import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bluetooth_device_model.dart';

// Database service for persisting scan data and historical analysis
class DatabaseService {
  static const String _databaseName = 'bluetooth_passive_sensing.db';
  static const int _databaseVersion = 1;
  
  // Table names
  static const String _tableDevices = 'devices';
  static const String _tableScanSessions = 'scan_sessions';
  static const String _tableDeviceDetections = 'device_detections';
  static const String _tableDataPoints = 'data_points';
  
  static DatabaseService? _instance;
  static Database? _database;
  
  DatabaseService._internal();
  
  static DatabaseService get instance {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }
  
  // Get database instance
  Future<Database> get database async {
    _database ??= await _initializeDatabase();
    return _database!;
  }
  
  // Initialize the database
  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    
    print('DatabaseService: Initializing database at $path');
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }
  
  // Create database tables
  Future<void> _createTables(Database db, int version) async {
    print('DatabaseService: Creating database tables');
    
    // Devices table - stores unique Bluetooth devices
    await db.execute('''
      CREATE TABLE $_tableDevices (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        local_name TEXT,
        device_type TEXT,
        manufacturer_data TEXT,
        service_uuids TEXT,
        first_seen INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        total_detections INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    
    // Scan sessions table - stores scanning session metadata
    await db.execute('''
      CREATE TABLE $_tableScanSessions (
        id TEXT PRIMARY KEY,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration INTEGER,
        devices_discovered INTEGER DEFAULT 0,
        scan_settings TEXT,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Device detections table - stores individual device detections during scans
    await db.execute('''
      CREATE TABLE $_tableDeviceDetections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        rssi INTEGER NOT NULL,
        connectable INTEGER NOT NULL,
        tx_power_level INTEGER,
        detected_at INTEGER NOT NULL,
        FOREIGN KEY (session_id) REFERENCES $_tableScanSessions (id),
        FOREIGN KEY (device_id) REFERENCES $_tableDevices (id)
      )
    ''');
    
    // Data points table - stores aggregated time-series data for visualization
    await db.execute('''
      CREATE TABLE $_tableDataPoints (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        device_count INTEGER NOT NULL,
        average_rssi REAL,
        min_rssi INTEGER,
        max_rssi INTEGER,
        unique_device_types INTEGER,
        scan_duration INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_devices_last_seen ON $_tableDevices (last_seen)');
    await db.execute('CREATE INDEX idx_sessions_start_time ON $_tableScanSessions (start_time)');
    await db.execute('CREATE INDEX idx_detections_session_device ON $_tableDeviceDetections (session_id, device_id)');
    await db.execute('CREATE INDEX idx_detections_detected_at ON $_tableDeviceDetections (detected_at)');
    await db.execute('CREATE INDEX idx_datapoints_timestamp ON $_tableDataPoints (timestamp)');
    
    print('DatabaseService: Database tables created successfully');
  }
  
  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('DatabaseService: Upgrading database from version $oldVersion to $newVersion');
    // Handle future database schema changes
  }
  
  // Save a scan session
  Future<void> saveScanSession(BluetoothScanSession session) async {
    final db = await database;
    
    try {
      await db.insert(
        _tableScanSessions,
        {
          'id': session.id,
          'start_time': session.startTime.millisecondsSinceEpoch,
          'end_time': session.endTime?.millisecondsSinceEpoch,
          'duration': session.duration?.inMilliseconds,
          'devices_discovered': session.devicesDiscovered,
          'scan_settings': session.scanSettings.toString(),
          'status': session.isActive ? 'active' : 'completed',
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('DatabaseService: Saved scan session ${session.id}');
    } catch (e) {
      print('DatabaseService: Error saving scan session: $e');
      rethrow;
    }
  }
  
  // Save or update a Bluetooth device
  Future<void> saveDevice(BluetoothDeviceModel device) async {
    final db = await database;
    
    try {
      await db.insert(
        _tableDevices,
        {
          'id': device.id,
          'name': device.name,
          'local_name': device.localName,
          'device_type': device.deviceType,
          'manufacturer_data': device.manufacturerData.toString(),
          'service_uuids': device.serviceUuids.join(','),
          'first_seen': device.firstSeen.millisecondsSinceEpoch,
          'last_seen': device.lastSeen.millisecondsSinceEpoch,
          'total_detections': device.scanCount,
          'created_at': device.firstSeen.millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      print('DatabaseService: Saved device ${device.displayName} (${device.id})');
    } catch (e) {
      print('DatabaseService: Error saving device: $e');
      rethrow;
    }
  }
  
  // Save a device detection during a scan
  Future<void> saveDeviceDetection({
    required String sessionId,
    required BluetoothDeviceModel device,
  }) async {
    final db = await database;
    
    try {
      await db.insert(_tableDeviceDetections, {
        'session_id': sessionId,
        'device_id': device.id,
        'rssi': device.rssi,
        'connectable': device.connectable ? 1 : 0,
        'tx_power_level': device.txPowerLevel != null ? int.tryParse(device.txPowerLevel!) : null,
        'detected_at': device.lastSeen.millisecondsSinceEpoch,
      });
    } catch (e) {
      print('DatabaseService: Error saving device detection: $e');
      rethrow;
    }
  }
  
  // Save aggregated data point for visualization
  Future<void> saveDataPoint(DataPoint dataPoint) async {
    final db = await database;
    
    try {
      await db.insert(_tableDataPoints, {
        'timestamp': dataPoint.timestamp.millisecondsSinceEpoch,
        'device_count': dataPoint.deviceCount,
        'average_rssi': dataPoint.averageRssi,
        'min_rssi': dataPoint.minRssi,
        'max_rssi': dataPoint.maxRssi,
        'unique_device_types': dataPoint.uniqueDeviceTypes,
        'scan_duration': dataPoint.scanDuration,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('DatabaseService: Error saving data point: $e');
      rethrow;
    }
  }
  
  // Get recent scan sessions
  Future<List<BluetoothScanSession>> getRecentScanSessions({int limit = 50}) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableScanSessions,
        orderBy: 'start_time DESC',
        limit: limit,
      );
      
      return maps.map((map) => _scanSessionFromMap(map)).toList();
    } catch (e) {
      print('DatabaseService: Error getting scan sessions: $e');
      return [];
    }
  }
  
  // Get data points for visualization within date range
  Future<List<DataPoint>> getDataPoints({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await database;
    
    try {
      String whereClause = '';
      List<Object?> whereArgs = [];
      
      if (startDate != null || endDate != null) {
        final conditions = <String>[];
        
        if (startDate != null) {
          conditions.add('timestamp >= ?');
          whereArgs.add(startDate.millisecondsSinceEpoch);
        }
        
        if (endDate != null) {
          conditions.add('timestamp <= ?');
          whereArgs.add(endDate.millisecondsSinceEpoch);
        }
        
        whereClause = conditions.join(' AND ');
      }
      
      final List<Map<String, dynamic>> maps = await db.query(
        _tableDataPoints,
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'timestamp ASC',
        limit: limit,
      );
      
      return maps.map((map) => _dataPointFromMap(map)).toList();
    } catch (e) {
      print('DatabaseService: Error getting data points: $e');
      return [];
    }
  }
  
  // Get device discovery trends
  Future<List<Map<String, dynamic>>> getDeviceDiscoveryTrends({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          DATE(detected_at / 1000, 'unixepoch') as date,
          COUNT(DISTINCT device_id) as unique_devices,
          COUNT(*) as total_detections,
          AVG(rssi) as average_rssi,
          MIN(rssi) as min_rssi,
          MAX(rssi) as max_rssi
        FROM $_tableDeviceDetections
        WHERE detected_at BETWEEN ? AND ?
        GROUP BY DATE(detected_at / 1000, 'unixepoch')
        ORDER BY date ASC
      ''', [
        startDate.millisecondsSinceEpoch,
        endDate.millisecondsSinceEpoch,
      ]);
      
      return maps;
    } catch (e) {
      print('DatabaseService: Error getting discovery trends: $e');
      return [];
    }
  }
  
  // Get top devices by detection frequency
  Future<List<Map<String, dynamic>>> getTopDevices({int limit = 10}) async {
    final db = await database;
    
    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          d.id,
          d.name,
          d.local_name,
          d.device_type,
          d.total_detections,
          COUNT(dd.device_id) as recent_detections,
          AVG(dd.rssi) as average_rssi,
          MAX(dd.detected_at) as last_detected
        FROM $_tableDevices d
        LEFT JOIN $_tableDeviceDetections dd ON d.id = dd.device_id
        GROUP BY d.id, d.name, d.local_name, d.device_type, d.total_detections
        ORDER BY recent_detections DESC, d.total_detections DESC
        LIMIT ?
      ''', [limit]);
      
      return maps;
    } catch (e) {
      print('DatabaseService: Error getting top devices: $e');
      return [];
    }
  }
  
  // Get scan statistics
  Future<Map<String, dynamic>> getScanStatistics() async {
    final db = await database;
    
    try {
      final totalSessions = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableScanSessions')
      ) ?? 0;
      
      final totalDevices = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableDevices')
      ) ?? 0;
      
      final totalDetections = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $_tableDeviceDetections')
      ) ?? 0;
      
      final avgRssi = await db.rawQuery('''
        SELECT AVG(rssi) as avg_rssi FROM $_tableDeviceDetections
      ''');
      
      final deviceTypes = await db.rawQuery('''
        SELECT device_type, COUNT(*) as count
        FROM $_tableDevices
        GROUP BY device_type
        ORDER BY count DESC
      ''');
      
      return {
        'totalSessions': totalSessions,
        'totalDevices': totalDevices,
        'totalDetections': totalDetections,
        'averageRssi': (avgRssi.first['avg_rssi'] as num?)?.toDouble() ?? 0.0,
        'deviceTypes': deviceTypes,
      };
    } catch (e) {
      print('DatabaseService: Error getting scan statistics: $e');
      return {};
    }
  }
  
  // Export scan data as JSON
  Future<Map<String, dynamic>> exportScanData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final sessions = await getRecentScanSessions();
      final dataPoints = await getDataPoints(startDate: startDate, endDate: endDate);
      final statistics = await getScanStatistics();
      final topDevices = await getTopDevices();
      
      return {
        'export_timestamp': DateTime.now().toIso8601String(),
        'date_range': {
          'start': startDate?.toIso8601String(),
          'end': endDate?.toIso8601String(),
        },
        'statistics': statistics,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'data_points': dataPoints.map((dp) => dp.toJson()).toList(),
        'top_devices': topDevices,
      };
    } catch (e) {
      print('DatabaseService: Error exporting scan data: $e');
      rethrow;
    }
  }
  
  // Clear old data (for cleanup)
  Future<void> clearOldData({required Duration olderThan}) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(olderThan).millisecondsSinceEpoch;
    
    try {
      await db.transaction((txn) async {
        // Delete old device detections
        await txn.delete(
          _tableDeviceDetections,
          where: 'detected_at < ?',
          whereArgs: [cutoffTime],
        );
        
        // Delete old data points
        await txn.delete(
          _tableDataPoints,
          where: 'timestamp < ?',
          whereArgs: [cutoffTime],
        );
        
        // Delete old scan sessions
        await txn.delete(
          _tableScanSessions,
          where: 'start_time < ?',
          whereArgs: [cutoffTime],
        );
        
        print('DatabaseService: Cleared data older than ${olderThan.inDays} days');
      });
    } catch (e) {
      print('DatabaseService: Error clearing old data: $e');
      rethrow;
    }
  }
  
  // Helper method to convert map to BluetoothScanSession
  BluetoothScanSession _scanSessionFromMap(Map<String, dynamic> map) {
    return BluetoothScanSession(
      id: map['id'] as String,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time'] as int),
      endTime: map['end_time'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(map['end_time'] as int)
        : null,
      duration: map['duration'] != null 
        ? Duration(milliseconds: map['duration'] as int)
        : null,
      devicesDiscovered: map['devices_discovered'] as int,
      deviceIds: [], // Would need to query separately if needed
      scanSettings: {}, // Would need to parse JSON string if needed
    );
  }
  
  // Helper method to convert map to DataPoint
  DataPoint _dataPointFromMap(Map<String, dynamic> map) {
    return DataPoint(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      deviceCount: map['device_count'] as int,
      averageRssi: (map['average_rssi'] as num?)?.toDouble(),
      minRssi: map['min_rssi'] as int?,
      maxRssi: map['max_rssi'] as int?,
      uniqueDeviceTypes: map['unique_device_types'] as int,
      scanDuration: map['scan_duration'] as int?,
    );
  }
  
  // Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      print('DatabaseService: Database connection closed');
    }
  }
}

// Data point model for time-series visualization
class DataPoint {
  final DateTime timestamp;
  final int deviceCount;
  final double? averageRssi;
  final int? minRssi;
  final int? maxRssi;
  final int uniqueDeviceTypes;
  final int? scanDuration;
  
  const DataPoint({
    required this.timestamp,
    required this.deviceCount,
    this.averageRssi,
    this.minRssi,
    this.maxRssi,
    required this.uniqueDeviceTypes,
    this.scanDuration,
  });
  
  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'deviceCount': deviceCount,
      'averageRssi': averageRssi,
      'minRssi': minRssi,
      'maxRssi': maxRssi,
      'uniqueDeviceTypes': uniqueDeviceTypes,
      'scanDuration': scanDuration,
    };
  }
  
  // Create from JSON
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      timestamp: DateTime.parse(json['timestamp'] as String),
      deviceCount: json['deviceCount'] as int,
      averageRssi: (json['averageRssi'] as num?)?.toDouble(),
      minRssi: json['minRssi'] as int?,
      maxRssi: json['maxRssi'] as int?,
      uniqueDeviceTypes: json['uniqueDeviceTypes'] as int,
      scanDuration: json['scanDuration'] as int?,
    );
  }
}