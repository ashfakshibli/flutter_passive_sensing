import 'package:flutter/foundation.dart';
import '../models/permission_models.dart';
import '../services/permission_service.dart';

class PermissionViewModel extends ChangeNotifier {
  final PermissionService _permissionService;
  
  BluetoothPermissions? _bluetoothPermissions;
  bool _isLoading = false;
  String? _errorMessage;

  PermissionViewModel({PermissionService? permissionService})
      : _permissionService = permissionService ?? PermissionService();

  // Getters
  BluetoothPermissions? get bluetoothPermissions => _bluetoothPermissions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get hasBluetoothPermissions => 
      _bluetoothPermissions?.allGranted ?? false;
  
  bool get hasLocationPermission => 
      _bluetoothPermissions?.location.isGranted ?? false;
  
  bool get hasBasicBluetoothPermission => 
      _bluetoothPermissions?.bluetooth.isGranted ?? false;

  List<AppPermission> get deniedPermissions => 
      _bluetoothPermissions?.deniedPermissions ?? [];

  // Private methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String? error) {
    if (_errorMessage != error) {
      _errorMessage = error;
      notifyListeners();
    }
  }

  void _setBluetoothPermissions(BluetoothPermissions permissions) {
    _bluetoothPermissions = permissions;
    _setError(null); // Clear any previous errors
    notifyListeners();
  }

  // Public methods
  Future<void> checkBluetoothPermissions() async {
    try {
      _setLoading(true);
      _setError(null);

      final permissions = await _permissionService.checkBluetoothPermissions();
      _setBluetoothPermissions(permissions);
      
      debugPrint('PermissionViewModel: Checked permissions - All granted: ${permissions.allGranted}');
    } catch (e) {
      _setError('Failed to check permissions: $e');
      debugPrint('PermissionViewModel: Error checking permissions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> requestBluetoothPermissions() async {
    try {
      _setLoading(true);
      _setError(null);

      final permissions = await _permissionService.requestBluetoothPermissions();
      _setBluetoothPermissions(permissions);
      
      final success = permissions.allGranted;
      debugPrint('PermissionViewModel: Requested permissions - Success: $success');
      
      if (!success) {
        final deniedList = permissions.deniedPermissions
            .map((p) => _permissionService.getPermissionDisplayName(p))
            .join(', ');
        _setError('The following permissions were denied: $deniedList');
      }
      
      return success;
    } catch (e) {
      _setError('Failed to request permissions: $e');
      debugPrint('PermissionViewModel: Error requesting permissions: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> openAppSettings() async {
    try {
      _setError(null);
      
      final success = await _permissionService.openAppSettings();
      if (!success) {
        _setError('Failed to open app settings');
      }
    } catch (e) {
      _setError('Error opening settings: $e');
      debugPrint('PermissionViewModel: Error opening settings: $e');
    }
  }

  void clearError() {
    _setError(null);
  }

  String getPermissionDisplayName(AppPermission permission) {
    return _permissionService.getPermissionDisplayName(permission);
  }

  String getPermissionStatusDescription() {
    final permissions = _bluetoothPermissions;
    if (permissions == null) {
      return 'Permissions not checked yet';
    }

    if (permissions.allGranted) {
      return 'All required permissions granted';
    }

    final deniedCount = permissions.deniedPermissions.length;
    if (deniedCount == 1) {
      final deniedName = getPermissionDisplayName(permissions.deniedPermissions.first);
      return '$deniedName permission is required';
    } else if (deniedCount > 1) {
      return '$deniedCount permissions are required';
    }

    return 'Some permissions need attention';
  }

  // Utility method to refresh permissions after returning from settings
  Future<void> refreshPermissions() async {
    await checkBluetoothPermissions();
  }
}