# Project Architecture

## Overview
This Flutter application follows the MVVM (Model-View-ViewModel) architectural pattern for clean code organization and separation of concerns.

## Folder Structure

```
lib/
├── models/           # Data models and entities
│   ├── bluetooth_device.dart
│   └── scan_session.dart
├── views/            # UI screens and pages
│   ├── home_view.dart
│   └── chart_view.dart
├── viewmodels/       # Business logic and state management
│   ├── bluetooth_viewmodel.dart
│   └── chart_viewmodel.dart
├── services/         # Platform services and external APIs
│   ├── bluetooth_service.dart
│   ├── database_service.dart
│   └── permission_service.dart
├── widgets/          # Reusable UI components
│   ├── device_list_tile.dart
│   └── signal_strength_indicator.dart
└── utils/            # Helper classes and constants
    ├── constants.dart
    └── extensions.dart
```

## MVVM Pattern Benefits

1. **Separation of Concerns**: Each layer has a specific responsibility
2. **Testability**: Business logic in ViewModels can be easily unit tested
3. **Maintainability**: Changes in one layer don't affect others
4. **Scalability**: Easy to add new features following the same pattern

## Dependencies

- **flutter_blue_plus**: Bluetooth Low Energy scanning
- **provider**: State management for MVVM pattern
- **sqflite**: Local SQLite database for data persistence
- **fl_chart**: Time-series data visualization
- **permission_handler**: Runtime permission management
- **intl**: Date/time formatting and internationalization

## Development Workflow

1. **Models First**: Define data structures
2. **Services**: Implement platform-specific functionality
3. **ViewModels**: Create business logic using Provider
4. **Views**: Build UI consuming ViewModels
5. **Testing**: Unit test ViewModels and Services