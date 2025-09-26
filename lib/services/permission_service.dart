import 'dart:io';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/permission_models.dart';

class PermissionService {
  static const String _logTag = 'PermissionService';

  // Convert permission_handler Permission to our AppPermission
  static AppPermission _mapPermissionToAppPermission(ph.Permission permission) {
    switch (permission) {
      case ph.Permission.bluetooth:
        return AppPermission.bluetooth;
      case ph.Permission.bluetoothScan:
        return AppPermission.bluetoothScan;
      case ph.Permission.bluetoothAdvertise:
        return AppPermission.bluetoothAdvertise;
      case ph.Permission.bluetoothConnect:
        return AppPermission.bluetoothConnect;
      case ph.Permission.location:
        return AppPermission.location;
      case ph.Permission.locationWhenInUse:
        return AppPermission.locationWhenInUse;
      case ph.Permission.locationAlways:
        return AppPermission.locationAlways;
      default:
        throw ArgumentError('Unsupported permission: $permission');
    }
  }

  // Convert permission_handler PermissionStatus to our PermissionStatus
  static PermissionStatus _mapPermissionStatus(ph.Permission permission, 
                                               ph.PermissionStatus status) {
    switch (status) {
      case ph.PermissionStatus.granted:
        return PermissionStatus.granted;
      case ph.PermissionStatus.denied:
        return PermissionStatus.denied;
      case ph.PermissionStatus.restricted:
        return PermissionStatus.restricted;
      case ph.PermissionStatus.limited:
        return PermissionStatus.limited;
      case ph.PermissionStatus.permanentlyDenied:
        return PermissionStatus.permanentlyDenied;
      case ph.PermissionStatus.provisional:
        return PermissionStatus.provisional;
    }
  }

  // Helper method to convert adapter state to permission result
  PermissionResult _convertAdapterStateToPermissionResult(BluetoothAdapterState adapterState) {
    switch (adapterState) {
      case BluetoothAdapterState.on:
        return PermissionResult(
          permission: AppPermission.bluetooth,
          status: PermissionStatus.granted,
          timestamp: DateTime.now(),
        );
      case BluetoothAdapterState.off:
        // Bluetooth is turned off, but permission is granted
        return PermissionResult(
          permission: AppPermission.bluetooth,
          status: PermissionStatus.granted,
          message: 'Bluetooth is turned off',
          timestamp: DateTime.now(),
        );
      case BluetoothAdapterState.unauthorized:
        return PermissionResult(
          permission: AppPermission.bluetooth,
          status: PermissionStatus.denied,
          message: 'Bluetooth permission denied',
          timestamp: DateTime.now(),
        );
      case BluetoothAdapterState.unknown:
      case BluetoothAdapterState.unavailable:
      case BluetoothAdapterState.turningOn:
      case BluetoothAdapterState.turningOff:
        return PermissionResult(
          permission: AppPermission.bluetooth,
          status: PermissionStatus.provisional,
          message: 'Bluetooth state: $adapterState',
          timestamp: DateTime.now(),
        );
    }
  }

  // Check iOS Bluetooth permission using flutter_blue_plus
  Future<PermissionResult> _checkiOSBluetoothPermission() async {
    try {
      print('$_logTag: Checking iOS Bluetooth via flutter_blue_plus adapterState');
      
      // Get the current adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      print('$_logTag: iOS adapterState: $adapterState');
      
      // Convert adapter state to permission result
      return _convertAdapterStateToPermissionResult(adapterState);
    } catch (e) {
      print('$_logTag: Error checking iOS Bluetooth permission: $e');
      return PermissionResult(
        permission: AppPermission.bluetooth,
        status: PermissionStatus.denied,
        message: 'Error checking iOS Bluetooth: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  // Request iOS Bluetooth permission using flutter_blue_plus
  Future<PermissionResult> _requestiOSBluetoothPermission() async {
    try {
      print('$_logTag: Requesting iOS Bluetooth permission via flutter_blue_plus');
      
      // On iOS, the permission dialog appears on the first call to any flutter_blue_plus method
      // Let's try checking if bluetooth is supported to trigger the permission dialog
      final isSupported = await FlutterBluePlus.isSupported;
      print('$_logTag: FlutterBluePlus.isSupported: $isSupported');
      
      if (!isSupported) {
        return PermissionResult(
          permission: AppPermission.bluetooth,
          status: PermissionStatus.denied,
          message: 'Bluetooth not supported',
          timestamp: DateTime.now(),
        );
      }
      
      // Now check the adapter state - this will trigger the permission dialog if needed
      final adapterState = await FlutterBluePlus.adapterState.first;
      print('$_logTag: iOS adapterState after permission request: $adapterState');
      
      // Convert adapter state to permission result
      return _convertAdapterStateToPermissionResult(adapterState);
    } catch (e) {
      print('$_logTag: Error requesting iOS Bluetooth permission: $e');
      return PermissionResult(
        permission: AppPermission.bluetooth,
        status: PermissionStatus.denied,
        message: 'Error requesting iOS Bluetooth: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  // Check single permission status
  Future<PermissionResult> checkPermission(ph.Permission permission) async {
    try {
      print('$_logTag: Checking permission: $permission');
      final status = await permission.status;
      print('$_logTag: Permission $permission status: $status');
      
      return PermissionResult(
        permission: _mapPermissionToAppPermission(permission),
        status: _mapPermissionStatus(permission, status),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('$_logTag: Error checking permission $permission: $e');
      return PermissionResult(
        permission: _mapPermissionToAppPermission(permission),
        status: PermissionStatus.denied,
        message: 'Error checking permission: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  // Request single permission
  Future<PermissionResult> requestPermission(ph.Permission permission) async {
    try {
      final status = await permission.request();
      return PermissionResult(
        permission: _mapPermissionToAppPermission(permission),
        status: _mapPermissionStatus(permission, status),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('$_logTag: Error requesting permission $permission: $e');
      return PermissionResult(
        permission: _mapPermissionToAppPermission(permission),
        status: PermissionStatus.denied,
        message: 'Error requesting permission: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  // Get platform-specific Bluetooth permissions
  List<ph.Permission> _getBluetoothPermissions() {
    final permissions = <ph.Permission>[];

    if (Platform.isAndroid) {
      // Android 12+ requires new Bluetooth permissions
      permissions.addAll([
        ph.Permission.bluetoothScan,
        ph.Permission.bluetoothAdvertise,
        ph.Permission.bluetoothConnect,
        ph.Permission.locationWhenInUse, // Required for Bluetooth scanning
      ]);
    } else if (Platform.isIOS) {
      permissions.addAll([
        ph.Permission.locationWhenInUse, // Required for Bluetooth scanning on iOS
      ]);
    }

    return permissions;
  }

  // Check all Bluetooth-related permissions
  Future<BluetoothPermissions> checkBluetoothPermissions() async {
    try {
      print('$_logTag: Checking Bluetooth permissions on ${Platform.operatingSystem}');
      
      if (Platform.isAndroid) {
        print('$_logTag: Checking Android Bluetooth permissions');
        final bluetoothScan = await checkPermission(ph.Permission.bluetoothScan);
        final bluetoothAdvertise = await checkPermission(ph.Permission.bluetoothAdvertise);
        final bluetoothConnect = await checkPermission(ph.Permission.bluetoothConnect);
        final location = await checkPermission(ph.Permission.locationWhenInUse);

        print('$_logTag: Android permissions - Scan: ${bluetoothScan.status}, Advertise: ${bluetoothAdvertise.status}, Connect: ${bluetoothConnect.status}, Location: ${location.status}');

        return BluetoothPermissions(
          bluetooth: bluetoothScan, // Use bluetoothScan as primary for Android
          bluetoothScan: bluetoothScan,
          bluetoothAdvertise: bluetoothAdvertise,
          bluetoothConnect: bluetoothConnect,
          location: location,
        );
      } else if (Platform.isIOS) {
        print('$_logTag: Checking iOS Bluetooth permissions');
        final bluetooth = await _checkiOSBluetoothPermission();
        
        // For iOS, we create a dummy granted location permission since location is not required
        // for basic Bluetooth LE scanning (only needed for iBeacons)
        final location = PermissionResult(
          permission: AppPermission.locationWhenInUse,
          status: PermissionStatus.granted,
          message: 'Location not required for iOS Bluetooth LE scanning',
          timestamp: DateTime.now(),
        );

        print('$_logTag: iOS permissions - Bluetooth: ${bluetooth.status}, Location: ${location.status} (not required)');
        
        final result = BluetoothPermissions(
          bluetooth: bluetooth,
          location: location,
        );
        
        print('$_logTag: iOS BluetoothPermissions.allGranted: ${result.allGranted}');
        return result;
      } else {
        throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
      }
    } catch (e) {
      print('$_logTag: Error checking Bluetooth permissions: $e');
      // Return denied permissions as fallback
      final deniedResult = PermissionResult(
        permission: AppPermission.bluetooth,
        status: PermissionStatus.denied,
        message: 'Error checking permissions: $e',
        timestamp: DateTime.now(),
      );
      
      return BluetoothPermissions(
        bluetooth: deniedResult,
        location: deniedResult,
      );
    }
  }

  // Request all Bluetooth-related permissions
  Future<BluetoothPermissions> requestBluetoothPermissions() async {
    try {
      if (Platform.isAndroid) {
        final permissions = _getBluetoothPermissions();
        final Map<ph.Permission, ph.PermissionStatus> statuses = 
            await permissions.request();

        final bluetoothScanStatus = statuses[ph.Permission.bluetoothScan] ?? 
                                   ph.PermissionStatus.denied;
        final bluetoothAdvertiseStatus = statuses[ph.Permission.bluetoothAdvertise] ?? 
                                        ph.PermissionStatus.denied;
        final bluetoothConnectStatus = statuses[ph.Permission.bluetoothConnect] ?? 
                                      ph.PermissionStatus.denied;
        final locationStatus = statuses[ph.Permission.locationWhenInUse] ?? 
                              ph.PermissionStatus.denied;

        return BluetoothPermissions(
          bluetooth: PermissionResult(
            permission: AppPermission.bluetoothScan,
            status: _mapPermissionStatus(ph.Permission.bluetoothScan, bluetoothScanStatus),
            timestamp: DateTime.now(),
          ),
          bluetoothScan: PermissionResult(
            permission: AppPermission.bluetoothScan,
            status: _mapPermissionStatus(ph.Permission.bluetoothScan, bluetoothScanStatus),
            timestamp: DateTime.now(),
          ),
          bluetoothAdvertise: PermissionResult(
            permission: AppPermission.bluetoothAdvertise,
            status: _mapPermissionStatus(ph.Permission.bluetoothAdvertise, bluetoothAdvertiseStatus),
            timestamp: DateTime.now(),
          ),
          bluetoothConnect: PermissionResult(
            permission: AppPermission.bluetoothConnect,
            status: _mapPermissionStatus(ph.Permission.bluetoothConnect, bluetoothConnectStatus),
            timestamp: DateTime.now(),
          ),
          location: PermissionResult(
            permission: AppPermission.locationWhenInUse,
            status: _mapPermissionStatus(ph.Permission.locationWhenInUse, locationStatus),
            timestamp: DateTime.now(),
          ),
        );
      } else if (Platform.isIOS) {
        print('$_logTag: Requesting iOS permissions');
        final bluetooth = await _requestiOSBluetoothPermission();
        
        // For iOS, we don't need to request location permission for basic Bluetooth LE scanning
        final location = PermissionResult(
          permission: AppPermission.locationWhenInUse,
          status: PermissionStatus.granted,
          message: 'Location not required for iOS Bluetooth LE scanning',
          timestamp: DateTime.now(),
        );

        print('$_logTag: iOS requested permissions - Bluetooth: ${bluetooth.status}, Location: ${location.status} (not required)');

        return BluetoothPermissions(
          bluetooth: bluetooth,
          location: location,
        );
      } else {
        throw UnsupportedError('Platform not supported: ${Platform.operatingSystem}');
      }
    } catch (e) {
      print('$_logTag: Error requesting Bluetooth permissions: $e');
      // Return denied permissions as fallback
      final deniedResult = PermissionResult(
        permission: AppPermission.bluetooth,
        status: PermissionStatus.denied,
        message: 'Error requesting permissions: $e',
        timestamp: DateTime.now(),
      );
      
      return BluetoothPermissions(
        bluetooth: deniedResult,
        location: deniedResult,
      );
    }
  }

  // Open app settings for permission management
  Future<bool> openAppSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (e) {
      print('$_logTag: Error opening app settings: $e');
      return false;
    }
  }

  // Get user-friendly permission name
  String getPermissionDisplayName(AppPermission permission) {
    switch (permission) {
      case AppPermission.bluetooth:
        return 'Bluetooth';
      case AppPermission.bluetoothScan:
        return 'Bluetooth Scanning';
      case AppPermission.bluetoothAdvertise:
        return 'Bluetooth Advertising';
      case AppPermission.bluetoothConnect:
        return 'Bluetooth Connection';
      case AppPermission.location:
      case AppPermission.locationWhenInUse:
        return 'Location';
      case AppPermission.locationAlways:
        return 'Location (Always)';
    }
  }
}