import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bluetooth_device_model.dart';
import '../models/battery_optimization_config.dart';
import 'database_service.dart';

// Bluetooth scanning configuration
class BluetoothScanConfig {
  final Duration scanDuration;
  final Duration scanTimeout;
  final List<String> serviceUuids;
  final bool allowDuplicates;
  final int scanMode; // Android only: 0=opportunistic, 1=low_power, 2=balanced, 3=low_latency
  
  const BluetoothScanConfig({
    this.scanDuration = const Duration(seconds: 30),
    this.scanTimeout = const Duration(seconds: 60),
    this.serviceUuids = const [],
    this.allowDuplicates = true,
    this.scanMode = 2, // balanced
  });
  
  Map<String, dynamic> toJson() {
    return {
      'scanDuration': scanDuration.inMilliseconds,
      'scanTimeout': scanTimeout.inMilliseconds,
      'serviceUuids': serviceUuids,
      'allowDuplicates': allowDuplicates,
      'scanMode': scanMode,
    };
  }
}

// Bluetooth scanning service
class BluetoothScanningService {
  static const String _logTag = 'BluetoothScanningService';
  
  // Stream controllers
  final _scanResultController = StreamController<BluetoothDeviceModel>.broadcast();
  final _scanStatusController = StreamController<bool>.broadcast();
  final _deviceCountController = StreamController<int>.broadcast();
  final _scanErrorController = StreamController<String>.broadcast();
  
  // Device tracking
  final Map<String, BluetoothDeviceModel> _discoveredDevices = {};
  BluetoothScanSession? _currentSession;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  Timer? _scanTimer;
  Timer? _dutyCycleTimer;
  bool _isScanning = false;
  bool _isInitialized = false;
  bool _isInScanPhase = true; // For duty cycling
  
  // Database service for persistence
  final DatabaseService _databaseService;
  
  // Battery optimization configuration
  BatteryOptimizationConfig _batteryConfig = BatteryOptimizationConfig.platformOptimized();
  
  // Getters
  Stream<BluetoothDeviceModel> get deviceDiscovered => _scanResultController.stream;
  Stream<bool> get scanStatusChanged => _scanStatusController.stream;
  Stream<int> get deviceCountChanged => _deviceCountController.stream;
  Stream<String> get scanError => _scanErrorController.stream;
  
  bool get isScanning => _isScanning;
  bool get isInitialized => _isInitialized;
  int get discoveredDeviceCount => _discoveredDevices.length;
  List<BluetoothDeviceModel> get discoveredDevices => _discoveredDevices.values.toList();
  BluetoothScanSession? get currentSession => _currentSession;
  
  // Constructor with optional database service
  BluetoothScanningService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;
  
  /// Battery Optimization: Configure battery saving settings
  void setBatteryOptimizationConfig(BatteryOptimizationConfig config) {
    _batteryConfig = config;
    print('$_logTag: Battery optimization configured: $config');
  }
  
  /// Check if Bluetooth adapter is enabled/powered on
  Future<bool> isBluetoothEnabled() async {
    try {
      return await FlutterBluePlus.isOn;
    } catch (e) {
      print('$_logTag: Error checking Bluetooth state: $e');
      return false;
    }
  }
  
  /// Battery Optimization: Enable low battery mode
  void enableLowBatteryMode() {
    setBatteryOptimizationConfig(BatteryOptimizationConfig.lowBattery);
  }
  
  /// Battery Optimization: Check if device should be processed based on RSSI
  bool _shouldProcessDevice(int rssi) {
    return rssi >= _batteryConfig.minRssiThreshold;
  }
  
  /// Battery Optimization: Start duty cycle scanning (scan X seconds, rest Y seconds)
  void _startDutyCycleScanning() {
    if (!_batteryConfig.enableDutyCycling) return;
    
    _dutyCycleTimer = Timer.periodic(
      Duration(seconds: _batteryConfig.scanDuration + _batteryConfig.restDuration),
      (timer) => _performDutyCycle(),
    );
    
    // Start with scan phase
    _isInScanPhase = true;
    _performDutyCycle();
  }
  
  /// Battery Optimization: Perform one duty cycle (scan -> rest -> scan)
  void _performDutyCycle() async {
    if (_isInScanPhase) {
      // Start scanning phase
      print('$_logTag: Duty cycle - Starting ${_batteryConfig.scanDuration}s scan phase');
      await _startActualScan();
      
      // Schedule rest phase
      Timer(Duration(seconds: _batteryConfig.scanDuration), () {
        _isInScanPhase = false;
        _pauseScanning();
      });
    } else {
      // Rest phase
      print('$_logTag: Duty cycle - Resting for ${_batteryConfig.restDuration}s');
      Timer(Duration(seconds: _batteryConfig.restDuration), () {
        if (_isScanning) {
          _isInScanPhase = true;
        }
      });
    }
  }
  
  /// Pause scanning (for duty cycling)
  void _pauseScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
    print('$_logTag: Scanning paused for battery optimization');
  }
  
  /// Start actual Bluetooth scan
  Future<void> _startActualScan() async {
    final scanConfig = const BluetoothScanConfig();
    
    await FlutterBluePlus.startScan(
      withServices: scanConfig.serviceUuids.map((uuid) => Guid(uuid)).toList(),
      timeout: scanConfig.scanTimeout,
    );
    
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      _handleScanResults,
      onError: (error) {
        print('$_logTag: Scan error: $error');
        _scanErrorController.add('Scan error: $error');
      },
    );
  }
  
  // Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      print('$_logTag: Initializing Bluetooth scanning service');
      
      // Check if Bluetooth is supported
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) {
        throw Exception('Bluetooth not supported on this device');
      }
      
      // Check adapter state
      final adapterState = await FlutterBluePlus.adapterState.first;
      print('$_logTag: Bluetooth adapter state: $adapterState');
      
      if (adapterState != BluetoothAdapterState.on) {
        print('$_logTag: Bluetooth is not turned on. State: $adapterState');
        // Don't throw error here, let the UI handle this
      }
      
      _isInitialized = true;
      print('$_logTag: Bluetooth scanning service initialized');
      return true;
    } catch (e) {
      print('$_logTag: Error initializing Bluetooth scanning service: $e');
      _scanErrorController.add('Failed to initialize Bluetooth: $e');
      return false;
    }
  }
  
  // Start scanning for devices
  Future<bool> startScanning({BluetoothScanConfig? config}) async {
    if (_isScanning) {
      print('$_logTag: Scanning already in progress');
      return false;
    }
    
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return false;
    }
    
    try {
      final scanConfig = config ?? const BluetoothScanConfig();
      print('$_logTag: Starting Bluetooth scan with config: ${scanConfig.toJson()}');
      
      // Check adapter state before scanning
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        throw Exception('Bluetooth is not turned on. Current state: $adapterState');
      }
      
      // Clear previous results
      _discoveredDevices.clear();
      _deviceCountController.add(0);
      
      // Create new scan session
      _currentSession = BluetoothScanSession.start(
        scanSettings: scanConfig.toJson(),
      );
      
      // Save scan session to database
      try {
        await _databaseService.saveScanSession(_currentSession!);
      } catch (e) {
        print('$_logTag: Warning - Could not save scan session to database: $e');
      }
      
      // Start scanning with battery optimization
      if (_batteryConfig.enableDutyCycling) {
        print('$_logTag: Starting duty cycle scanning (${_batteryConfig.scanDuration}s scan, ${_batteryConfig.restDuration}s rest)');
        _startDutyCycleScanning();
      } else {
        print('$_logTag: Starting continuous scanning');
        await _startActualScan();
      }
      
      // Note: Removed auto-stop timer for continuous scanning until user stops
      // This improves battery life by allowing user control over scan duration
      
      _isScanning = true;
      _scanStatusController.add(true);
      
      print('$_logTag: Bluetooth scan started successfully (battery optimized: ${_batteryConfig.enableDutyCycling})');
      return true;
    } catch (e) {
      print('$_logTag: Error starting scan: $e');
      _scanErrorController.add('Failed to start scan: $e');
      _isScanning = false;
      _scanStatusController.add(false);
      return false;
    }
  }
  
  // Stop scanning
  Future<void> stopScanning() async {
    if (!_isScanning) return;
    
    try {
      print('$_logTag: Stopping Bluetooth scan');
      
      // Cancel scan timer
      _scanTimer?.cancel();
      _scanTimer = null;
      
      // Cancel scan subscription
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      
      // Stop the scan
      await FlutterBluePlus.stopScan();
      
      // End current session
      if (_currentSession != null) {
        _currentSession = _currentSession!.end(_discoveredDevices.keys.toList());
        
        // Save updated session to database
        try {
          await _databaseService.saveScanSession(_currentSession!);
          
          // Generate data point for visualization
          await _saveDataPoint();
        } catch (e) {
          print('$_logTag: Warning - Could not save scan session to database: $e');
        }
      }
      
      _isScanning = false;
      _scanStatusController.add(false);
      
      print('$_logTag: Bluetooth scan stopped. Discovered ${_discoveredDevices.length} devices');
    } catch (e) {
      print('$_logTag: Error stopping scan: $e');
      _scanErrorController.add('Error stopping scan: $e');
    }
  }
  
  // Handle scan results
  void _handleScanResults(List<ScanResult> results) async {
    for (final result in results) {
      try {
        final deviceId = result.device.remoteId.toString();
        
        // Battery Optimization: Filter out weak signals to reduce processing
        if (!_shouldProcessDevice(result.rssi)) {
          continue; // Skip processing weak signals to save battery
        }
        
        if (_discoveredDevices.containsKey(deviceId)) {
          // Update existing device
          final existingDevice = _discoveredDevices[deviceId]!;
          final updatedDevice = existingDevice.updateFromScanResult(result);
          _discoveredDevices[deviceId] = updatedDevice;
          _scanResultController.add(updatedDevice);
          
          // Save device detection to database
          try {
            await _saveDeviceDetection(updatedDevice);
          } catch (e) {
            print('$_logTag: Warning - Could not save device detection: $e');
          }
        } else {
          // Add new device
          final newDevice = BluetoothDeviceModel.fromScanResult(result);
          _discoveredDevices[deviceId] = newDevice;
          _scanResultController.add(newDevice);
          _deviceCountController.add(_discoveredDevices.length);
          
          print('$_logTag: New device discovered: ${newDevice.displayName} (${newDevice.id}) RSSI: ${newDevice.rssi}');
          
          // Save new device and detection to database
          try {
            await _databaseService.saveDevice(newDevice);
            await _saveDeviceDetection(newDevice);
          } catch (e) {
            print('$_logTag: Warning - Could not save device to database: $e');
          }
        }
      } catch (e) {
        print('$_logTag: Error processing scan result: $e');
      }
    }
  }
  
  // Save device detection to database
  Future<void> _saveDeviceDetection(BluetoothDeviceModel device) async {
    if (_currentSession != null) {
      await _databaseService.saveDeviceDetection(
        sessionId: _currentSession!.id,
        device: device,
      );
    }
  }
  
  // Save aggregated data point for visualization
  Future<void> _saveDataPoint() async {
    if (_discoveredDevices.isEmpty) return;
    
    final devices = _discoveredDevices.values.toList();
    final deviceCount = devices.length;
    final rssiValues = devices.map((d) => d.rssi).toList();
    final averageRssi = rssiValues.isNotEmpty 
        ? rssiValues.reduce((a, b) => a + b) / rssiValues.length 
        : null;
    final minRssi = rssiValues.isNotEmpty ? rssiValues.reduce((a, b) => a < b ? a : b) : null;
    final maxRssi = rssiValues.isNotEmpty ? rssiValues.reduce((a, b) => a > b ? a : b) : null;
    final uniqueDeviceTypes = devices.map((d) => d.deviceType).toSet().length;
    final scanDuration = _currentSession?.sessionDuration.inSeconds;
    
    final dataPoint = DataPoint(
      timestamp: DateTime.now(),
      deviceCount: deviceCount,
      averageRssi: averageRssi,
      minRssi: minRssi,
      maxRssi: maxRssi,
      uniqueDeviceTypes: uniqueDeviceTypes,
      scanDuration: scanDuration,
    );
    
    await _databaseService.saveDataPoint(dataPoint);
  }
  
  // Clear discovered devices
  void clearDevices() {
    print('$_logTag: Clearing discovered devices');
    _discoveredDevices.clear();
    _deviceCountController.add(0);
  }
  
  // Get device by ID
  BluetoothDeviceModel? getDevice(String deviceId) {
    return _discoveredDevices[deviceId];
  }
  
  // Filter devices by criteria
  List<BluetoothDeviceModel> filterDevices({
    int? minRssi,
    bool? recentlyActive,
    String? nameFilter,
    String? deviceType,
  }) {
    var devices = _discoveredDevices.values.toList();
    
    if (minRssi != null) {
      devices = devices.where((device) => device.rssi >= minRssi).toList();
    }
    
    if (recentlyActive == true) {
      devices = devices.where((device) => device.isRecentlyActive).toList();
    }
    
    if (nameFilter != null && nameFilter.isNotEmpty) {
      devices = devices.where((device) => 
        device.displayName.toLowerCase().contains(nameFilter.toLowerCase())
      ).toList();
    }
    
    if (deviceType != null && deviceType.isNotEmpty) {
      devices = devices.where((device) => device.deviceType == deviceType).toList();
    }
    
    return devices;
  }
  
  // Get scanning statistics
  Map<String, dynamic> getScanStatistics() {
    final devices = _discoveredDevices.values.toList();
    
    if (devices.isEmpty) {
      return {
        'totalDevices': 0,
        'averageRssi': 0,
        'deviceTypes': <String, int>{},
        'signalStrengthDistribution': <String, int>{},
      };
    }
    
    final avgRssi = devices.map((d) => d.rssi).reduce((a, b) => a + b) / devices.length;
    
    final deviceTypes = <String, int>{};
    final signalDistribution = <String, int>{};
    
    for (final device in devices) {
      deviceTypes[device.deviceType] = (deviceTypes[device.deviceType] ?? 0) + 1;
      signalDistribution[device.signalStrengthDescription] = 
        (signalDistribution[device.signalStrengthDescription] ?? 0) + 1;
    }
    
    return {
      'totalDevices': devices.length,
      'averageRssi': avgRssi.round(),
      'deviceTypes': deviceTypes,
      'signalStrengthDistribution': signalDistribution,
      'sessionDuration': _currentSession?.sessionDuration.inSeconds ?? 0,
    };
  }
  
  // Check if Bluetooth is available and ready
  Future<bool> isBluetoothReady() async {
    try {
      final isSupported = await FlutterBluePlus.isSupported;
      if (!isSupported) return false;
      
      final adapterState = await FlutterBluePlus.adapterState.first;
      return adapterState == BluetoothAdapterState.on;
    } catch (e) {
      print('$_logTag: Error checking Bluetooth state: $e');
      return false;
    }
  }
  
  // Dispose resources
  void dispose() {
    print('$_logTag: Disposing Bluetooth scanning service');
    
    if (_isScanning) {
      stopScanning();
    }
    
    _scanTimer?.cancel();
    _dutyCycleTimer?.cancel();
    _scanSubscription?.cancel();
    
    _scanResultController.close();
    _scanStatusController.close();
    _deviceCountController.close();
    _scanErrorController.close();
    
    _discoveredDevices.clear();
    _isInitialized = false;
  }
}