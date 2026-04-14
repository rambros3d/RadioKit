import 'dart:typed_data';
import 'protocol_service.dart';

/// Callback types shared across all transport implementations.
typedef PacketReceivedCallback = void Function(ParsedPacket packet);
typedef ConnectionLostCallback = void Function(String reason);

/// Abstract transport used by [DeviceProvider].
///
/// Implemented by [BleService] and [SerialService]. The provider
/// is agnostic to the underlying physical transport.
abstract class TransportService {
  PacketReceivedCallback? onPacketReceived;
  ConnectionLostCallback? onConnectionLost;

  /// True while a peer session is active.
  bool get isConnected;

  /// Connect to the device identified by [deviceId].
  Future<void> connect(String deviceId);

  /// Disconnect and release resources.
  Future<void> disconnect();

  /// Write a framed RadioKit packet to the transport.
  Future<void> writePacket(Uint8List data);

  /// Release all resources (called when the provider is disposed).
  Future<void> dispose();
}
