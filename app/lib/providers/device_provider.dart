import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../services/transport_service.dart';
import '../services/protocol_service.dart';
import '../services/debug_transport.dart';

enum DeviceConnectionState {
  disconnected,
  connecting,
  fetchingConfig,
  connected,
  error,
}

/// Pending VAR_UPDATE entry for retry logic.
class _PendingUpdate {
  final int widgetId;
  final int seq;
  final List<int> values;
  int retries;
  Timer? timer;

  _PendingUpdate({
    required this.widgetId,
    required this.seq,
    required this.values,
    this.retries = 0,
  });
}

/// Manages the connected device, widget configuration, and variable
/// polling/update loop. Transport-agnostic.
class DeviceProvider extends ChangeNotifier {
  TransportService _transport;

  DeviceInfo?              _connectedDevice;
  DeviceConnectionState    _connectionState = DeviceConnectionState.disconnected;
  List<WidgetConfig>       _widgets  = [];
  int                      _orientation = kOrientationLandscape;
  RadioWidgetState?        _widgetState;
  String?                  _errorMessage;
  bool                     _configReceived = false;

  Timer?                   _pollTimer;
  Timer?                   _pingTimer;
  Timer?                   _confTimeoutTimer;
  DebugLogSink?            _debugSink;
  Completer<void>?         _confCompleter;

  /// Pending VAR_UPDATE packets awaiting ACK, keyed by SEQ byte.
  final Map<int, _PendingUpdate> _pendingUpdates = {};
  int _nextSeq = 0;

  DeviceProvider({
    required TransportService transport,
    DebugLogSink? debugSink,
  })  : _transport = transport,
        _debugSink = debugSink;

  // ── Getters ────────────────────────────────────────────────────────────────

  DeviceInfo?           get connectedDevice  => _connectedDevice;
  DeviceConnectionState get connectionState  => _connectionState;
  List<WidgetConfig>    get widgets          => List.unmodifiable(_widgets);
  int                   get orientation      => _orientation;
  RadioWidgetState?     get widgetState      => _widgetState;
  String?               get errorMessage     => _errorMessage;
  bool                  get isConnected      =>
      _connectionState == DeviceConnectionState.connected;
  TransportService      get currentTransport => _transport;

  // ── Transport swap ─────────────────────────────────────────────────────────

  void setTransport(TransportService transport) {
    var next = transport;
    if (_debugSink != null) {
      next = DebugTransport(inner: transport, sink: _debugSink!);
    }
    if (identical(_transport, next)) return;
    _transport = next;
    _transport.onPacketReceived = _handlePacket;
    _transport.onConnectionLost = _handleConnectionLost;
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> connectToDevice(DeviceInfo device, {int baudRate = 115200}) async {
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = device;
    _errorMessage    = null;
    _configReceived  = false;
    notifyListeners();

    _transport.onPacketReceived = _handlePacket;
    _transport.onConnectionLost = _handleConnectionLost;

    if (_debugSink != null && _transport is! DebugTransport) {
      _transport = DebugTransport(inner: _transport, sink: _debugSink!);
      _transport.onPacketReceived = _handlePacket;
      _transport.onConnectionLost = _handleConnectionLost;
    }

    try {
      await _transport.connect(device.id, baudRate: baudRate);
      if (_connectionState == DeviceConnectionState.disconnected) return;
    } catch (e) {
      _errorMessage    = 'Connection failed: $e';
      _connectionState = DeviceConnectionState.error;
      notifyListeners();
      return;
    }

    await _requestConfig();
  }

  Future<void> _requestConfig() async {
    _connectionState = DeviceConnectionState.fetchingConfig;
    notifyListeners();

    for (int attempt = 0; attempt < 3; attempt++) {
      _confCompleter = Completer<void>();

      try {
        await _transport.writePacket(ProtocolService.buildGetConf());
      } catch (e) {
        _errorMessage    = 'Failed to send GET_CONF: $e';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      }

      _confTimeoutTimer = Timer(kConfTimeout, () {
        if (_confCompleter != null && !_confCompleter!.isCompleted) {
          _confCompleter!.completeError(TimeoutException('CONF_DATA timeout'));
        }
      });

      try {
        await _confCompleter!.future;
        _confTimeoutTimer?.cancel();
        if (_connectionState == DeviceConnectionState.disconnected) return;
        _startPolling();
        return;
      } on TimeoutException {
        _confTimeoutTimer?.cancel();
        if (_connectionState == DeviceConnectionState.disconnected) return;
        if (attempt < 2) continue;
        _errorMessage    = 'Timed out waiting for device configuration. Please reconnect.';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      } catch (e) {
        _confTimeoutTimer?.cancel();
        if (_connectionState == DeviceConnectionState.disconnected) return;
        _errorMessage    = 'Error receiving config: $e';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      }
    }
  }

  // ── Polling loop ───────────────────────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pingTimer?.cancel();

    _pollTimer = Timer.periodic(kGetVarsInterval, (_) async {
      if (!_transport.isConnected) return;
      try { await _transport.writePacket(ProtocolService.buildGetVars()); } catch (_) {}
    });

    _pingTimer = Timer.periodic(kPingInterval, (_) async {
      if (!_transport.isConnected) return;
      try { await _transport.writePacket(ProtocolService.buildPing()); } catch (_) {}
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel(); _pollTimer = null;
    _pingTimer?.cancel(); _pingTimer = null;
  }

  // ── Packet handling ────────────────────────────────────────────────────────

  void _handlePacket(ParsedPacket packet) {
    switch (packet.cmd) {
      case kCmdConfData:  _handleConfData(packet.payload);  break;
      case kCmdVarData:   _handleVarData(packet.payload);   break;
      case kCmdVarUpdate: _handleVarUpdate(packet.payload); break;
      case kCmdAck:       _handleAck(packet.payload);       break;
      case kCmdPong:      break;
      default:
        debugPrint('RadioKit: Unknown cmd 0x${packet.cmd.toRadixString(16)}');
    }
  }

  void _handleConfData(List<int> payload) {
    final conf = ProtocolService.parseConfData(payload);
    if (conf == null) { debugPrint('RadioKit: Failed to parse CONF_DATA'); return; }
    _widgets         = conf.widgets;
    _orientation     = conf.orientation;
    _widgetState     = RadioWidgetState.initial(conf.widgets);
    _configReceived  = true;
    _connectionState = DeviceConnectionState.connected;
    notifyListeners();
    if (_confCompleter != null && !_confCompleter!.isCompleted) {
      _confCompleter!.complete();
    }
  }

  void _handleVarData(List<int> payload) {
    final current = _widgetState;
    if (current == null) return;
    final next = ProtocolService.parseVarData(payload, _widgets, current);
    if (next != null) { _widgetState = next; notifyListeners(); }
  }

  /// Handle an incoming VAR_UPDATE (device → app partial update).
  /// Apply the change immediately and send back an ACK.
  void _handleVarUpdate(List<int> payload) {
    final result = ProtocolService.parseVarUpdate(payload);
    if (result == null) return;
    final (widgetId, seq, values) = result;

    final current = _widgetState;
    if (current == null) return;

    // Find the widget to know if this is input or output
    final widget = _widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => WidgetConfig(
        typeId: 0, widgetId: widgetId, x: 0, y: 0, size: 0, aspect: 0),
    );

    RadioWidgetState next;
    if (widget.hasOutput) {
      if (widget.typeId == kWidgetLed && values.length >= 4) {
        next = current.copyWithOutput(widgetId, List<int>.from(values.take(4)));
      } else if (widget.typeId == kWidgetText) {
        final nullIdx = values.indexOf(0);
        final text = utf8Decode(nullIdx >= 0 ? values.sublist(0, nullIdx) : values);
        next = current.copyWithOutput(widgetId, text);
      } else {
        next = current.copyWithOutput(widgetId, values.isNotEmpty ? values[0] : 0);
      }
    } else {
      next = current.copyWithInput(widgetId, values);
    }

    _widgetState = next;
    notifyListeners();

    // Send ACK
    _transport.writePacket(ProtocolService.buildAck(seq)).catchError((_) {});
  }

  /// Handle ACK from device — clears the pending VAR_UPDATE retry for [seq].
  void _handleAck(List<int> payload) {
    if (payload.isEmpty) return;
    final seq    = payload[0];
    final pending = _pendingUpdates.remove(seq);
    pending?.timer?.cancel();
  }

  void _handleConnectionLost(String reason) {
    _cancelAllPendingUpdates();
    _stopPolling();
    _connectionState = DeviceConnectionState.disconnected;
    _errorMessage    = reason;
    notifyListeners();
  }

  // ── VAR_UPDATE with retry (app → device) ───────────────────────────────────

  /// Send a reliable VAR_UPDATE for [widgetId] with [values].
  /// Retries every [kVarUpdateTimeoutMs] ms up to [kVarUpdateMaxRetries] times,
  /// then falls back to a full GET_VARS cycle.
  Future<void> _sendVarUpdate(int widgetId, List<int> values) async {
    final seq = _nextSeq++ & 0xFF;
    final pkt = ProtocolService.buildVarUpdate(widgetId, seq, values);

    final entry = _PendingUpdate(
        widgetId: widgetId, seq: seq, values: values);
    _pendingUpdates[seq] = entry;

    Future<void> trySend() async {
      if (!_transport.isConnected) {
        _pendingUpdates.remove(seq);
        return;
      }
      try { await _transport.writePacket(pkt); } catch (_) {}

      if (!_pendingUpdates.containsKey(seq)) return; // ACK arrived

      if (entry.retries >= kVarUpdateMaxRetries) {
        _pendingUpdates.remove(seq);
        // Fallback: request a full VAR_DATA
        try { await _transport.writePacket(ProtocolService.buildGetVars()); } catch (_) {}
        return;
      }

      entry.retries++;
      entry.timer = Timer(
        Duration(milliseconds: kVarUpdateTimeoutMs),
        trySend,
      );
    }

    await trySend();
  }

  void _cancelAllPendingUpdates() {
    for (final e in _pendingUpdates.values) {
      e.timer?.cancel();
    }
    _pendingUpdates.clear();
  }

  // ── Widget interaction ─────────────────────────────────────────────────────

  Future<void> setInputValue(int widgetId, List<int> values) async {
    final current = _widgetState;
    if (current == null) return;
    final next = current.copyWithInput(widgetId, values);
    _widgetState = next;
    notifyListeners();
    if (!_transport.isConnected) return;
    // Use reliable VAR_UPDATE for single-widget changes
    await _sendVarUpdate(widgetId, values);
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _connectionState = DeviceConnectionState.disconnected;
    notifyListeners();

    _cancelAllPendingUpdates();
    _stopPolling();
    _confTimeoutTimer?.cancel();
    if (_confCompleter != null && !_confCompleter!.isCompleted) {
      _confCompleter!.completeError(TimeoutException('Disconnected by user'));
    }
    await _transport.disconnect();
    _connectedDevice = null;
    _widgets         = [];
    _widgetState     = null;
    _errorMessage    = null;
    notifyListeners();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cancelAllPendingUpdates();
    _stopPolling();
    _confTimeoutTimer?.cancel();
    super.dispose();
  }
}

// ignore: non_constant_identifier_names
String utf8Decode(List<int> bytes) {
  try { return const Utf8Decoder(allowMalformed: true).convert(bytes); }
  catch (_) { return ''; }
}
