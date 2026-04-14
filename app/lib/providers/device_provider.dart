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

/// Manages the connected device, widget configuration, and variable
/// polling/update loop. Transport-agnostic.
class DeviceProvider extends ChangeNotifier {
  TransportService _transport;

  DeviceInfo? _connectedDevice;
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  List<WidgetConfig> _widgets = [];
  int _orientation = kOrientationLandscape;
  RadioWidgetState? _widgetState;
  String? _errorMessage;
  bool _configReceived = false;

  Timer? _pollTimer;
  Timer? _pingTimer;
  Timer? _confTimeoutTimer;
  DebugLogSink? _debugSink;
  Completer<void>? _confCompleter;

  DeviceProvider({
    required TransportService transport,
    DebugLogSink? debugSink,
  })  : _transport = transport,
        _debugSink = debugSink;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  DeviceInfo? get connectedDevice    => _connectedDevice;
  DeviceConnectionState get connectionState => _connectionState;
  List<WidgetConfig> get widgets     => List.unmodifiable(_widgets);
  int get orientation                => _orientation;
  RadioWidgetState? get widgetState  => _widgetState;
  String? get errorMessage           => _errorMessage;
  bool get isConnected               => _connectionState == DeviceConnectionState.connected;

  /// Exposes the current transport so [ControlScreen] can wrap it in
  /// [DebugTransport] without a full reconnect.
  TransportService get currentTransport => _transport;

  // ---------------------------------------------------------------------------
  // Transport swap
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> connectToDevice(DeviceInfo device) async {
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = device;
    _errorMessage    = null;
    _configReceived  = false;
    notifyListeners();

    _transport.onPacketReceived  = _handlePacket;
    _transport.onConnectionLost  = _handleConnectionLost;

    // Ensure we are logging if a sink is available
    if (_debugSink != null && _transport is! DebugTransport) {
      _transport = DebugTransport(inner: _transport, sink: _debugSink!);
      _transport.onPacketReceived = _handlePacket;
      _transport.onConnectionLost = _handleConnectionLost;
    }

    try {
      await _transport.connect(device.id);
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

  // ---------------------------------------------------------------------------
  // Polling loop
  // ---------------------------------------------------------------------------

  void _startPolling() {
    _pollTimer?.cancel();
    _pingTimer?.cancel();

    _pollTimer = Timer.periodic(kGetVarsInterval, (_) async {
      if (!_transport.isConnected) return;
      try { await _transport.writePacket(ProtocolService.buildGetVars()); }
      catch (_) {}
    });

    _pingTimer = Timer.periodic(kPingInterval, (_) async {
      if (!_transport.isConnected) return;
      try { await _transport.writePacket(ProtocolService.buildPing()); }
      catch (_) {}
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel(); _pollTimer = null;
    _pingTimer?.cancel(); _pingTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Packet handling
  // ---------------------------------------------------------------------------

  void _handlePacket(ParsedPacket packet) {
    switch (packet.cmd) {
      case kCmdConfData: _handleConfData(packet.payload); break;
      case kCmdVarData:  _handleVarData(packet.payload);  break;
      case kCmdAck:      break;
      case kCmdPong:     break;
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

  void _handleConnectionLost(String reason) {
    _stopPolling();
    _connectionState = DeviceConnectionState.disconnected;
    _errorMessage    = reason;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Widget interaction
  // ---------------------------------------------------------------------------

  Future<void> setInputValue(int widgetId, List<int> values) async {
    final current = _widgetState;
    if (current == null) return;
    final next = current.copyWithInput(widgetId, values);
    _widgetState = next;
    notifyListeners();
    if (!_transport.isConnected) return;
    try {
      await _transport.writePacket(ProtocolService.buildSetInput(_widgets, next));
    } catch (e) {
      debugPrint('RadioKit: Failed to send SET_INPUT: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    _connectionState = DeviceConnectionState.disconnected;
    notifyListeners(); // Update UI immediately

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
    notifyListeners(); // Update again once transport is clean
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _stopPolling();
    _confTimeoutTimer?.cancel();
    super.dispose();
  }
}
