import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// Bluetooth device discovery result model
class BluetoothDeviceModel {
  final String id;
  final String name;
  final String? localName;
  final int rssi;
  final List<String> serviceUuids;
  final Map<String, dynamic> manufacturerData;
  final Map<String, dynamic> serviceData;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final int scanCount;
  final bool connectable;
  final String? txPowerLevel;
  
  const BluetoothDeviceModel({
    required this.id,
    required this.name,
    this.localName,
    required this.rssi,
    required this.serviceUuids,
    required this.manufacturerData,
    required this.serviceData,
    required this.firstSeen,
    required this.lastSeen,
    required this.scanCount,
    required this.connectable,
    this.txPowerLevel,
  });

  // Create from flutter_blue_plus ScanResult
  factory BluetoothDeviceModel.fromScanResult(ScanResult scanResult) {
    final device = scanResult.device;
    final advertisementData = scanResult.advertisementData;
    final now = DateTime.now();
    
    return BluetoothDeviceModel(
      id: device.remoteId.toString(),
      name: device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
      localName: advertisementData.localName.isNotEmpty ? advertisementData.localName : null,
      rssi: scanResult.rssi,
      serviceUuids: advertisementData.serviceUuids.map((uuid) => uuid.toString()).toList(),
      manufacturerData: advertisementData.manufacturerData.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      serviceData: advertisementData.serviceData.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      firstSeen: now,
      lastSeen: now,
      scanCount: 1,
      connectable: advertisementData.connectable,
      txPowerLevel: advertisementData.txPowerLevel?.toString(),
    );
  }

  // Update device with new scan result
  BluetoothDeviceModel updateFromScanResult(ScanResult scanResult) {
    return BluetoothDeviceModel(
      id: id,
      name: name,
      localName: localName,
      rssi: scanResult.rssi, // Update with latest RSSI
      serviceUuids: serviceUuids,
      manufacturerData: manufacturerData,
      serviceData: serviceData,
      firstSeen: firstSeen,
      lastSeen: DateTime.now(), // Update last seen
      scanCount: scanCount + 1, // Increment scan count
      connectable: connectable,
      txPowerLevel: txPowerLevel,
    );
  }

  // Get display name (prefers local name over platform name)
  String get displayName {
    if (localName != null && localName!.isNotEmpty) {
      return localName!;
    }
    return name;
  }

  // Get signal strength description
  String get signalStrengthDescription {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -70) return 'Good';
    if (rssi >= -80) return 'Fair';
    return 'Poor';
  }

  // Get device type from manufacturer data or service UUIDs
  String get deviceType {
    // Try to determine device type from manufacturer data
    if (manufacturerData.containsKey('76')) { // Apple
      return 'Apple Device';
    }
    
    // Check for common service UUIDs
    for (final serviceUuid in serviceUuids) {
      final uuid = serviceUuid.toLowerCase();
      if (uuid.contains('180f')) return 'Battery Service';
      if (uuid.contains('1800')) return 'Generic Access';
      if (uuid.contains('1801')) return 'Generic Attribute';
      if (uuid.contains('180a')) return 'Device Information';
      if (uuid.contains('1812')) return 'HID Device';
      if (uuid.contains('180d')) return 'Heart Rate Monitor';
    }
    
    return 'BLE Device';
  }

  // Check if device is recently seen (within last 30 seconds)
  bool get isRecentlyActive {
    final timeDiff = DateTime.now().difference(lastSeen);
    return timeDiff.inSeconds <= 30;
  }

  // Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'localName': localName,
      'rssi': rssi,
      'serviceUuids': serviceUuids,
      'manufacturerData': manufacturerData,
      'serviceData': serviceData,
      'firstSeen': firstSeen.toIso8601String(),
      'lastSeen': lastSeen.toIso8601String(),
      'scanCount': scanCount,
      'connectable': connectable,
      'txPowerLevel': txPowerLevel,
    };
  }

  // Create from JSON
  factory BluetoothDeviceModel.fromJson(Map<String, dynamic> json) {
    return BluetoothDeviceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      localName: json['localName'] as String?,
      rssi: json['rssi'] as int,
      serviceUuids: List<String>.from(json['serviceUuids'] ?? []),
      manufacturerData: Map<String, dynamic>.from(json['manufacturerData'] ?? {}),
      serviceData: Map<String, dynamic>.from(json['serviceData'] ?? {}),
      firstSeen: DateTime.parse(json['firstSeen'] as String),
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      scanCount: json['scanCount'] as int,
      connectable: json['connectable'] as bool,
      txPowerLevel: json['txPowerLevel'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothDeviceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'BluetoothDeviceModel{id: $id, name: $name, rssi: $rssi, scanCount: $scanCount}';
  }
}

// Bluetooth scan session model
class BluetoothScanSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final int devicesDiscovered;
  final List<String> deviceIds;
  final Map<String, dynamic> scanSettings;

  const BluetoothScanSession({
    required this.id,
    required this.startTime,
    this.endTime,
    this.duration,
    required this.devicesDiscovered,
    required this.deviceIds,
    required this.scanSettings,
  });

  // Create new scan session
  factory BluetoothScanSession.start({
    Map<String, dynamic>? scanSettings,
  }) {
    return BluetoothScanSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      devicesDiscovered: 0,
      deviceIds: [],
      scanSettings: scanSettings ?? {},
    );
  }

  // End scan session
  BluetoothScanSession end(List<String> discoveredDeviceIds) {
    final endTime = DateTime.now();
    return BluetoothScanSession(
      id: id,
      startTime: startTime,
      endTime: endTime,
      duration: endTime.difference(startTime),
      devicesDiscovered: discoveredDeviceIds.length,
      deviceIds: discoveredDeviceIds,
      scanSettings: scanSettings,
    );
  }

  // Check if session is active
  bool get isActive => endTime == null;

  // Get session duration (current or final)
  Duration get sessionDuration {
    if (duration != null) return duration!;
    return DateTime.now().difference(startTime);
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'duration': duration?.inMilliseconds,
      'devicesDiscovered': devicesDiscovered,
      'deviceIds': deviceIds,
      'scanSettings': scanSettings,
    };
  }

  // Create from JSON
  factory BluetoothScanSession.fromJson(Map<String, dynamic> json) {
    return BluetoothScanSession(
      id: json['id'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime'] as String) : null,
      duration: json['duration'] != null ? Duration(milliseconds: json['duration'] as int) : null,
      devicesDiscovered: json['devicesDiscovered'] as int,
      deviceIds: List<String>.from(json['deviceIds'] ?? []),
      scanSettings: Map<String, dynamic>.from(json['scanSettings'] ?? {}),
    );
  }
}