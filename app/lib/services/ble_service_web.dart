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

      final options = RequestOptionsBuilder(
        [
          RequestFilterBuilder(
            services: [kRadioKitServiceUuid.toLowerCase()],
          ),
        ],
        optionalServices: [kRadioKitServiceUuid.toLowerCase()],
      );

      final device = await FlutterWebBluetooth.instance.requestDevice(options);

      controller.add(
        DeviceInfo(
          id: device.id,
          name: device.name ?? '',
          rssi: -60,
        ),
      );

      _pendingDevice = device;
    } catch (e) {
      if (e.toString().contains('UserCancelledDialogError') ||
          e.toString().contains('DeviceNotFoundError')) {
        // User cancelled — ignore
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

  BluetoothDevice? _pendingDevice;

  /// Stop scan — no-op on web (the picker auto-dismisses).
  Future<void> stopScan() async {}

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to a device previously selected via [startScan].
  Future<void> connect(String deviceId) async {
    BluetoothDevice? device = _pendingDevice;

    if (deviceId == 'MOCK-UUID-1234') {
      _handleMockConnect();
      return;
    }

    if (device == null || device.id != deviceId) {
      final knownDevices = await FlutterWebBluetooth.instance.devices.first;
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

    device.connected.listen((connected) {
      if (!connected && _device != null) {
        _handleDisconnect('Connection lost');
      }
    });

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
    try { await _characteristic?.stopNotifications(); } catch (_) {}
    try { _device?.disconnect(); } catch (_) {}
    _device = null;
    _characteristic = null;
    _receiveBuffer.clear();
  }

  bool _isMockConnected = false;

  void _handleMockConnect() {
    _isMockConnected = true;
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
      if (startIdx < 0) { _receiveBuffer.clear(); return; }
      if (startIdx > 0) { _receiveBuffer.removeRange(0, startIdx); continue; }

      if (_receiveBuffer.length < 3) return;
      final length = _receiveBuffer[1] | (_receiveBuffer[2] << 8);

      if (length < 6) { _receiveBuffer.removeAt(0); continue; }
      if (_receiveBuffer.length < length) return;

      final packetBytes = _receiveBuffer.sublist(0, length);
      _receiveBuffer.removeRange(0, length);

      final packet = ProtocolService.parsePacket(packetBytes);
      if (packet != null) onPacketReceived?.call(packet);
    }
  }

  // ---------------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------------

  int _mockButtonValue = 0;
  int _mockSwitchValue = 1;
  int _mockSliderValue = 50;
  int _mockJoyX        = 0;
  int _mockJoyY        = 0;
  int _mockLedValue    = 1;
  String _mockTextValue = 'Demo Mode Active';

  Future<void> writePacket(Uint8List data) async {
    if (_isMockConnected) {
      if (data.length >= 4 && data[0] == kStartByte) {
        final cmd     = data[3];
        final payload = data.sublist(4, data.length - 2);

        Future.delayed(const Duration(milliseconds: 30), () {
          if (cmd == kCmdGetConf) {
            _respondWithMockConf();
          } else if (cmd == kCmdGetVars) {
            _respondWithMockVars();
          } else if (cmd == kCmdSetInput) {
            // Layout: [Btn(1)] [Sw(1)] [Sld(1)] [JoyX(1)] [JoyY(1)]
            if (payload.length >= 5) {
              _mockButtonValue = payload[0];
              _mockSwitchValue = payload[1];
              _mockSliderValue = payload[2];
              _mockJoyX        = _toSigned(payload[3]);
              _mockJoyY        = _toSigned(payload[4]);
              _mockLedValue    = _mockSwitchValue;
              _mockTextValue   = 'Val: $_mockSliderValue | Joy: $_mockJoyX,$_mockJoyY';
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
    await char.writeValueWithoutResponse(data);
  }

  /// Inject a mock CONF_DATA response using protocol v2 SIZE+ASPECT wire format.
  ///
  /// Header:  [0x02=version][0x00=landscape][0x06=6 widgets]
  /// Descriptors: [TYPE][ID][X][Y][SIZE][ASPECT][ROTATION][LABEL_LEN][LABEL...]
  ///   SIZE   = height in canvas units
  ///   ASPECT = uint8(aspectRatio × 10)  e.g. 2.5 → 25, 1.0 → 10
  ///   W      = SIZE × (ASPECT / 10.0)  computed by the app
  ///
  ///   id=0  Button   center=(38, 25)  size=15 aspect=25  → W=37.5  H=15
  ///   id=1  Switch   center=(63, 75)  size=15 aspect=16  → W=24.0  H=15
  ///   id=2  Slider   center=(12, 51)  size=10 aspect=50  → W=50.0  H=10
  ///   id=3  Joystick center=(127,51)  size=38 aspect=10  → W=38.0  H=38
  ///   id=4  LED      center=(12, 80)  size=12 aspect=10  → W=12.0  H=12
  ///   id=5  Text     center=(51, 80)  size=12 aspect=40  → W=48.0  H=12
  ///
  /// CRC-16/CCITT verified: 0x2E26
  void _respondWithMockConf() {
    injectDebugPacket([
      0x55, 0x5B, 0x00, 0x02,                               // START, LEN=91, CMD=CONF_DATA
      0x02, 0x00, 0x06,                                      // v2: version, landscape, 6 widgets
      0x01, 0x00, 0x26, 0x19, 0x0F, 0x19, 0x00, 0x06,       // Button   id=0 x=38 y=25 size=15 aspect=25 rot=0 llen=6
      0x42, 0x75, 0x74, 0x74, 0x6F, 0x6E,                   // "Button"
      0x02, 0x01, 0x3F, 0x4B, 0x0F, 0x10, 0x00, 0x06,       // Switch   id=1 x=63 y=75 size=15 aspect=16 rot=0 llen=6
      0x53, 0x77, 0x69, 0x74, 0x63, 0x68,                   // "Switch"
      0x03, 0x02, 0x0C, 0x33, 0x0A, 0x32, 0x00, 0x06,       // Slider   id=2 x=12 y=51 size=10 aspect=50 rot=0 llen=6
      0x53, 0x6C, 0x69, 0x64, 0x65, 0x72,                   // "Slider"
      0x04, 0x03, 0x7F, 0x33, 0x26, 0x0A, 0x00, 0x07,       // Joystick id=3 x=127 y=51 size=38 aspect=10 rot=0 llen=7
      0x43, 0x6F, 0x6E, 0x74, 0x72, 0x6F, 0x6C,             // "Control"
      0x05, 0x04, 0x0C, 0x50, 0x0C, 0x0A, 0x00, 0x03,       // LED      id=4 x=12 y=80 size=12 aspect=10 rot=0 llen=3
      0x4C, 0x45, 0x44,                                      // "LED"
      0x06, 0x05, 0x33, 0x50, 0x0C, 0x28, 0x00, 0x06,       // Text     id=5 x=51 y=80 size=12 aspect=40 rot=0 llen=6
      0x53, 0x74, 0x61, 0x74, 0x75, 0x73,                   // "Status"
      0x26, 0x2E,                                            // CRC-16/CCITT = 0x2E26
    ]);
  }

  void _respondWithMockVars() {
    final textBytes = Uint8List(32);
    final encoded   = utf8.encode(_mockTextValue);
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
    injectDebugPacket(ProtocolService.buildPacket(kCmdVarData, payload));
  }

  void _respondWithAck()  => injectDebugPacket(ProtocolService.buildPacket(kCmdAck));
  void _respondWithPong() => injectDebugPacket(ProtocolService.buildPacket(kCmdPong));

  static int _toSigned(int byte) {
    final b = byte & 0xFF;
    return b >= 128 ? b - 256 : b;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async => disconnect();
}
