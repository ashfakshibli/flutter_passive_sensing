import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bluetooth_device_model.dart';
import '../models/scan_history_model.dart';
import '../models/battery_optimization_config.dart';
import '../services/bluetooth_scanning_service.dart';
import '../services/database_service.dart';

// Scanning state enumeration
enum ScanningState {
  idle,
  initializing,
  scanning,
  stopping,
  error,
}

// Bluetooth scanning viewmodel
class BluetoothScanningViewModel extends ChangeNotifier {
  final BluetoothScanningService _scanningService;
  final DatabaseService _databaseService;
  
  // State variables
  ScanningState _state = ScanningState.idle;
  List<BluetoothDeviceModel> _devices = [];
  BluetoothDeviceModel? _selectedDevice;
  String? _errorMessage;
  Map<String, dynamic> _scanStatistics = {};
  BluetoothScanConfig _scanConfig = const BluetoothScanConfig();
  List<ScanHistoryPoint> _scanHistory = [];
  
  // Stream subscriptions
  StreamSubscription<BluetoothDeviceModel>? _deviceSubscription;
  StreamSubscription<bool>? _statusSubscription;
  StreamSubscription<int>? _countSubscription;
  StreamSubscription<String>? _errorSubscription;
  Timer? _historyTimer;
  
  // Filtering and sorting
  String _nameFilter = '';
  String _deviceTypeFilter = '';
  int _minRssi = -100;
  bool _showRecentOnly = false;
  String _sortBy = 'rssi'; // 'rssi', 'name', 'lastSeen', 'scanCount'
  bool _sortAscending = false;
  
  BluetoothScanningViewModel({BluetoothScanningService? scanningService})
      : _scanningService = scanningService ?? BluetoothScanningService(),
        _databaseService = DatabaseService.instance {
    _initializeSubscriptions();
    _initializeDatabase();
  }
  
  // Getters
  ScanningState get state => _state;
  List<BluetoothDeviceModel> get devices => _getFilteredAndSortedDevices();
  List<BluetoothDeviceModel> get allDevices => _devices;
  BluetoothDeviceModel? get selectedDevice => _selectedDevice;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic> get scanStatistics => _scanStatistics;
  BluetoothScanConfig get scanConfig => _scanConfig;
  List<ScanHistoryPoint> get scanHistory => _scanHistory;
  
  bool get isScanning => _state == ScanningState.scanning;
  bool get isInitializing => _state == ScanningState.initializing;
  bool get hasError => _state == ScanningState.error;
  bool get hasDevices => _devices.isNotEmpty;
  int get deviceCount => _devices.length;
  int get filteredDeviceCount => devices.length;
  
  // Filtering getters
  String get nameFilter => _nameFilter;
  String get deviceTypeFilter => _deviceTypeFilter;
  int get minRssi => _minRssi;
  bool get showRecentOnly => _showRecentOnly;
  String get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  
  // Get unique device types from discovered devices
  List<String> getAvailableDeviceTypes() {
    final deviceTypes = <String>{};
    for (final device in _devices) {
      if (device.deviceType.isNotEmpty) {
        deviceTypes.add(device.deviceType);
      }
    }
    return deviceTypes.toList()..sort();
  }
  
  // Initialize stream subscriptions
  void _initializeSubscriptions() {
    _deviceSubscription = _scanningService.deviceDiscovered.listen(
      _onDeviceDiscovered,
      onError: (error) {
        debugPrint('BluetoothScanningViewModel: Device stream error: $error');
      },
    );
    
    _statusSubscription = _scanningService.scanStatusChanged.listen(
      _onScanStatusChanged,
      onError: (error) {
        debugPrint('BluetoothScanningViewModel: Status stream error: $error');
      },
    );
    
    _countSubscription = _scanningService.deviceCountChanged.listen(
      _onDeviceCountChanged,
      onError: (error) {
        debugPrint('BluetoothScanningViewModel: Count stream error: $error');
      },
    );
    
    _errorSubscription = _scanningService.scanError.listen(
      _onScanError,
      onError: (error) {
        debugPrint('BluetoothScanningViewModel: Error stream error: $error');
      },
    );
  }
  
  // Initialize database
  void _initializeDatabase() async {
    try {
      // Database will be automatically initialized when first accessed
      _loadRecentScanHistory();
    } catch (e) {
      debugPrint('BluetoothScanningViewModel: Database initialization error: $e');
    }
  }
  
  // Load recent scan history for charts
  void _loadRecentScanHistory() async {
    try {
      // Load recent history points from database
      // For simplicity, we'll generate some sample data points
      _scanHistory = [];
      
      // Start periodic history updates
      _startHistoryTracking();
    } catch (e) {
      debugPrint('BluetoothScanningViewModel: History loading error: $e');
    }
  }
  
  // Start tracking scan history
  void _startHistoryTracking() {
    _historyTimer?.cancel();
    _historyTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _addHistoryPoint();
    });
  }
  
  // Add a history point
  void _addHistoryPoint() {
    if (_devices.isEmpty) return;
    
    final averageRssi = _devices.map((d) => d.rssi).reduce((a, b) => a + b) / _devices.length;
    
    final historyPoint = ScanHistoryPoint(
      timestamp: DateTime.now(),
      deviceCount: _devices.length,
      averageRssi: averageRssi,
    );
    
    _scanHistory.add(historyPoint);
    
    // Keep only the last 60 points (10 minutes of data)
    if (_scanHistory.length > 60) {
      _scanHistory.removeAt(0);
    }
    
    // Save to database
    _saveHistoryPoint(historyPoint);
    
    notifyListeners();
  }
  
  // Save history point to database
  void _saveHistoryPoint(ScanHistoryPoint point) async {
    try {
      // For now, just store the devices. The DatabaseService 
      // will handle the data points through the scanning service.
      for (final device in _devices) {
        await _databaseService.saveDevice(device);
      }
    } catch (e) {
      debugPrint('BluetoothScanningViewModel: History save error: $e');
    }
  }
  
  // Handle device discovered
  void _onDeviceDiscovered(BluetoothDeviceModel device) {
    final existingIndex = _devices.indexWhere((d) => d.id == device.id);
    
    if (existingIndex >= 0) {
      _devices[existingIndex] = device;
    } else {
      _devices.add(device);
    }
    
    _updateStatistics();
    notifyListeners();
  }
  
  // Handle scan status change
  void _onScanStatusChanged(bool isScanning) {
    if (isScanning) {
      _state = ScanningState.scanning;
    } else {
      _state = ScanningState.idle;
    }
    
    _clearError();
    notifyListeners();
  }
  
  // Handle device count change
  void _onDeviceCountChanged(int count) {
    // This is handled by device discovered events
    _updateStatistics();
  }
  
  // Handle scan error
  void _onScanError(String error) {
    _errorMessage = error;
    _state = ScanningState.error;
    notifyListeners();
  }
  
  // Update scan statistics
  void _updateStatistics() {
    _scanStatistics = _scanningService.getScanStatistics();
  }
  
  // Check if Bluetooth is enabled
  Future<bool> isBluetoothEnabled() async {
    return await _scanningService.isBluetoothEnabled();
  }
  
  // Start scanning
  Future<bool> startScanning({BluetoothScanConfig? config}) async {
    if (_state == ScanningState.scanning) return false;
    
    try {
      _state = ScanningState.initializing;
      _clearError();
      _clearDevices();
      notifyListeners();
      
      if (config != null) {
        _scanConfig = config;
      }
      
      final success = await _scanningService.startScanning(config: _scanConfig);
      
      if (success) {
        _startHistoryTracking();
      } else {
        _state = ScanningState.error;
        _errorMessage = 'Failed to start scanning';
        notifyListeners();
      }
      
      return success;
    } catch (e) {
      _state = ScanningState.error;
      _errorMessage = 'Error starting scan: $e';
      notifyListeners();
      return false;
    }
  }
  
  // Stop scanning
  Future<void> stopScanning() async {
    if (_state != ScanningState.scanning) return;
    
    try {
      _state = ScanningState.stopping;
      notifyListeners();
      
      _historyTimer?.cancel();
      await _scanningService.stopScanning();
      
      _state = ScanningState.idle;
      _updateStatistics();
      notifyListeners();
    } catch (e) {
      _state = ScanningState.error;
      _errorMessage = 'Error stopping scan: $e';
      notifyListeners();
    }
  }
  
  // Toggle scanning
  Future<bool> toggleScanning() async {
    if (isScanning) {
      await stopScanning();
      return false;
    } else {
      return await startScanning();
    }
  }
  
  // Select device
  void selectDevice(BluetoothDeviceModel? device) {
    if (_selectedDevice != device) {
      _selectedDevice = device;
      notifyListeners();
    }
  }
  
  // Clear devices
  void clearDevices() {
    _clearDevices();
    notifyListeners();
  }

  /// Background Scanning: Enter background scanning mode (less frequent, battery optimized)
  void enterBackgroundScanning() {
    if (isScanning) {
      debugPrint('BluetoothScanningViewModel: Entering background scanning mode');
      _scanningService.setBatteryOptimizationConfig(
        const BatteryOptimizationConfig(
          enableDutyCycling: true,
          scanDuration: 3,   // Shorter scan periods in background
          restDuration: 30,  // Longer rest periods in background
          minRssiThreshold: -70, // Only process stronger signals
        ),
      );
    }
  }
  
  /// Background Scanning: Resume foreground scanning mode (more frequent)
  void resumeForegroundScanning() {
    if (isScanning) {
      debugPrint('BluetoothScanningViewModel: Resuming foreground scanning mode');
      _scanningService.setBatteryOptimizationConfig(
        BatteryOptimizationConfig.platformOptimized(),
      );
    }
  }
  
  /// Battery Optimization: Enable low battery mode
  void enableLowBatteryMode() {
    _scanningService.enableLowBatteryMode();
    notifyListeners();
  }
  
  void _clearDevices() {
    _devices.clear();
    _selectedDevice = null;
    _scanningService.clearDevices();
    _updateStatistics();
  }
  
  // Update scan configuration
  void updateScanConfig(BluetoothScanConfig config) {
    if (_scanConfig != config) {
      _scanConfig = config;
      notifyListeners();
    }
  }
  
  // Filtering methods
  void setNameFilter(String filter) {
    if (_nameFilter != filter) {
      _nameFilter = filter;
      notifyListeners();
    }
  }
  
  void setDeviceTypeFilter(String filter) {
    if (_deviceTypeFilter != filter) {
      _deviceTypeFilter = filter;
      notifyListeners();
    }
  }
  
  void setMinRssi(int rssi) {
    if (_minRssi != rssi) {
      _minRssi = rssi;
      notifyListeners();
    }
  }
  
  void setShowRecentOnly(bool showRecent) {
    if (_showRecentOnly != showRecent) {
      _showRecentOnly = showRecent;
      notifyListeners();
    }
  }
  
  void setSortBy(String sortBy, {bool? ascending}) {
    bool changed = false;
    
    if (_sortBy != sortBy) {
      _sortBy = sortBy;
      changed = true;
    }
    
    if (ascending != null && _sortAscending != ascending) {
      _sortAscending = ascending;
      changed = true;
    }
    
    if (changed) {
      notifyListeners();
    }
  }
  
  // Get filtered and sorted devices
  List<BluetoothDeviceModel> _getFilteredAndSortedDevices() {
    var filteredDevices = List<BluetoothDeviceModel>.from(_devices);
    
    // Apply filters
    if (_nameFilter.isNotEmpty) {
      filteredDevices = filteredDevices.where((device) =>
        device.displayName.toLowerCase().contains(_nameFilter.toLowerCase())
      ).toList();
    }
    
    if (_deviceTypeFilter.isNotEmpty) {
      filteredDevices = filteredDevices.where((device) => 
        device.deviceType == _deviceTypeFilter
      ).toList();
    }
    
    filteredDevices = filteredDevices.where((device) => device.rssi >= _minRssi).toList();
    
    if (_showRecentOnly) {
      filteredDevices = filteredDevices.where((device) => device.isRecentlyActive).toList();
    }
    
    // Apply sorting
    filteredDevices.sort((a, b) {
      int comparison = 0;
      
      switch (_sortBy) {
        case 'name':
          comparison = a.displayName.compareTo(b.displayName);
          break;
        case 'rssi':
          comparison = a.rssi.compareTo(b.rssi);
          break;
        case 'lastSeen':
          comparison = a.lastSeen.compareTo(b.lastSeen);
          break;
        case 'scanCount':
          comparison = a.scanCount.compareTo(b.scanCount);
          break;
        default:
          comparison = a.rssi.compareTo(b.rssi);
      }
      
      return _sortAscending ? comparison : -comparison;
    });
    
    return filteredDevices;
  }
  
  // Clear error
  void clearError() {
    _clearError();
    notifyListeners();
  }
  
  void _clearError() {
    _errorMessage = null;
    if (_state == ScanningState.error) {
      _state = ScanningState.idle;
    }
  }
  
  // Check if Bluetooth is ready
  Future<bool> checkBluetoothReady() async {
    try {
      return await _scanningService.isBluetoothReady();
    } catch (e) {
      _onScanError('Error checking Bluetooth state: $e');
      return false;
    }
  }
  
  // Get device by ID
  BluetoothDeviceModel? getDevice(String deviceId) {
    try {
      return _devices.firstWhere((device) => device.id == deviceId);
    } catch (e) {
      return null;
    }
  }
  
  // Get device types for filtering
  List<String> getDeviceTypes() {
    final types = _devices.map((device) => device.deviceType).toSet().toList();
    types.sort();
    return types;
  }
  
  // Get scan session info
  BluetoothScanSession? getCurrentSession() {
    return _scanningService.currentSession;
  }
  
  // Export devices data
  List<Map<String, dynamic>> exportDevicesData() {
    return _devices.map((device) => device.toJson()).toList();
  }
  
  // Get scanning status description
  String getStatusDescription() {
    switch (_state) {
      case ScanningState.idle:
        return hasDevices 
          ? 'Scan completed - ${deviceCount} devices found' 
          : 'Ready to scan';
      case ScanningState.initializing:
        return 'Initializing Bluetooth scanner...';
      case ScanningState.scanning:
        return 'Scanning for devices... (${deviceCount} found)';
      case ScanningState.stopping:
        return 'Stopping scan...';
      case ScanningState.error:
        return 'Error: ${_errorMessage ?? 'Unknown error'}';
    }
  }
  
  @override
  void dispose() {
    debugPrint('BluetoothScanningViewModel: Disposing');
    
    // Cancel subscriptions
    _deviceSubscription?.cancel();
    _statusSubscription?.cancel();
    _countSubscription?.cancel();
    _errorSubscription?.cancel();
    _historyTimer?.cancel();
    
    // Dispose scanning service
    _scanningService.dispose();
    
    super.dispose();
  }
}