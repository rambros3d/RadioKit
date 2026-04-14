import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../services/serial_service.dart';

/// Manages Serial port discovery state and the [SerialService] instance.
///
/// Mirrors [BleProvider] so that [ScanScreen] can treat both uniformly.
class SerialProvider extends ChangeNotifier {
  final SerialService _serialService = SerialService();

  List<DeviceInfo> _ports = [];
  bool _isScanning = false;
  String? _errorMessage;

  StreamSubscription<DeviceInfo>? _scanSubscription;

  List<DeviceInfo> get ports => List.unmodifiable(_ports);
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  SerialService get serialService => _serialService;
  bool get isSupported => _serialService.isSupported;

  // ---------------------------------------------------------------------------
  // Port discovery
  // ---------------------------------------------------------------------------

  /// On native: enumerates attached USB-CDC devices and populates [ports].
  /// On web: opens the browser port picker (one-shot).
  Future<void> startScan() async {
    if (_isScanning) return;

    _ports = [];
    _errorMessage = null;
    _isScanning = true;
    notifyListeners();

    await _scanSubscription?.cancel();

    _scanSubscription = _serialService.listPorts().listen(
      (port) {
        final idx = _ports.indexWhere((p) => p.id == port.id);
        if (idx >= 0) {
          _ports[idx] = port;
        } else {
          _ports.add(port);
        }
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Serial scan error: $error';
        _isScanning = false;
        notifyListeners();
      },
      onDone: () {
        _isScanning = false;
        notifyListeners();
      },
    );
  }

  /// Stop an active scan (no-op on web where the picker is one-shot).
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    _isScanning = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _serialService.dispose();
    super.dispose();
  }
}
