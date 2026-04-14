import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../services/transport_service.dart';
import '../services/protocol_service.dart';

/// Connection state for the currently connected device.
enum DeviceConnectionState {
  disconnected,
  connecting,
  fetchingConfig,
  connected,
  error,
}

/// Manages the connected device, widget configuration, and variable
/// polling/update loop.
///
/// Transport-agnostic: works with both [BleService] and [SerialService]
/// through the [TransportService] abstraction.
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

  Completer<void>? _confCompleter;

  DeviceProvider({required TransportService transport}) : _transport = transport;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  DeviceInfo? get connectedDevice => _connectedDevice;
  DeviceConnectionState get connectionState => _connectionState;
  List<WidgetConfig> get widgets => List.unmodifiable(_widgets);
  int get orientation => _orientation;
  RadioWidgetState? get widgetState => _widgetState;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _connectionState == DeviceConnectionState.connected;

  // ---------------------------------------------------------------------------
  // Transport swap
  // ---------------------------------------------------------------------------

  /// Called by [app.dart] when the user switches between BLE and Serial.
  void setTransport(TransportService transport) {
    if (identical(_transport, transport)) return;
    _transport = transport;
    // Attach callbacks to the new transport immediately
    _transport.onPacketReceived = _handlePacket;
    _transport.onConnectionLost = _handleConnectionLost;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> connectToDevice(DeviceInfo device) async {
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = device;
    _errorMessage = null;
    _configReceived = false;
    notifyListeners();

    _transport.onPacketReceived = _handlePacket;
    _transport.onConnectionLost = _handleConnectionLost;

    try {
      await _transport.connect(device.id);
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
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
        _errorMessage = 'Failed to send GET_CONF: $e';
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
        _startPolling();
        return;
      } on TimeoutException {
        _confTimeoutTimer?.cancel();
        if (attempt < 2) continue;
        _errorMessage = 'Timed out waiting for device configuration. Please reconnect.';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      } catch (e) {
        _confTimeoutTimer?.cancel();
        _errorMessage = 'Error receiving config: $e';
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

    // PING every 2 s — keeps the Serial session alive (3 s timeout on firmware)
    _pingTimer = Timer.periodic(kPingInterval, (_) async {
      if (!_transport.isConnected) return;
      try { await _transport.writePacket(ProtocolService.buildPing()); }
      catch (_) {}
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ---------------------------------------------------------------------------
  // Packet handling
  // ---------------------------------------------------------------------------

  void _handlePacket(ParsedPacket packet) {
    switch (packet.cmd) {
      case kCmdConfData:
        _handleConfData(packet.payload);
        break;
      case kCmdVarData:
        _handleVarData(packet.payload);
        break;
      case kCmdAck:
        break;
      case kCmdPong:
        break;
      default:
        debugPrint('RadioKit: Unknown command 0x${packet.cmd.toRadixString(16)}');
    }
  }

  void _handleConfData(List<int> payload) {
    final conf = ProtocolService.parseConfData(payload);
    if (conf == null) {
      debugPrint('RadioKit: Failed to parse CONF_DATA');
      return;
    }
    _widgets      = conf.widgets;
    _orientation  = conf.orientation;
    _widgetState  = RadioWidgetState.initial(conf.widgets);
    _configReceived = true;
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
    if (next != null) {
      _widgetState = next;
      notifyListeners();
    }
  }

  void _handleConnectionLost(String reason) {
    _stopPolling();
    _connectionState = DeviceConnectionState.disconnected;
    _errorMessage = reason;
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
    _stopPolling();
    await _transport.disconnect();
    _connectionState  = DeviceConnectionState.disconnected;
    _connectedDevice  = null;
    _widgets          = [];
    _widgetState      = null;
    _errorMessage     = null;
    notifyListeners();
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
