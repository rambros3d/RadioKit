import 'dart:async';
import 'dart:convert';
import 'package:universal_ble/universal_ble.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import '../models/protocol.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';

// Conditionally import JS bridge for Web Mock
import 'ble_js_bridge_stub.dart' if (dart.library.js) 'ble_js_bridge_web.dart';

/// Unified BLE service using universal_ble.
///
/// Handles scanning, connection, and UART-style data transfer across
/// Web, Android, iOS, Windows, macOS, and Linux.
class BleService implements TransportService {
  BleService() {
    _setupListeners();
    setupBleJsBridge(this);
  }

  @override
  PacketReceivedCallback? onPacketReceived;
  @override
  ConnectionLostCallback? onConnectionLost;

  String? _connectedDeviceId;
  bool _isMockConnected = false;
  final List<int> _receiveBuffer = [];

  StreamController<DeviceInfo>? _scanController;
  final _availabilityController = StreamController<AvailabilityState>.broadcast();
  Stream<AvailabilityState> get availabilityStream => _availabilityController.stream;

  @override
  bool get isConnected => _isMockConnected || _connectedDeviceId != null;

  String? get connectedDeviceId =>
      _isMockConnected ? 'MOCK-UUID-1234' : _connectedDeviceId;

  /// Returns true if BLE is supported on this platform.
  bool get isSupported => true;

  /// Returns true if Bluetooth is available/enabled.
  Future<bool> get isAvailable async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state == AvailabilityState.poweredOn;
  }

  /// Returns true if Location Services are enabled (required for Android < 12).
  Future<bool> get isLocationServiceEnabled async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await Geolocator.isLocationServiceEnabled();
    }
    return true;
  }

  /// Returns the current Bluetooth availability state.
  Future<AvailabilityState> getAvailability() async {
    return await UniversalBle.getBluetoothAvailabilityState();
  }

  /// Requests necessary Bluetooth permissions.
  Future<void> requestPermissions() async {
    try {
      debugPrint('BLE_SERVICE: Requesting permissions...');
      await UniversalBle.requestPermissions(
        withAndroidFineLocation: true, // Required for reliable BLE scanning on many Android devices
      );
      debugPrint('BLE_SERVICE: Permissions request completed.');
    } catch (e) {
      debugPrint('BLE_SERVICE: Error requesting BLE permissions: $e');
    }
  }

  /// Prompts user to enable Bluetooth (Android only).
  Future<void> enableBluetooth() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await UniversalBle.enableBluetooth();
      } catch (e) {
        debugPrint('Error enabling Bluetooth: $e');
      }
    }
  }

  void _setupListeners() {
    UniversalBle.onAvailabilityChange = (state) {
      _availabilityController.add(state);
    };

    UniversalBle.onConnectionChange = (String deviceId, bool isConnected, String? error) {
      if (deviceId == _connectedDeviceId && !isConnected) {
        _handleDisconnect(error ?? 'Connection lost');
      }
    };

    UniversalBle.onValueChange = (String deviceId, String characteristicId, Uint8List value, int? timestamp) {
      if (deviceId == _connectedDeviceId &&
          characteristicId.toLowerCase() == kRadioKitCharUuid.toLowerCase()) {
        _receiveBuffer.addAll(value);
        _processBuffer();
      }
    };
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  Stream<DeviceInfo> startScan() {
    debugPrint('BLE_SERVICE: startScan() called');
    _scanController?.close();
    final controller = StreamController<DeviceInfo>.broadcast();
    _scanController = controller;
    final seen = <String>{};

    UniversalBle.onScanResult = (BleDevice result) {
      if (!seen.contains(result.deviceId)) {
        seen.add(result.deviceId);
        debugPrint('BLE_SERVICE: Found device: ${result.name} (${result.deviceId})');
        final info = DeviceInfo(
          id: result.deviceId,
          name: result.name ?? 'Unknown Device',
          rssi: result.rssi ?? -100,
        );
        if (!controller.isClosed) {
          controller.add(info);
        }
      }
    };

    UniversalBle.startScan(
      scanFilter: ScanFilter(
        withServices: [kRadioKitServiceUuid.toLowerCase()],
      ),
    ).then((_) {
      debugPrint('BLE_SERVICE: UniversalBle.startScan success');
    }).catchError((error) {
      debugPrint('BLE_SERVICE: UniversalBle.startScan ERROR: $error');
      if (!controller.isClosed) {
        controller.addError(error);
      }
    });

    return controller.stream;
  }

  Future<void> stopScan() async {
    UniversalBle.onScanResult = null;
    await UniversalBle.stopScan();
    await _scanController?.close();
    _scanController = null;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId, {int baudRate = 115200}) async {
    if (deviceId == 'MOCK-UUID-1234') {
      _isMockConnected = true;
      return;
    }

    try {
      await UniversalBle.connect(deviceId);
      _connectedDeviceId = deviceId;

      // Discover services and enable notifications
      await UniversalBle.discoverServices(deviceId);
      
      await UniversalBle.subscribeNotifications(
        deviceId,
        kRadioKitServiceUuid.toLowerCase(),
        kRadioKitCharUuid.toLowerCase(),
      );

      _receiveBuffer.clear();
    } catch (e) {
      _connectedDeviceId = null;
      throw Exception('Failed to connect: $e');
    }
  }

  @override
  Future<void> disconnect() async {
    if (_isMockConnected) {
      _isMockConnected = false;
      return;
    }

    final id = _connectedDeviceId;
    if (id != null) {
      await UniversalBle.disconnect(id);
      _connectedDeviceId = null;
    }
    _receiveBuffer.clear();
  }

  void _handleDisconnect(String reason) {
    _connectedDeviceId = null;
    _isMockConnected = false;
    _receiveBuffer.clear();
    onConnectionLost?.call(reason);
  }

  // ---------------------------------------------------------------------------
  // Data Transfer
  // ---------------------------------------------------------------------------

  @override
  Future<void> writePacket(Uint8List data) async {
    if (_isMockConnected) {
      _handleMockWrite(data);
      return;
    }

    final deviceId = _connectedDeviceId;
    if (deviceId == null) throw StateError('Not connected');

    await UniversalBle.write(
      deviceId,
      kRadioKitServiceUuid.toLowerCase(),
      kRadioKitCharUuid.toLowerCase(),
      data,
      withoutResponse: true,
    );
  }

  void _processBuffer() {
    while (_receiveBuffer.length >= 6) {
      final startIdx = _receiveBuffer.indexOf(kStartByte);
      if (startIdx < 0) {
        _receiveBuffer.clear();
        return;
      }
      if (startIdx > 0) {
        _receiveBuffer.removeRange(0, startIdx);
        continue;
      }

      if (_receiveBuffer.length < 3) return;
      final length = _receiveBuffer[1] | (_receiveBuffer[2] << 8);

      if (length < 6) {
        _receiveBuffer.removeAt(0);
        continue;
      }
      if (_receiveBuffer.length < length) return;

      final packetBytes = _receiveBuffer.sublist(0, length);
      _receiveBuffer.removeRange(0, length);

      final packet = ProtocolService.parsePacket(Uint8List.fromList(packetBytes));
      if (packet != null) {
        onPacketReceived?.call(packet);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Mock / Simulation Logic
  // ---------------------------------------------------------------------------

  /// [Debug only] Manually inject a packet into the received stream.
  void injectDebugPacket(List<int> packetBytes) {
    final packet = ProtocolService.parsePacket(Uint8List.fromList(packetBytes));
    if (packet != null) {
      onPacketReceived?.call(packet);
    }
  }

  int _mockButtonValue = 0;
  int _mockSwitchValue = 1;
  int _mockSliderValue = 50;
  int _mockJoyX = 0;
  int _mockJoyY = 0;
  int _mockLedValue = 1;
  String _mockTextValue = 'Demo Mode Active';

  void _handleMockWrite(Uint8List data) {
    if (data.length >= 4 && data[0] == kStartByte) {
      final cmd = data[3];
      final payload = data.sublist(4, data.length - 2);

      Future.delayed(const Duration(milliseconds: 30), () {
        if (cmd == kCmdGetConf) {
          _respondWithMockConf();
        } else if (cmd == kCmdGetVars) {
          _respondWithMockVars();
        } else if (cmd == kCmdSetInput) {
          if (payload.length >= 5) {
            _mockButtonValue = payload[0];
            _mockSwitchValue = payload[1];
            _mockSliderValue = payload[2];
            _mockJoyX = _toSigned(payload[3]);
            _mockJoyY = _toSigned(payload[4]);
            _mockLedValue = _mockSwitchValue;
            _mockTextValue = 'Val: $_mockSliderValue | Joy: $_mockJoyX,$_mockJoyY';
          }
          _respondWithAck();
        } else if (cmd == kCmdPing) {
          _respondWithPong();
        }
      });
    }
  }

  void _respondWithMockConf() {
    injectDebugPacket([
      0x55, 0x5B, 0x00, 0x02,
      0x02, 0x00, 0x06,
      0x01, 0x00, 0x26, 0x19, 0x0F, 0x19, 0x00, 0x06,
      0x42, 0x75, 0x74, 0x74, 0x6F, 0x6E,
      0x02, 0x01, 0x3F, 0x4B, 0x0F, 0x10, 0x00, 0x06,
      0x53, 0x77, 0x69, 0x74, 0x63, 0x68,
      0x03, 0x02, 0x0C, 0x33, 0x0A, 0x32, 0x00, 0x06,
      0x53, 0x6C, 0x69, 0x64, 0x65, 0x72,
      0x04, 0x03, 0x7F, 0x33, 0x26, 0x0A, 0x00, 0x07,
      0x43, 0x6F, 0x6E, 0x74, 0x72, 0x6F, 0x6C,
      0x05, 0x04, 0x0C, 0x50, 0x0C, 0x0A, 0x00, 0x03,
      0x4C, 0x45, 0x44,
      0x06, 0x05, 0x33, 0x50, 0x0C, 0x28, 0x00, 0x06,
      0x53, 0x74, 0x61, 0x74, 0x75, 0x73,
      0x26, 0x2E,
    ]);
  }

  void _respondWithMockVars() {
    final textBytes = Uint8List(32);
    final encoded = utf8.encode(_mockTextValue);
    for (int i = 0; i < encoded.length && i < 32; i++) {
      textBytes[i] = encoded[i];
    }
    final payload = [
      _mockButtonValue,
      _mockSwitchValue,
      _mockSliderValue,
      _mockJoyX < 0 ? _mockJoyX + 256 : _mockJoyX,
      _mockJoyY < 0 ? _mockJoyY + 256 : _mockJoyY,
      _mockLedValue,
      ...textBytes,
    ];
    injectDebugPacket(ProtocolService.buildPacket(kCmdVarData, Uint8List.fromList(payload)));
  }

  void _respondWithAck() => injectDebugPacket(ProtocolService.buildPacket(kCmdAck));
  void _respondWithPong() => injectDebugPacket(ProtocolService.buildPacket(kCmdPong));

  static int _toSigned(int byte) {
    final b = byte & 0xFF;
    return b >= 128 ? b - 256 : b;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  Future<void> dispose() async {
    await stopScan();
    await disconnect();
    await _availabilityController.close();
  }
}
