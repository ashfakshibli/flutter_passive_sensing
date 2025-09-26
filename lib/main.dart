import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'viewmodels/permission_viewmodel.dart';
import 'viewmodels/bluetooth_scanning_viewmodel.dart';
import 'widgets/permission_widget.dart';
import 'widgets/bluetooth_scanning_screen.dart';

void main() {
  runApp(const BluetoothPassiveSensingApp());
}

class BluetoothPassiveSensingApp extends StatelessWidget {
  const BluetoothPassiveSensingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PermissionViewModel()),
        ChangeNotifierProvider(create: (_) => BluetoothScanningViewModel()),
      ],
      child: MaterialApp(
        title: 'Bluetooth Passive Sensing',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const HomeView(),
      ),
    );
  }
}

// Main home view with permission handling
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return PermissionWidget(
      child: const MainAppView(),
    );
  }
}

// Main application view (shown after permissions are granted)
class MainAppView extends StatefulWidget {
  const MainAppView({super.key});

  @override
  State<MainAppView> createState() => _MainAppViewState();
}

class _MainAppViewState extends State<MainAppView> {
  @override
  void initState() {
    super.initState();
    
    // Check permissions when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = Provider.of<PermissionViewModel>(context, listen: false);
      viewModel.checkBluetoothPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.hasBluetoothPermissions) {
          // Show the scanning interface directly
          return const BluetoothScanningScreen();
        }
        
        // Show permission request screen
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            title: const Text('Bluetooth Passive Sensing'),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_disabled,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                Text(
                  'Permissions Required',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This app needs Bluetooth and Location permissions to scan for nearby devices',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await viewModel.requestBluetoothPermissions();
                    if (!success) {
                      // If permissions were denied, show option to go to settings
                      _showPermissionDeniedDialog(context, viewModel);
                    }
                  },
                  icon: const Icon(Icons.security),
                  label: const Text('Grant Permissions'),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _showPermissionDeniedDialog(context, viewModel),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPermissionDeniedDialog(BuildContext context, PermissionViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'To scan for Bluetooth devices, this app needs:\n\n'
          '• Bluetooth permission\n'
          '• Location permission (required by Android for Bluetooth scanning)\n\n'
          'Please enable these permissions in Settings and return to the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await viewModel.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
