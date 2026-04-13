/// Platform-conditional BLE service export.
///
/// On web (dart.library.js_interop available) → ble_service_web.dart
/// On native (Android/iOS)                   → ble_service_native.dart
/// Unsupported platform                       → ble_service_stub.dart
export 'ble_service_stub.dart'
    if (dart.library.js_interop) 'ble_service_web.dart'
    if (dart.library.io) 'ble_service_native.dart';
