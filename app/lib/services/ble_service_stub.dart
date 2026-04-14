import 'dart:async';
import 'dart:typed_data';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Unsupported-platform stub.
///
/// All methods throw [UnsupportedError]. This is never used at runtime because
/// the conditional export selects the correct implementation, but it satisfies
/// the Dart analyser for platforms where neither dart:io nor dart:js_interop
/// is available.
class BleService implements TransportService {
  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  @override bool get isConnected => false;
  String? get connectedDeviceId => null;
  bool get isSupported => false;
  Future<bool> get isAvailable async => false;

  Stream<DeviceInfo> startScan() =>
      throw UnsupportedError('BLE not supported on this platform');

  Future<void> stopScan() =>
      throw UnsupportedError('BLE not supported on this platform');

  @override
  Future<void> connect(String deviceId) =>
      throw UnsupportedError('BLE not supported on this platform');

  @override
  Future<void> disconnect() =>
      throw UnsupportedError('BLE not supported on this platform');

  @override
  Future<void> writePacket(Uint8List data) =>
      throw UnsupportedError('BLE not supported on this platform');

  @override
  Future<void> dispose() =>
      throw UnsupportedError('BLE not supported on this platform');
}
