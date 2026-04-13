import 'dart:async';
import 'dart:typed_data';
import '../models/device_info.dart';
import 'protocol_service.dart';

/// Callback types shared across all BLE service implementations.
typedef PacketReceivedCallback = void Function(ParsedPacket packet);
typedef ConnectionLostCallback = void Function(String reason);

/// Unsupported-platform stub.
///
/// All methods throw [UnsupportedError]. This is never used at runtime because
/// the conditional export selects the correct implementation, but it satisfies
/// the Dart analyser for platforms where neither dart:io nor dart:js_interop
/// is available.
class BleService {
  PacketReceivedCallback? onPacketReceived;
  ConnectionLostCallback? onConnectionLost;

  bool get isConnected => false;
  String? get connectedDeviceId => null;

  Stream<DeviceInfo> startScan() =>
      throw UnsupportedError('BLE not supported on this platform');

  Future<void> stopScan() =>
      throw UnsupportedError('BLE not supported on this platform');

  Future<void> connect(String deviceId) =>
      throw UnsupportedError('BLE not supported on this platform');

  Future<void> disconnect() =>
      throw UnsupportedError('BLE not supported on this platform');

  Future<void> writePacket(Uint8List data) =>
      throw UnsupportedError('BLE not supported on this platform');

  Future<void> dispose() =>
      throw UnsupportedError('BLE not supported on this platform');
}
