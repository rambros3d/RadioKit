import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../models/protocol.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';

/// Callback types used by [BleService].
typedef DeviceDiscoveredCallback = void Function(DeviceInfo device);
typedef PacketReceivedCallback = void Function(ParsedPacket packet);
typedef ConnectionLostCallback = void Function(String reason);

/// Low-level BLE service: scanning, connection management, and
/// characteristic read/write.
///
/// All heavy protocol logic lives in [ProtocolService]; this class handles
/// the BLE transport layer only.
class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // UUIDs
  static final Uuid _serviceUuid =
      Uuid.parse(kRadioKitServiceUuid.toLowerCase());
  static final Uuid _charUuid = Uuid.parse(kRadioKitCharUuid.toLowerCase());

  // Subscriptions
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  // State
  String? _connectedDeviceId;
  QualifiedCharacteristic? _characteristic;

  // Buffer for assembling multi-chunk BLE packets
  final List<int> _receiveBuffer = [];

  // Callbacks
  PacketReceivedCallback? onPacketReceived;
  ConnectionLostCallback? onConnectionLost;

  bool get isConnected => _connectedDeviceId != null;
  String? get connectedDeviceId => _connectedDeviceId;

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Start scanning for RadioKit BLE devices.
  ///
  /// [onDeviceFound] is called for each unique RadioKit-compatible device found.
  /// [onDone] is called when the scan completes or times out.
  Stream<DeviceInfo> startScan() {
    final controller = StreamController<DeviceInfo>.broadcast();
    final seen = <String>{};

    _scanSubscription?.cancel();

    _scanSubscription = _ble.scanForDevices(
      withServices: [_serviceUuid],
      scanMode: ScanMode.balanced,
    ).listen(
      (device) {
        if (!seen.contains(device.id)) {
          seen.add(device.id);
          final info = DeviceInfo(
            id: device.id,
            name: device.name,
            rssi: device.rssi,
          );
          if (!controller.isClosed) {
            controller.add(info);
          }
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );

    return controller.stream;
  }

  /// Stop any active scan.
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  /// Connect to a device and set up the UART characteristic.
  ///
  /// Completes with [true] on success. Throws on failure.
  Future<void> connect(String deviceId) async {
    final completer = Completer<void>();

    await _connectionSubscription?.cancel();

    _connectionSubscription = _ble
        .connectToDevice(
      id: deviceId,
      servicesWithCharacteristicsToDiscover: {
        _serviceUuid: [_charUuid]
      },
      connectionTimeout: const Duration(seconds: 10),
    )
        .listen(
      (update) {
        switch (update.connectionState) {
          case DeviceConnectionState.connected:
            _connectedDeviceId = deviceId;
            _characteristic = QualifiedCharacteristic(
              serviceId: _serviceUuid,
              characteristicId: _charUuid,
              deviceId: deviceId,
            );
            _setupNotifications();
            if (!completer.isCompleted) completer.complete();
            break;

          case DeviceConnectionState.disconnected:
            if (_connectedDeviceId != null) {
              final reason = update.failure?.message ?? 'Connection lost';
              _handleDisconnect(reason);
            }
            if (!completer.isCompleted) {
              completer.completeError(
                  Exception(update.failure?.message ?? 'Failed to connect'));
            }
            break;

          default:
            break;
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Disconnect from the currently connected device.
  Future<void> disconnect() async {
    await _notifySubscription?.cancel();
    _notifySubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _connectedDeviceId = null;
    _characteristic = null;
    _receiveBuffer.clear();
  }

  void _handleDisconnect(String reason) {
    _connectedDeviceId = null;
    _characteristic = null;
    _receiveBuffer.clear();
    _notifySubscription?.cancel();
    _notifySubscription = null;
    onConnectionLost?.call(reason);
  }

  // ---------------------------------------------------------------------------
  // Notifications (incoming data)
  // ---------------------------------------------------------------------------

  void _setupNotifications() {
    final char = _characteristic;
    if (char == null) return;

    _notifySubscription = _ble.subscribeToCharacteristic(char).listen(
      (data) {
        _receiveBuffer.addAll(data);
        _processBuffer();
      },
      onError: (error) {
        _handleDisconnect('Notification error: $error');
      },
    );
  }

  /// Process the receive buffer, extracting complete packets.
  void _processBuffer() {
    while (_receiveBuffer.length >= 6) {
      // Find START byte
      final startIdx = _receiveBuffer.indexOf(kStartByte);
      if (startIdx < 0) {
        _receiveBuffer.clear();
        return;
      }

      // Remove leading garbage before START
      if (startIdx > 0) {
        _receiveBuffer.removeRange(0, startIdx);
        continue;
      }

      // Read LENGTH (little-endian)
      if (_receiveBuffer.length < 3) return;
      final length = _receiveBuffer[1] | (_receiveBuffer[2] << 8);

      if (length < 6) {
        // Invalid length — skip this start byte
        _receiveBuffer.removeAt(0);
        continue;
      }

      if (_receiveBuffer.length < length) {
        // Incomplete packet — wait for more data
        return;
      }

      // Extract complete packet
      final packetBytes = _receiveBuffer.sublist(0, length);
      _receiveBuffer.removeRange(0, length);

      final packet = ProtocolService.parsePacket(packetBytes);
      if (packet != null) {
        onPacketReceived?.call(packet);
      }
      // CRC mismatch packets are silently dropped by parsePacket
    }
  }

  // ---------------------------------------------------------------------------
  // Writing
  // ---------------------------------------------------------------------------

  /// Write [data] to the RadioKit characteristic.
  Future<void> writePacket(Uint8List data) async {
    final char = _characteristic;
    if (char == null) throw StateError('Not connected');

    await _ble.writeCharacteristicWithoutResponse(char, value: data);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> dispose() async {
    await stopScan();
    await disconnect();
  }
}
