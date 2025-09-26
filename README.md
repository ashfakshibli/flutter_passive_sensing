# Flutter Bluetooth Passive Sensing

A cross-platform Flutter application for passive Bluetooth device sensing and data visualization, created for Dartmouth Full Stack Developer interview.

## Project Overview

This application demonstrates professional Flutter development practices by implementing a Bluetooth passive sensing system that:

- Scans for nearby Bluetooth devices and collects RSSI data
- Stores time-series data locally with SQLite
- Visualizes device count and signal strength trends
- Follows MVVM architecture pattern for maintainable code
- Implements proper permission handling for iOS and Android

## Architecture

### MVVM Pattern
```
lib/
├── models/           # Data models and entities
├── views/            # UI screens and pages  
├── viewmodels/       # Business logic and state management
├── services/         # Platform services (Bluetooth, Database, Permissions)
├── widgets/          # Reusable UI components
└── utils/            # Helper classes and constants
```

### Key Dependencies
- **flutter_blue_plus**: Bluetooth Low Energy scanning
- **provider**: State management for MVVM pattern
- **sqflite**: Local SQLite database for data persistence
- **fl_chart**: Time-series data visualization
- **permission_handler**: Runtime permission management

## Getting Started

### Prerequisites
- Flutter SDK 3.35.4+ 
- Dart 3.9.2+
- iOS 13.0+ / Android API 21+
- Xcode (for iOS development)

### Installation

1. **Clone the repository**
   ```bash
   git clone git@github.com:ashfakshibli/flutter_passive_sensing.git
   cd flutter_passive_sensing
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **iOS Setup** (macOS only)
   ```bash
   cd ios && pod install
   ```

4. **Run the application**
   ```bash
   flutter run
   ```

## Platform Configuration

### iOS Configuration
- **Minimum Version**: iOS 13.0
- **Permissions**: Bluetooth and Location permissions configured in `Info.plist`
- **CocoaPods**: Managed dependencies for native iOS libraries

### Android Configuration  
- **Minimum SDK**: API 21 (Android 5.0)
- **Permissions**: Bluetooth and Location permissions in `AndroidManifest.xml`
- **Target SDK**: API 34 (Android 14)

## Battery Optimization Strategies

1. **Scan Intervals**: Configurable scanning periods to balance data collection and battery life
2. **Background Limitations**: Proper handling of iOS/Android background execution limits
3. **Efficient Data Storage**: Optimized database queries and batch operations
4. **Smart Scanning**: Conditional scanning based on device movement and time

## Testing Strategy

- **Unit Tests**: ViewModels and Services business logic
- **Widget Tests**: UI component testing
- **Integration Tests**: End-to-end Bluetooth scanning workflows
- **Platform Testing**: iOS and Android specific functionality

## Development Approach

### Phase 1: Foundation 
- [x] Project setup with MVVM architecture
- [x] Dependency configuration
- [x] Platform permissions setup
- [x] GitHub repository and workflow

### Phase 2: Core Features (In Progress)
- [ ] Permission handling service
- [ ] Bluetooth scanning implementation  
- [ ] Local data storage with SQLite
- [ ] Device list UI with RSSI display

### Phase 3: Data Visualization
- [ ] Time-series charts implementation
- [ ] Historical data analysis
- [ ] Export functionality

### Phase 4: Optimization & Polish
- [ ] Battery optimization features
- [ ] Advanced filtering options
- [ ] Error handling and edge cases
- [ ] Performance optimization


---

**Developer**: Ashfak Md Shibli  
**Contact**: shibli.emon@gmail.com  
**GitHub**: [@ashfakshibli](https://github.com/ashfakshibli)