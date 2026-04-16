import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../services/transport_service.dart';
import '../services/protocol_service.dart';
import '../services/debug_transport.dart';

import '../providers/console_provider.dart';
import '../providers/skin_provider.dart';
import '../models/console_entry.dart';

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
  ConsoleProvider? _console;
  SkinProvider? _skinProvider;

  DeviceInfo?              _connectedDevice;
  DeviceConnectionState    _connectionState = DeviceConnectionState.disconnected;
  String?                  _configName;
  List<WidgetConfig>       _widgets  = [];
  int                      _orientation = kOrientationLandscape;
  RadioWidgetState?        _widgetState;
  String?                  _errorMessage;

  Timer?                   _pollTimer;
  Timer?                   _pingTimer;
  Timer?                   _confTimeoutTimer;
  DebugLogSink?            _debugSink;
  Completer<void>?         _confCompleter;

  final Map<int, _PendingUpdate> _pendingUpdates = {};
  int _nextSeq = 0;

  DeviceProvider({
    required TransportService transport,
    DebugLogSink? debugSink,
    ConsoleProvider? console,
    SkinProvider? skinProvider,
  })  : _transport = transport,
        _debugSink = debugSink,
        _console = console,
        _skinProvider = skinProvider;

  void _log(String message, {ConsoleLogLevel level = ConsoleLogLevel.info}) {
    _console?.log(message, level: level);
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  DeviceInfo?           get connectedDevice  => _connectedDevice;
  DeviceConnectionState get connectionState  => _connectionState;
  String?               get configName       => _configName;
  List<WidgetConfig>    get widgets          => List.unmodifiable(_widgets);
  int                   get orientation      => _orientation;
  RadioWidgetState?     get widgetState      => _widgetState;
  String?               get errorMessage     => _errorMessage;
  bool                  get isConnected      =>
      _connectionState == DeviceConnectionState.connected;
  TransportService      get currentTransport => _transport;

  // ── Transport swap ───────────────────────────────────────────────────────────

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
    notifyListeners();

    _transport.onPacketReceived = _handlePacket;
    _transport.onConnectionLost = _handleConnectionLost;

    if (_debugSink != null && _transport is! DebugTransport) {
      _transport = DebugTransport(inner: _transport, sink: _debugSink!);
      _transport.onPacketReceived = _handlePacket;
      _transport.onConnectionLost = _handleConnectionLost;
    }

    _log('CONNECTING TO: ${device.name} (${device.id})');
    try {
      await _transport.connect(device.id, baudRate: baudRate);
      if (_connectionState == DeviceConnectionState.disconnected) return;
    } catch (e) {
      _log('CONNECTION FAILED: $e', level: ConsoleLogLevel.error);
      _errorMessage    = 'Connection failed: $e';
      _connectionState = DeviceConnectionState.error;
      await _transport.disconnect(); // Hardened cleanup
      notifyListeners();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 3500));
    if (_connectionState == DeviceConnectionState.disconnected) return;

    await _requestConfig();
  }

  Future<void> _requestConfig() async {
    _log('ESTABLISHING HANDSHAKE (Protocol v${kProtocolVersion})...');
    _connectionState = DeviceConnectionState.fetchingConfig;
    notifyListeners();

    for (int attempt = 0; attempt < 3; attempt++) {
      _confCompleter = Completer<void>();

      try {
        final pkt = ProtocolService.buildGetConf();
        final hex = pkt.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _log('TX -> GET_CONF (attempt ${attempt + 1}/3) bytes: $hex');
        await _transport.writePacket(pkt);
      } catch (e) {
        _log('FAILED TO SEND GET_CONF: $e', level: ConsoleLogLevel.error);
        _errorMessage    = 'Failed to send GET_CONF: $e';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      }

      _confTimeoutTimer?.cancel();
      _confTimeoutTimer = Timer(kConfTimeout, () {
        if (_confCompleter != null && !_confCompleter!.isCompleted) {
          _confCompleter!.completeError(
              TimeoutException('CONF_DATA timeout (attempt ${attempt + 1})'));
        }
      });

      try {
        await _confCompleter!.future;
        _confTimeoutTimer?.cancel();
        _confTimeoutTimer = null;
        _confCompleter = null;
        _log('RX <- CONF_DATA (${_transport.isConnected ? "connected" : "handshake done"})');
        break; // Success
      } on TimeoutException catch (_) {
        _confTimeoutTimer?.cancel();
        _confTimeoutTimer = null;
        _log('TIMEOUT: Device did not respond to GET_CONF.',
            level: ConsoleLogLevel.warning);
        if (_connectionState == DeviceConnectionState.disconnected) return;
        if (attempt < 2) continue;

        _errorMessage = 'Device did not respond to GET_CONF after 3 attempts.';
        _connectionState = DeviceConnectionState.error;
        await _transport.disconnect(); // Hardened cleanup
        notifyListeners();
        return;
      } catch (e) {
        _confTimeoutTimer?.cancel();
        _confTimeoutTimer = null;
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
    // Always cancel existing timers before creating new ones.
    // This is the single safe entry point — never call twice concurrently.
    _pollTimer?.cancel();
    _pingTimer?.cancel();
    _pollTimer = null;
    _pingTimer = null;

    _pollTimer = Timer.periodic(kGetVarsInterval, (_) async {
      if (!_transport.isConnected) return;
      try {
        await _transport.writePacket(ProtocolService.buildGetVars());
      } catch (e) {
        _log('POLL ERROR: $e', level: ConsoleLogLevel.warning);
      }
    });

    _pingTimer = Timer.periodic(kPingInterval, (_) async {
      if (!_transport.isConnected) return;
      try {
        await _transport.writePacket(ProtocolService.buildPing());
      } catch (e) {
        debugPrint('RadioKit: Ping error: $e');
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel(); _pollTimer = null;
    _pingTimer?.cancel(); _pingTimer = null;
  }

  // ── Packet handling ──────────────────────────────────────────────────────────

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
    _log('RX <- CONF_DATA (${payload.length} bytes)');
    final conf = ProtocolService.parseConfData(payload);
    if (conf == null) {
      _log('PARSE FAILED: Invalid CONF_DATA payload.', level: ConsoleLogLevel.error);
      debugPrint('RadioKit: CONF_DATA parse failed — raw: '
          '${payload.take(32).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
      return;
    }
    _log('RECEIVED CONFIG: "${(conf as ParsedConf).name}" with ${conf.widgets.length} widgets', level: ConsoleLogLevel.success);
    _configName      = conf.name;
    _widgets         = conf.widgets;
    _orientation     = conf.orientation;
    _widgetState     = RadioWidgetState.initial(conf.widgets);
    _connectionState = DeviceConnectionState.connected;
    
    // Apply the skin provided by the device
    _skinProvider?.setSkin(conf.theme);

    _startPolling();
    notifyListeners();
    final completer = _confCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _handleVarData(List<int> payload) {
    final current = _widgetState;
    if (current == null) return;
    final next = ProtocolService.parseVarData(payload, _widgets, current);
    if (next != null) { _widgetState = next; notifyListeners(); }
  }

  void _handleVarUpdate(List<int> payload) {
    final result = ProtocolService.parseVarUpdate(payload);
    if (result == null) return;
    final (widgetId, seq, values) = result;

    final current = _widgetState;
    if (current == null) return;

    final widget = _widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => WidgetConfig(
          typeId: 0, widgetId: widgetId, x: 0, y: 0, scale: 0, aspect: 0),
    );

    RadioWidgetState next;
    if (widget.hasOutput) {
      if (widget.typeId == kWidgetLed && values.length >= 5) {
        // v3: [STATE, R, G, B, OPACITY]
        next = current.copyWithOutput(widgetId, List<int>.from(values.take(5)));
      } else if (widget.typeId == kWidgetText) {
        final nullIdx = values.indexOf(0);
        final text = utf8Decode(
            nullIdx >= 0 ? values.sublist(0, nullIdx) : values);
        next = current.copyWithOutput(widgetId, text);
      } else {
        next = current.copyWithOutput(
            widgetId, values.isNotEmpty ? values[0] : 0);
      }
    } else {
      next = current.copyWithInput(widgetId, values);
    }

    _widgetState = next;
    notifyListeners();

    _transport.writePacket(ProtocolService.buildAck(seq)).catchError((_) {});
  }

  void _handleAck(List<int> payload) {
    if (payload.isEmpty) return;
    final seq     = payload[0];
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

  // ── VAR_UPDATE with retry (app → device) ──────────────────────────────────────

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

      if (!_pendingUpdates.containsKey(seq)) return;

      if (entry.retries >= kVarUpdateMaxRetries) {
        _pendingUpdates.remove(seq);
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

  // ── Widget interaction ──────────────────────────────────────────────────────────

  Future<void> setInputValue(int widgetId, List<int> values) async {
    final current = _widgetState;
    if (current == null) return;
    final next = current.copyWithInput(widgetId, values);
    _widgetState = next;
    notifyListeners();
    if (!_transport.isConnected) return;
    await _sendVarUpdate(widgetId, values);
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _connectionState = DeviceConnectionState.disconnected;
    notifyListeners();

    _cancelAllPendingUpdates();
    _stopPolling();
    _confTimeoutTimer?.cancel();
    _confTimeoutTimer = null;
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

  // ── Cleanup ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cancelAllPendingUpdates();
    _stopPolling();
    _confTimeoutTimer?.cancel();
    super.dispose();
  }
}

String utf8Decode(List<int> bytes) {
  try { return const Utf8Decoder(allowMalformed: true).convert(bytes); }
  catch (_) { return ''; }
}
