import 'dart:async';
import 'dart:typed_data';
import 'package:usb_serial/usb_serial.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Native USB-CDC Serial transport (Android + desktop).
///
/// Uses the `usb_serial` package to enumerate USB-CDC devices and open
/// a bidirectional byte stream. Received bytes are fed into the same
/// RadioKit framing buffer used by the BLE service.
///
/// isConnected returns true for [_kSessionTimeout] after the last
/// valid packet — matching the Arduino firmware's 3-second window.
class SerialService implements TransportService {
  static const _kSessionTimeout = Duration(seconds: 3);
  static const _kDefaultBaud = 115200;

  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  UsbDevice? _device;
  UsbPort? _port;
  StreamSubscription<Uint8List>? _rxSub;
  Timer? _sessionTimer;
  bool _connected = false;

  final List<int> _receiveBuffer = [];

  bool get isSupported => true;

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// Returns a one-shot stream of available USB-CDC [DeviceInfo] objects.
  ///
  /// The [DeviceInfo.id] encodes the USB device serial number / port path
  /// used by [connect].
  Stream<DeviceInfo> listPorts() async* {
    final devices = await UsbSerial.listDevices();
    for (final d in devices) {
      yield DeviceInfo(
        id: '${d.vid}:${d.pid}:${d.serial ?? d.deviceName ?? 'usb'}',
        name: d.productName ?? d.deviceName ?? 'USB Serial Device',
        rssi: 0, // not applicable for serial
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId) async {
    final devices = await UsbSerial.listDevices();
    final target = devices.firstWhere(
      (d) => '${d.vid}:${d.pid}:${d.serial ?? d.deviceName ?? 'usb'}' == deviceId,
      orElse: () => throw Exception('USB device "$deviceId" not found.'),
    );

    final port = await target.create();
    if (port == null) throw Exception('Failed to open USB port.');

    final opened = await port.open();
    if (!opened) throw Exception('USB port refused to open.');

    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(
      _kDefaultBaud,
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    _device = target;
    _port   = port;
    _receiveBuffer.clear();
    _connected = false;

    _rxSub = port.inputStream?.listen(
      _onBytesReceived,
      onError: (e) => _handleDisconnect('Serial read error: $e'),
      onDone: ()   => _handleDisconnect('Serial port closed'),
    );
  }

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Receive path
  // ---------------------------------------------------------------------------

  void _onBytesReceived(Uint8List data) {
    _receiveBuffer.addAll(data);
    _processBuffer();
  }

  void _processBuffer() {
    while (_receiveBuffer.length >= 6) {
      final startIdx = _receiveBuffer.indexOf(0x55);
      if (startIdx < 0) { _receiveBuffer.clear(); return; }
      if (startIdx > 0) { _receiveBuffer.removeRange(0, startIdx); continue; }

      if (_receiveBuffer.length < 3) return;
      final length = _receiveBuffer[1] | (_receiveBuffer[2] << 8);

      if (length < 6) { _receiveBuffer.removeAt(0); continue; }
      if (_receiveBuffer.length < length) return;

      final packetBytes = _receiveBuffer.sublist(0, length);
      _receiveBuffer.removeRange(0, length);

      final packet = ProtocolService.parsePacket(packetBytes);
      if (packet != null) {
        _connected = true;
        _resetSessionTimer();
        onPacketReceived?.call(packet);
      }
    }
  }

  void _resetSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(_kSessionTimeout, () {
      if (_connected) {
        _connected = false;
        onConnectionLost?.call('Serial session timed out (no packet for 3 s)');
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Write path
  // ---------------------------------------------------------------------------

  @override
  Future<void> writePacket(Uint8List data) async {
    final port = _port;
    if (port == null) throw StateError('Serial port not open');
    await port.write(data);
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _connected = false;
    _sessionTimer?.cancel();
    _rxSub?.cancel();
    _rxSub = null;
    _port?.close();
    _port   = null;
    _device = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    await _rxSub?.cancel();
    _rxSub = null;
    try { await _port?.close(); } catch (_) {}
    _port   = null;
    _device = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
