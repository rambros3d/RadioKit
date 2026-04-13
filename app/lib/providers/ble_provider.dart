import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device_info.dart';
import '../services/ble_service.dart';
// permission_handler is not available on web; import conditionally
import 'package:permission_handler/permission_handler.dart'
    if (dart.library.js_interop) '../utils/permission_handler_stub.dart';

/// Manages BLE scanning state and the list of discovered devices.
class BleProvider extends ChangeNotifier {
  final BleService _bleService = BleService();

  List<DeviceInfo> _devices = [];
  bool _isScanning = false;
  String? _errorMessage;

  StreamSubscription<DeviceInfo>? _scanSubscription;

  List<DeviceInfo> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;
  String? get errorMessage => _errorMessage;
  BleService get bleService => _bleService;

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Request all required BLE permissions.
  ///
  /// On web, permissions are handled by the browser device picker,
  /// so this always returns true.
  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;

    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];

    final statuses = await permissions.request();

    for (final entry in statuses.entries) {
      if (entry.value.isDenied || entry.value.isPermanentlyDenied) {
        _errorMessage =
            'Bluetooth permissions are required. Please enable them in Settings.';
        notifyListeners();
        return false;
      }
    }

    _errorMessage = null;
    return true;
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Start scanning for RadioKit BLE devices.
  Future<void> startScan() async {
    if (_isScanning) return;

    final hasPermissions = await requestPermissions();
    if (!hasPermissions) return;

    _devices = [];
    _errorMessage = null;
    _isScanning = true;
    notifyListeners();

    await _scanSubscription?.cancel();

    _scanSubscription = _bleService.startScan().listen(
      (device) {
        // Only add if not already present (same ID)
        final idx = _devices.indexWhere((d) => d.id == device.id);
        if (idx >= 0) {
          _devices[idx] = device; // Update RSSI
        } else {
          _devices.add(device);
        }
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Scan error: $error';
        _isScanning = false;
        notifyListeners();
      },
    );

    // Auto-stop scan after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isScanning) stopScan();
    });
  }

  /// Stop an active scan.
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _bleService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }
}
