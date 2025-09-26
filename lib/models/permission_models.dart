import 'dart:io';

// Permission status enumeration
enum PermissionStatus {
  granted,
  denied,
  restricted,
  limited,
  permanentlyDenied,
  provisional,
}

// Permission types for our application
enum AppPermission {
  bluetooth,
  bluetoothScan,
  bluetoothAdvertise,
  bluetoothConnect,
  location,
  locationWhenInUse,
  locationAlways,
}

// Permission result model
class PermissionResult {
  final AppPermission permission;
  final PermissionStatus status;
  final String? message;
  final DateTime timestamp;

  const PermissionResult({
    required this.permission,
    required this.status,
    this.message,
    required this.timestamp,
  });

  bool get isGranted => status == PermissionStatus.granted || 
                       status == PermissionStatus.provisional;
  bool get isDenied => status == PermissionStatus.denied || 
                      status == PermissionStatus.permanentlyDenied;
  bool get isPermanentlyDenied => status == PermissionStatus.permanentlyDenied;

  @override
  String toString() {
    return 'PermissionResult{permission: $permission, status: $status, message: $message}';
  }
}

// Bluetooth permissions state model
class BluetoothPermissions {
  final PermissionResult bluetooth;
  final PermissionResult? bluetoothScan;
  final PermissionResult? bluetoothAdvertise;
  final PermissionResult? bluetoothConnect;
  final PermissionResult location;

  const BluetoothPermissions({
    required this.bluetooth,
    this.bluetoothScan,
    this.bluetoothAdvertise,
    this.bluetoothConnect,
    required this.location,
  });

  bool get allGranted {
    // On iOS, we only need Bluetooth permission
    if (Platform.isIOS) {
      return bluetooth.isGranted;
    }
    
    // On Android, check all required permissions
    final requiredPermissions = [bluetooth, location];
    final androidPermissions = [bluetoothScan, bluetoothAdvertise, bluetoothConnect];
    
    // Check required permissions
    for (final permission in requiredPermissions) {
      if (!permission.isGranted) return false;
    }

    // Check Android-specific permissions if they exist
    for (final permission in androidPermissions) {
      if (permission != null && !permission.isGranted) return false;
    }

    return true;
  }

  bool get hasAnyDenied {
    if (Platform.isIOS) {
      return bluetooth.isDenied;
    }
    
    final allPermissions = [
      bluetooth,
      location,
      if (bluetoothScan != null) bluetoothScan!,
      if (bluetoothAdvertise != null) bluetoothAdvertise!,
      if (bluetoothConnect != null) bluetoothConnect!,
    ];

    return allPermissions.any((p) => p.isDenied);
  }

  List<AppPermission> get deniedPermissions {
    final denied = <AppPermission>[];
    
    if (bluetooth.isDenied) denied.add(bluetooth.permission);
    
    // Only include location for Android
    if (Platform.isAndroid && location.isDenied) {
      denied.add(location.permission);
    }
    
    if (bluetoothScan?.isDenied == true) denied.add(bluetoothScan!.permission);
    if (bluetoothAdvertise?.isDenied == true) denied.add(bluetoothAdvertise!.permission);
    if (bluetoothConnect?.isDenied == true) denied.add(bluetoothConnect!.permission);

    return denied;
  }
}