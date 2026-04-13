import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../services/ble_service.dart';
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
class DeviceProvider extends ChangeNotifier {
  final BleService _bleService;

  DeviceInfo? _connectedDevice;
  DeviceConnectionState _connectionState = DeviceConnectionState.disconnected;
  List<WidgetConfig> _widgets = [];
  WidgetState? _widgetState;
  String? _errorMessage;
  bool _configReceived = false;

  // Timers for polling and ping
  Timer? _pollTimer;
  Timer? _pingTimer;
  Timer? _confTimeoutTimer;

  // Completer for waiting on CONF_DATA response
  Completer<void>? _confCompleter;

  DeviceProvider({required BleService bleService}) : _bleService = bleService;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  DeviceInfo? get connectedDevice => _connectedDevice;
  DeviceConnectionState get connectionState => _connectionState;
  List<WidgetConfig> get widgets => List.unmodifiable(_widgets);
  WidgetState? get widgetState => _widgetState;
  String? get errorMessage => _errorMessage;
  bool get isConnected =>
      _connectionState == DeviceConnectionState.connected;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to [device] and fetch its UI configuration.
  Future<void> connectToDevice(DeviceInfo device) async {
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = device;
    _errorMessage = null;
    _configReceived = false;
    notifyListeners();

    // Set up packet handling callbacks
    _bleService.onPacketReceived = _handlePacket;
    _bleService.onConnectionLost = _handleConnectionLost;

    try {
      await _bleService.connect(device.id);
    } catch (e) {
      _errorMessage = 'Connection failed: $e';
      _connectionState = DeviceConnectionState.error;
      notifyListeners();
      return;
    }

    // Request UI configuration
    await _requestConfig();
  }

  /// Request CONF_DATA from the device. Retries up to 2 times on timeout.
  Future<void> _requestConfig() async {
    _connectionState = DeviceConnectionState.fetchingConfig;
    notifyListeners();

    for (int attempt = 0; attempt < 3; attempt++) {
      _confCompleter = Completer<void>();

      try {
        await _bleService.writePacket(ProtocolService.buildGetConf());
      } catch (e) {
        _errorMessage = 'Failed to send GET_CONF: $e';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      }

      // Wait for CONF_DATA or timeout
      _confTimeoutTimer =
          Timer(kConfTimeout, () {
        if (_confCompleter != null && !_confCompleter!.isCompleted) {
          _confCompleter!.completeError(TimeoutException('CONF_DATA timeout'));
        }
      });

      try {
        await _confCompleter!.future;
        _confTimeoutTimer?.cancel();
        // Successfully received config
        _startPolling();
        return;
      } on TimeoutException {
        _confTimeoutTimer?.cancel();
        if (attempt < 2) {
          // Retry
          continue;
        }
        _errorMessage =
            'Timed out waiting for device configuration. Please reconnect.';
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

    // Poll GET_VARS every 100ms
    _pollTimer = Timer.periodic(kGetVarsInterval, (_) async {
      if (!_bleService.isConnected) return;
      try {
        await _bleService.writePacket(ProtocolService.buildGetVars());
      } catch (_) {
        // Disconnection will be handled by onConnectionLost callback
      }
    });

    // PING every 2 seconds
    _pingTimer = Timer.periodic(kPingInterval, (_) async {
      if (!_bleService.isConnected) return;
      try {
        await _bleService.writePacket(ProtocolService.buildPing());
      } catch (_) {}
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
        // Acknowledgment for SET_INPUT — no action needed
        break;

      case kCmdPong:
        // Pong received — connection is healthy
        break;

      default:
        debugPrint(
            'RadioKit: Unknown command 0x${packet.cmd.toRadixString(16)}');
    }
  }

  void _handleConfData(List<int> payload) {
    final widgets = ProtocolService.parseConfData(payload);
    if (widgets == null) {
      debugPrint('RadioKit: Failed to parse CONF_DATA');
      return;
    }

    _widgets = widgets;
    _widgetState = WidgetState.initial(widgets);
    _configReceived = true;
    _connectionState = DeviceConnectionState.connected;
    notifyListeners();

    if (_confCompleter != null && !_confCompleter!.isCompleted) {
      _confCompleter!.complete();
    }
  }

  void _handleVarData(List<int> payload) {
    final currentState = _widgetState;
    if (currentState == null) return;

    final newState =
        ProtocolService.parseVarData(payload, _widgets, currentState);
    if (newState != null) {
      _widgetState = newState;
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

  /// Update an input widget's value and send SET_INPUT to the device.
  Future<void> setInputValue(int widgetId, List<int> values) async {
    final currentState = _widgetState;
    if (currentState == null) return;

    final newState = currentState.copyWithInput(widgetId, values);
    _widgetState = newState;
    notifyListeners();

    if (!_bleService.isConnected) return;
    try {
      await _bleService
          .writePacket(ProtocolService.buildSetInput(_widgets, newState));
    } catch (e) {
      debugPrint('RadioKit: Failed to send SET_INPUT: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  Future<void> disconnect() async {
    _stopPolling();
    await _bleService.disconnect();
    _connectionState = DeviceConnectionState.disconnected;
    _connectedDevice = null;
    _widgets = [];
    _widgetState = null;
    _errorMessage = null;
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
