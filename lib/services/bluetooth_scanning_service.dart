import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bluetooth_device_model.dart';

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
  bool _isScanning = false;
  bool _isInitialized = false;
  
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
      
      // Start scanning
      await FlutterBluePlus.startScan(
        withServices: scanConfig.serviceUuids.map((uuid) => Guid(uuid)).toList(),
        timeout: scanConfig.scanTimeout,
      );
      
      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen(
        _handleScanResults,
        onError: (error) {
          print('$_logTag: Scan error: $error');
          _scanErrorController.add('Scan error: $error');
        },
      );
      
      // Set up auto-stop timer
      _scanTimer = Timer(scanConfig.scanDuration, () {
        print('$_logTag: Scan duration reached, stopping scan');
        stopScanning();
      });
      
      _isScanning = true;
      _scanStatusController.add(true);
      
      print('$_logTag: Bluetooth scan started successfully');
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
  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      try {
        final deviceId = result.device.remoteId.toString();
        
        if (_discoveredDevices.containsKey(deviceId)) {
          // Update existing device
          final existingDevice = _discoveredDevices[deviceId]!;
          final updatedDevice = existingDevice.updateFromScanResult(result);
          _discoveredDevices[deviceId] = updatedDevice;
          _scanResultController.add(updatedDevice);
        } else {
          // Add new device
          final newDevice = BluetoothDeviceModel.fromScanResult(result);
          _discoveredDevices[deviceId] = newDevice;
          _scanResultController.add(newDevice);
          _deviceCountController.add(_discoveredDevices.length);
          
          print('$_logTag: New device discovered: ${newDevice.displayName} (${newDevice.id}) RSSI: ${newDevice.rssi}');
        }
      } catch (e) {
        print('$_logTag: Error processing scan result: $e');
      }
    }
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
    _scanSubscription?.cancel();
    
    _scanResultController.close();
    _scanStatusController.close();
    _deviceCountController.close();
    _scanErrorController.close();
    
    _discoveredDevices.clear();
    _isInitialized = false;
  }
}