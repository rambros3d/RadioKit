import 'dart:async';
import 'dart:typed_data';
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
  PacketReceivedCallback? onPacketReceived;
  ConnectionLostCallback? onConnectionLost;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;

  // Buffer for assembling multi-chunk BLE packets
  final List<int> _receiveBuffer = [];

  bool get isConnected => _device != null && _characteristic != null;
  String? get connectedDeviceId => _device?.id;

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
    } on UserCancelledDialogError {
      // User dismissed the picker — not an error, just an empty scan result
    } on DeviceNotFoundError {
      // No matching devices in range
    } catch (e) {
      if (!controller.isClosed) {
        controller.addError(Exception('Bluetooth error: $e'));
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
      await device.disconnect();
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
      await device.disconnect();
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
      await _device?.disconnect();
    } catch (_) {}
    _device = null;
    _characteristic = null;
    _receiveBuffer.clear();
  }

  void _handleDisconnect(String reason) {
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

  Future<void> writePacket(Uint8List data) async {
    final char = _characteristic;
    if (char == null) throw StateError('Not connected');

    // Web Bluetooth: write without response
    await char.writeValueWithoutResponse(data);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await disconnect();
  }
}
