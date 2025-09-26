class ScanHistoryPoint {
  final DateTime timestamp;
  final int deviceCount;
  final double averageRssi;
  
  const ScanHistoryPoint({
    required this.timestamp,
    required this.deviceCount,
    required this.averageRssi,
  });
  
  @override
  String toString() {
    return 'ScanHistoryPoint(timestamp: $timestamp, deviceCount: $deviceCount, averageRssi: $averageRssi)';
  }
}