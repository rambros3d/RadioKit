import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_web_serial/flutter_web_serial.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Web Serial transport (Chrome / Edge).
///
/// The Web Serial API works like Web Bluetooth:
///   - A one-shot browser port picker dialog is shown when [requestPort] is called.
///   - The selected port persists for the browser session.
///   - Requires a secure context (https or localhost).
///
/// isConnected returns true for [_kSessionTimeout] after the last
/// valid packet — matching the Arduino firmware's 3-second window.
class SerialService implements TransportService {
  static const _kSessionTimeout = Duration(seconds: 3);
  static const _kDefaultBaud = 115200;

  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  SerialPort? _port;
  StreamSubscription<Uint8List>? _rxSub;
  Timer? _sessionTimer;
  bool _connected = false;
  bool _pickerOpen = false;

  final List<int> _receiveBuffer = [];

  bool get isSupported => WebSerial.isSupported;

  @override
  bool get isConnected => _connected;

  // ---------------------------------------------------------------------------
  // Port discovery (triggers browser picker)
  // ---------------------------------------------------------------------------

  /// Open the browser's serial port picker and yield the selected port as
  /// a single [DeviceInfo]. Uses a synthetic ID of the form
  /// `serial:<usbVendorId>:<usbProductId>` when available.
  Stream<DeviceInfo> listPorts() {
    final controller = StreamController<DeviceInfo>();
    _requestPort(controller);
    return controller.stream;
  }

  Future<void> _requestPort(StreamController<DeviceInfo> controller) async {
    if (!WebSerial.isSupported) {
      controller.addError(Exception(
        'Web Serial is not supported in this browser.\n'
        'Please use Chrome or Edge on desktop.',
      ));
      await controller.close();
      return;
    }

    if (_pickerOpen) { await controller.close(); return; }
    _pickerOpen = true;

    try {
      final port = await WebSerial.requestPort();
      _pendingPort = port;

      final info = port.getInfo();
      final vendorId  = info.usbVendorId  ?? 0;
      final productId = info.usbProductId ?? 0;
      final id = 'serial:${vendorId.toRadixString(16).padLeft(4, '0')}:${productId.toRadixString(16).padLeft(4, '0')}';

      controller.add(DeviceInfo(
        id: id,
        name: 'USB Serial ($id)',
        rssi: 0,
      ));
    } catch (e) {
      final msg = e.toString();
      if (!msg.contains('NotFoundError') && !msg.contains('SecurityError')) {
        if (!controller.isClosed) controller.addError(Exception('Serial error: $e'));
      }
      // User cancelled — close silently
    } finally {
      _pickerOpen = false;
      if (!controller.isClosed) await controller.close();
    }
  }

  SerialPort? _pendingPort;

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId) async {
    final port = _pendingPort;
    _pendingPort = null;

    if (port == null) {
      throw Exception('No serial port selected. Please choose a port first.');
    }

    await port.open(baudRate: _kDefaultBaud);

    _port = port;
    _receiveBuffer.clear();
    _connected = false;

    _rxSub = port.readable?.listen(
      _onBytesReceived,
      onError: (e) => _handleDisconnect('Serial read error: $e'),
      onDone: ()   => _handleDisconnect('Serial port closed'),
    );
  }

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
    await port.writable?.write(data);
  }

  // ---------------------------------------------------------------------------
  // Disconnect
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _connected = false;
    _sessionTimer?.cancel();
    _rxSub?.cancel();
    _rxSub = null;
    try { _port?.close(); } catch (_) {}
    _port = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionTimer?.cancel();
    await _rxSub?.cancel();
    _rxSub = null;
    try { await _port?.close(); } catch (_) {}
    _port = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
