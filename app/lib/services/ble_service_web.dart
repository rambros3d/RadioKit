import 'dart:async';
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_web_bluetooth/flutter_web_bluetooth.dart';
import '../models/protocol.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';

/// Callback types used by [BleService].
typedef PacketReceivedCallback = void Function(ParsedPacket packet);
typedef ConnectionLostCallback = void Function(String reason);

/// Web BLE service using the Web Bluetooth API (Chrome/Edge).
///
/// Web Bluetooth works differently from native BLE:
///  - There is no continuous background scan. The browser shows a one-shot
///    device picker dialog when the user taps "Connect".
///  - After pairing, the device is accessible again without re-pairing.
///  - Requires a secure context (https or localhost).
///
/// The [startScan] method triggers the browser's native device picker,
/// yielding a single [DeviceInfo] for whatever device the user selects.
class BleService {
  BleService() {
    // Expose a function to JS for debugging/mocking
    js.context['injectBlePacket'] = (List<dynamic> bytes) {
      injectDebugPacket(bytes.cast<int>());
    };
  }

  PacketReceivedCallback? onPacketReceived;
  ConnectionLostCallback? onConnectionLost;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;

  // Buffer for assembling multi-chunk BLE packets
  final List<int> _receiveBuffer = [];

  bool get isConnected => _isMockConnected || (_device != null && _characteristic != null);
  String? get connectedDeviceId => _isMockConnected ? 'MOCK-UUID-1234' : _device?.id;

  /// Returns true if the browser supports the Web Bluetooth API.
  bool get isSupported => FlutterWebBluetooth.instance.isBluetoothApiSupported;

  /// Returns true if a Bluetooth adapter is available and enabled.
  Future<bool> get isAvailable async {
    if (!isSupported) return false;
    return await FlutterWebBluetooth.instance.getAvailability();
  }

  // ---------------------------------------------------------------------------
  // Scanning (Web: triggers browser device picker)
  // ---------------------------------------------------------------------------

  /// On web, "scanning" means opening the browser's Bluetooth device picker.
  ///
  /// The stream emits a single [DeviceInfo] for the device the user selects,
  /// then closes. If the user cancels or no device is found, the stream closes
  /// empty (no error).
  Stream<DeviceInfo> startScan() {
    final controller = StreamController<DeviceInfo>();

    _doRequestDevice(controller);

    return controller.stream;
  }

  Future<void> _doRequestDevice(StreamController<DeviceInfo> controller) async {
    try {
      // Check API availability
      if (!FlutterWebBluetooth.instance.isBluetoothApiSupported) {
        controller.addError(
          Exception(
            'Web Bluetooth is not supported in this browser.\n'
            'Please use Chrome or Edge on desktop, or Chrome on Android.',
          ),
        );
        await controller.close();
        return;
      }

      final available = await FlutterWebBluetooth.instance.getAvailability();
      if (!available) {
        controller.addError(
          Exception(
            'No Bluetooth adapter available. '
            'Please make sure Bluetooth is enabled on your device.',
          ),
        );
        await controller.close();
        return;
      }

      // Open the browser's device picker filtered to RadioKit service UUID
      final options = RequestOptionsBuilder(
        [
          RequestFilterBuilder(
            services: [kRadioKitServiceUuid.toLowerCase()],
          ),
        ],
        optionalServices: [kRadioKitServiceUuid.toLowerCase()],
      );

      final device = await FlutterWebBluetooth.instance.requestDevice(options);

      // Emit a DeviceInfo for the selected device
      controller.add(
        DeviceInfo(
          id: device.id,
          name: device.name ?? '',
          rssi: -60, // RSSI not available in Web Bluetooth; default to good
        ),
      );

      // Keep a reference for connect()
      _pendingDevice = device;
    } catch (e) {
      if (e.toString().contains('UserCancelledDialogError') ||
          e.toString().contains('DeviceNotFoundError')) {
        // User cancelled or device not found — ignore
      } else {
        if (!controller.isClosed) {
          controller.addError(Exception('Bluetooth error: $e'));
        }
      }
    }

    if (!controller.isClosed) {
      await controller.close();
    }
  }

  // Hold the device object returned by requestDevice() until connect() is called
  BluetoothDevice? _pendingDevice;

  /// Stop scan — no-op on web (the picker auto-dismisses).
  Future<void> stopScan() async {}

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to a device previously selected via [startScan].
  ///
  /// [deviceId] must match the id of the device emitted by [startScan].
  Future<void> connect(String deviceId) async {
    BluetoothDevice? device = _pendingDevice;

    // Handle mock device
    if (deviceId == 'MOCK-UUID-1234') {
      _handleMockConnect();
      return;
    }

    // If somehow _pendingDevice is gone (e.g. reconnect to paired device),
    // try to find it in the known devices stream.
    if (device == null || device.id != deviceId) {
      // Look in already-paired devices
      final knownDevices =
          await FlutterWebBluetooth.instance.devices.first;
      try {
        device = knownDevices.firstWhere((d) => d.id == deviceId);
      } catch (_) {
        throw Exception('Device $deviceId not found. Please scan again.');
      }
    }

    _pendingDevice = null;

    try {
      await device.connect();
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }

    // Discover services
    final services = await device.discoverServices();
    BluetoothService? radioKitService;
    try {
      radioKitService = services.firstWhere(
        (s) => s.uuid.toLowerCase() == kRadioKitServiceUuid.toLowerCase(),
      );
    } catch (_) {
      device.disconnect();
      throw Exception(
        'RadioKit service not found on device. '
        'Make sure the Arduino sketch is running.',
      );
    }

    // Get the UART characteristic
    BluetoothCharacteristic? characteristic;
    try {
      characteristic = await radioKitService
          .getCharacteristic(kRadioKitCharUuid.toLowerCase());
    } catch (_) {
      device.disconnect();
      throw Exception('RadioKit characteristic not found.');
    }

    _device = device;
    _characteristic = characteristic;
    _receiveBuffer.clear();

    // Listen to disconnect events
    device.connected.listen((connected) {
      if (!connected && _device != null) {
        _handleDisconnect('Connection lost');
      }
    });

    // Subscribe to notifications
    await characteristic.startNotifications();
    characteristic.value.listen(
      (data) {
        _receiveBuffer.addAll(data.buffer.asUint8List());
        _processBuffer();
      },
      onError: (error) {
        _handleDisconnect('Notification error: $error');
      },
    );
  }

  /// Disconnect from the device.
  Future<void> disconnect() async {
    try {
      await _characteristic?.stopNotifications();
    } catch (_) {}
    try {
      _device?.disconnect();
    } catch (_) {}
    _device = null;
    _characteristic = null;
    _receiveBuffer.clear();
  }

  bool _isMockConnected = false;

  void _handleMockConnect() {
    _isMockConnected = true;
    // Simulate successful connection and service discovery
  }

  /// [Debug only] Manually inject a packet into the received stream.
  void injectDebugPacket(List<int> packetBytes) {
    final packet = ProtocolService.parsePacket(packetBytes);
    if (packet != null) {
      onPacketReceived?.call(packet);
    }
  }

  void _handleDisconnect(String reason) {
    _isMockConnected = false;
    _device = null;
    _characteristic = null;
    _receiveBuffer.clear();
    onConnectionLost?.call(reason);
  }

  // ---------------------------------------------------------------------------
  // Buffer processing
  // ---------------------------------------------------------------------------

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

      final packet = ProtocolService.parsePacket(packetBytes);
      if (packet != null) {
        onPacketReceived?.call(packet);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------------

  // Mock state for All-Widget Demo Mode
  int _mockButtonValue = 0;
  int _mockSwitchValue = 1;
  int _mockSliderValue = 50;
  int _mockJoyX = 0;
  int _mockJoyY = 0;
  int _mockLedValue = 1;
  String _mockTextValue = 'Demo Mode Active';

  Future<void> writePacket(Uint8List data) async {
    if (_isMockConnected) {
      // Analyze the incoming packet
      if (data.length >= 4 && data[0] == kStartByte) {
        final cmd = data[3];
        final payload = data.sublist(4, data.length - 2);

        // Simulate processing delay
        Future.delayed(const Duration(milliseconds: 30), () {
          if (cmd == kCmdGetConf) {
            _respondWithMockConf();
          } else if (cmd == kCmdGetVars) {
            _respondWithMockVars();
          } else if (cmd == kCmdSetInput) {
            // Update mock state from SET_INPUT payload
            // Layout: [Btn(1)] [Sw(1)] [Sld(1)] [JoyX(1)] [JoyY(1)]
            if (payload.length >= 5) {
              _mockButtonValue = payload[0];
              _mockSwitchValue = payload[1];
              _mockSliderValue = payload[2];
              _mockJoyX = _toSigned(payload[3]);
              _mockJoyY = _toSigned(payload[4]);
              
              // Simple feedback: LED follows switch, text follows slider
              _mockLedValue = _mockSwitchValue;
              _mockTextValue = 'Val: $_mockSliderValue | Joy: $_mockJoyX,$_mockJoyY';
            }
            _respondWithAck();
          } else if (cmd == kCmdPing) {
            _respondWithPong();
          }
        });
      }
      return;
    }

    final char = _characteristic;
    if (char == null) throw StateError('Not connected');

    // Web Bluetooth: write without response
    await char.writeValueWithoutResponse(data);
  }

  void _respondWithMockConf() {
    injectDebugPacket([
      0x55, 0x6C, 0x00, 0x02, 0x01, 0x06, 0x01, 0x01, 0x32, 0x00, 0x32, 0x00,
      0x96, 0x00, 0x64, 0x00, 0x06, 0x42, 0x75, 0x74, 0x74, 0x6f, 0x6e, 0x02,
      0x02, 0xFA, 0x00, 0x32, 0x00, 0xC8, 0x00, 0x64, 0x00, 0x06, 0x53, 0x77,
      0x69, 0x74, 0x63, 0x68, 0x03, 0x03, 0x32, 0x00, 0xC8, 0x00, 0x90, 0x01,
      0x64, 0x00, 0x06, 0x53, 0x6c, 0x69, 0x64, 0x65, 0x72, 0x04, 0x04, 0xF4,
      0x01, 0xC8, 0x00, 0x2C, 0x01, 0x2C, 0x01, 0x07, 0x43, 0x6f, 0x6e, 0x74,
      0x72, 0x6f, 0x6c, 0x05, 0x05, 0x32, 0x00, 0x26, 0x02, 0x64, 0x00, 0x64,
      0x00, 0x03, 0x4C, 0x45, 0x44, 0x06, 0x06, 0xC8, 0x00, 0x26, 0x02, 0x58,
      0x02, 0x64, 0x00, 0x06, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x30, 0x44
    ]);
  }

  void _respondWithMockVars() {
    final textBytes = Uint8List(32);
    final encoded = utf8.encode(_mockTextValue);
    for (int i = 0; i < encoded.length && i < 32; i++) {
      textBytes[i] = encoded[i];
    }

    // Inputs: Btn(1), Sw(1), Sld(1), JoyX(1), JoyY(1)
    // Outputs: Led(1), Text(32)
    final payload = [
      _mockButtonValue,
      _mockSwitchValue,
      _mockSliderValue,
      _mockJoyX < 0 ? _mockJoyX + 256 : _mockJoyX,
      _mockJoyY < 0 ? _mockJoyY + 256 : _mockJoyY,
      _mockLedValue,
      ...textBytes
    ];
    final packet = ProtocolService.buildPacket(kCmdVarData, payload);
    injectDebugPacket(packet);
  }

  void _respondWithAck() {
    final packet = ProtocolService.buildPacket(kCmdAck);
    injectDebugPacket(packet);
  }

  void _respondWithPong() {
    final packet = ProtocolService.buildPacket(kCmdPong);
    injectDebugPacket(packet);
  }

  /// Convert an unsigned byte value (0-255) to a signed int8 (-128..127).
  static int _toSigned(int byte) {
    final b = byte & 0xFF;
    return b >= 128 ? b - 256 : b;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await disconnect();
  }
}
