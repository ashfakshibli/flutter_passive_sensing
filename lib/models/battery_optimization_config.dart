import 'dart:io';

/// Battery optimization configuration for Bluetooth scanning
class BatteryOptimizationConfig {
  /// Enable duty cycling (scan for X seconds, rest for Y seconds)
  final bool enableDutyCycling;
  
  /// Duration to scan during each cycle (in seconds)
  final int scanDuration;
  
  /// Duration to rest between scan cycles (in seconds)
  final int restDuration;
  
  /// Reduce scan frequency based on platform
  final bool adaptiveScanMode;
  
  /// Minimum RSSI threshold to reduce processing of weak signals
  final int minRssiThreshold;
  
  /// Background scan interval (longer intervals save battery)
  final Duration backgroundScanInterval;
  
  /// Foreground scan interval (can be more frequent)
  final Duration foregroundScanInterval;

  const BatteryOptimizationConfig({
    this.enableDutyCycling = true,
    this.scanDuration = 10, // Scan for 10 seconds
    this.restDuration = 5,  // Rest for 5 seconds
    this.adaptiveScanMode = true,
    this.minRssiThreshold = -90, // Ignore very weak signals
    this.backgroundScanInterval = const Duration(minutes: 2),
    this.foregroundScanInterval = const Duration(seconds: 30),
  });

  /// Platform-optimized configuration
  static BatteryOptimizationConfig platformOptimized() {
    if (Platform.isIOS) {
      return const BatteryOptimizationConfig(
        enableDutyCycling: true,
        scanDuration: 8,  // iOS is more battery efficient
        restDuration: 7,
        minRssiThreshold: -85, // iOS has better signal processing
      );
    } else if (Platform.isAndroid) {
      return const BatteryOptimizationConfig(
        enableDutyCycling: true,
        scanDuration: 5,  // Android needs more aggressive optimization
        restDuration: 10,
        minRssiThreshold: -80, // Filter more aggressively on Android
      );
    }
    
    return const BatteryOptimizationConfig();
  }

  /// Low battery configuration (more aggressive optimization)
  static const BatteryOptimizationConfig lowBattery = BatteryOptimizationConfig(
    enableDutyCycling: true,
    scanDuration: 3,
    restDuration: 15,
    minRssiThreshold: -75, // Only strong signals
    backgroundScanInterval: Duration(minutes: 5),
    foregroundScanInterval: Duration(minutes: 1),
  );

  Map<String, dynamic> toJson() {
    return {
      'enableDutyCycling': enableDutyCycling,
      'scanDuration': scanDuration,
      'restDuration': restDuration,
      'adaptiveScanMode': adaptiveScanMode,
      'minRssiThreshold': minRssiThreshold,
      'backgroundScanInterval': backgroundScanInterval.inMilliseconds,
      'foregroundScanInterval': foregroundScanInterval.inMilliseconds,
    };
  }

  @override
  String toString() {
    return 'BatteryOptimizationConfig(dutyCycle: $enableDutyCycling, '
           'scan: ${scanDuration}s, rest: ${restDuration}s, '
           'minRssi: ${minRssiThreshold}dBm)';
  }
}