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
class MainAppView extends StatelessWidget {
  const MainAppView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Bluetooth Passive Sensing'),
        actions: [
          Consumer<PermissionViewModel>(
            builder: (context, viewModel, child) {
              return IconButton(
                icon: Icon(
                  viewModel.hasBluetoothPermissions 
                    ? Icons.bluetooth_connected 
                    : Icons.bluetooth_disabled,
                  color: viewModel.hasBluetoothPermissions 
                    ? Colors.green 
                    : Colors.red,
                ),
                onPressed: () {
                  viewModel.checkBluetoothPermissions();
                  _showPermissionStatus(context, viewModel);
                },
                tooltip: 'Check Permissions',
              );
            },
          ),
        ],
      ),
      body: Consumer<PermissionViewModel>(
        builder: (context, viewModel, child) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.bluetooth_searching,
                  size: 64,
                  color: viewModel.hasBluetoothPermissions 
                    ? Colors.green 
                    : Colors.blue,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bluetooth Passive Sensing',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  viewModel.hasBluetoothPermissions
                    ? 'Ready for Bluetooth scanning'
                    : 'Permissions required for Bluetooth scanning',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: viewModel.hasBluetoothPermissions 
                      ? Colors.green 
                      : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                if (viewModel.hasBluetoothPermissions) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BluetoothScanningScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Scanning'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showPermissionStatus(context, viewModel),
                    icon: const Icon(Icons.info),
                    label: const Text('View Permissions'),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      await viewModel.requestBluetoothPermissions();
                    },
                    icon: const Icon(Icons.security),
                    label: const Text('Grant Permissions'),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPermissionStatus(BuildContext context, PermissionViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(viewModel.getPermissionStatusDescription()),
            const SizedBox(height: 16),
            
            if (viewModel.bluetoothPermissions != null) ...[
              const Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              _buildStatusItem(
                'Bluetooth', 
                viewModel.bluetoothPermissions!.bluetooth.isGranted,
              ),
              
              _buildStatusItem(
                'Location', 
                viewModel.bluetoothPermissions!.location.isGranted,
              ),
              
              if (viewModel.bluetoothPermissions!.bluetoothScan != null)
                _buildStatusItem(
                  'Bluetooth Scan', 
                  viewModel.bluetoothPermissions!.bluetoothScan!.isGranted,
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          if (!viewModel.hasBluetoothPermissions)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                viewModel.requestBluetoothPermissions();
              },
              child: const Text('Request Permissions'),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String name, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(name),
        ],
      ),
    );
  }
}
