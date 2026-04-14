import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:webserial/webserial.dart';
import '../models/device_info.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
export 'transport_service.dart';

/// Web Serial transport (Chrome / Edge — Web Serial API).
///
/// Uses the `webserial` ^1.1.0 package which wraps `window.navigator.serial`
/// via `dart:js_interop` extension types.
///
/// Flow:
///   1. [listPorts] → calls `serial.requestPort(null)` — shows the browser
///      port picker once and yields the selected port as a [DeviceInfo].
///   2. [connect] → opens the port at 115200 baud and starts the read loop.
///   3. [writePacket] → locks the writable stream, writes, then releases lock.
///
/// [isConnected] returns true for [_kSessionTimeout] after the last valid
/// packet — matching the Arduino firmware's 3-second keep-alive window.
class SerialService implements TransportService {
  static const _kSessionTimeout = Duration(seconds: 3);
  static const _kDefaultBaud = 115200;

  @override PacketReceivedCallback? onPacketReceived;
  @override ConnectionLostCallback? onConnectionLost;

  JSSerialPort? _port;
  Timer? _sessionTimer;
  bool _connected = false;
  bool _reading = false;
  bool _pickerOpen = false;

  final List<int> _receiveBuffer = [];

  @override
  bool get isConnected => _connected;

  bool get isSupported {
    try {
      return serial.isDefinedAndNotNull;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Port discovery — triggers browser picker
  // ---------------------------------------------------------------------------

  /// Opens the browser serial port picker and yields the selected port as a
  /// single [DeviceInfo]. The port is cached internally so [connect] can
  /// open it without showing the picker again.
  Stream<DeviceInfo> listPorts() {
    final controller = StreamController<DeviceInfo>();
    _requestPort(controller);
    return controller.stream;
  }

  Future<void> _requestPort(StreamController<DeviceInfo> controller) async {
    if (!isSupported) {
      controller.addError(Exception(
        'Web Serial is not supported in this browser. Use Chrome or Edge on desktop.',
      ));
      await controller.close();
      return;
    }

    if (_pickerOpen) { await controller.close(); return; }
    _pickerOpen = true;

    try {
      // requestWebSerialPort is the top-level helper from webserial package
      final port = await requestWebSerialPort(null);
      if (port == null) {
        // User cancelled — close silently
        await controller.close();
        return;
      }

      _port = port;

      // Build a display ID from vendor/product IDs when available
      final info = port.getInfo();
      final vid = (info.getProperty<JSNumber?>('usbVendorId'.toJS)?.toDartInt ?? 0)
          .toRadixString(16).padLeft(4, '0');
      final pid = (info.getProperty<JSNumber?>('usbProductId'.toJS)?.toDartInt ?? 0)
          .toRadixString(16).padLeft(4, '0');
      final id = 'serial:$vid:$pid';

      controller.add(DeviceInfo(
        id: id,
        name: 'USB Serial ($vid:$pid)',
        rssi: 0,
      ));
    } catch (e) {
      final msg = e.toString();
      // Suppress "user cancelled" errors (NotFoundError / SecurityError)
      if (!msg.contains('NotFoundError') && !msg.contains('SecurityError')) {
        if (!controller.isClosed) controller.addError(Exception('Serial error: $e'));
      }
    } finally {
      _pickerOpen = false;
      if (!controller.isClosed) await controller.close();
    }
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  @override
  Future<void> connect(String deviceId) async {
    final port = _port;
    if (port == null) {
      throw Exception('No serial port selected. Please choose a port first.');
    }

    // Build JSSerialOptions with baudRate
    final options = JSSerialOptions(
      baudRate: _kDefaultBaud.toJS,
    );
    await port.open(options).toDart;

    _receiveBuffer.clear();
    _connected = false;
    _reading = true;

    // Start continuous read loop in background
    _readLoop(port);
  }

  // ---------------------------------------------------------------------------
  // Read loop
  // ---------------------------------------------------------------------------

  Future<void> _readLoop(JSSerialPort port) async {
    final readable = port.readable;
    if (readable == null) {
      _handleDisconnect('Serial port has no readable stream');
      return;
    }

    final reader = readable.getReader();

    try {
      while (_reading) {
        final result = await reader.read().toDart;
        final done = (result.getProperty<JSBoolean?>('done'.toJS)?.toDart) ?? false;
        if (done) break;

        final jsValue = result.getProperty<JSUint8Array?>('value'.toJS);
        if (jsValue != null) {
          final bytes = jsValue.toDart;
          _receiveBuffer.addAll(bytes);
          _processBuffer();
        }
      }
    } catch (e) {
      if (_reading) _handleDisconnect('Serial read error: $e');
    } finally {
      try { reader.releaseLock(); } catch (_) {}
    }
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

    final writable = port.writable;
    if (writable == null) throw StateError('Serial port has no writable stream');

    final writer = writable.getWriter();
    try {
      await writer.write(data.toJS).toDart;
    } finally {
      writer.releaseLock();
    }
  }

  // ---------------------------------------------------------------------------
  // Disconnect / dispose
  // ---------------------------------------------------------------------------

  void _handleDisconnect(String reason) {
    _reading = false;
    _connected = false;
    _sessionTimer?.cancel();
    try { _port?.close().toDart; } catch (_) {}
    _port = null;
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> disconnect() async {
    _reading = false;
    _connected = false;
    _sessionTimer?.cancel();
    try { await _port?.close().toDart; } catch (_) {}
    _port = null;
    _receiveBuffer.clear();
  }

  @override
  Future<void> dispose() => disconnect();
}
