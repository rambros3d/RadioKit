/// Stub for permission_handler on web.
///
/// Web doesn't need runtime permission requests — the browser handles
/// Bluetooth access via its device picker. These types are exposed so
/// that ble_provider.dart compiles on web without conditional compilation
/// throughout the file.

// ignore_for_file: avoid_classes_with_only_static_members

class Permission {
  static final Permission bluetooth = Permission._();
  static final Permission bluetoothScan = Permission._();
  static final Permission bluetoothConnect = Permission._();
  static final Permission locationWhenInUse = Permission._();

  Permission._();

  Future<PermissionStatus> request() async => PermissionStatus._granted();

  Future<Map<Permission, PermissionStatus>> request2() async => {};
}

extension PermissionListExt on List<Permission> {
  Future<Map<Permission, PermissionStatus>> request() async {
    return {for (final p in this) p: PermissionStatus._granted()};
  }
}

class PermissionStatus {
  final bool _granted;

  PermissionStatus._granted() : _granted = true;

  bool get isDenied => !_granted;
  bool get isPermanentlyDenied => false;
  bool get isGranted => _granted;
}
