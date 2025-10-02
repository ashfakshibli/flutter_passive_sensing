import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../viewmodels/permission_viewmodel.dart';
import '../viewmodels/bluetooth_scanning_viewmodel.dart';

class PermissionWidget extends StatefulWidget {
  final Widget child;
  final bool checkOnInit;

  const PermissionWidget({
    Key? key,
    required this.child,
    this.checkOnInit = true,
  }) : super(key: key);

  @override
  State<PermissionWidget> createState() => _PermissionWidgetState();
}

class _PermissionWidgetState extends State<PermissionWidget> 
    with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    if (widget.checkOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<PermissionViewModel>().checkBluetoothPermissions();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh permissions when app resumes (user might have changed them in settings)
      context.read<PermissionViewModel>().refreshPermissions();
      
      // Background Scanning: Resume foreground scanning mode
      final scanningViewModel = context.read<BluetoothScanningViewModel>();
      if (scanningViewModel.isScanning) {
        scanningViewModel.resumeForegroundScanning();
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // Background Scanning: Switch to background scanning mode
      final scanningViewModel = context.read<BluetoothScanningViewModel>();
      if (scanningViewModel.isScanning) {
        scanningViewModel.enterBackgroundScanning();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PermissionViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Checking permissions...'),
                ],
              ),
            ),
          );
        }

        if (!viewModel.hasBluetoothPermissions) {
          return _buildPermissionScreen(viewModel);
        }

        return widget.child;
      },
    );
  }

  Widget _buildPermissionScreen(PermissionViewModel viewModel) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Required'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.security,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 24),
            
            Text(
              'Bluetooth Permissions Required',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            Text(
              Platform.isIOS 
                ? 'This app needs Bluetooth permission to scan for nearby devices and collect passive sensing data.'
                : 'This app needs Bluetooth and location permissions to scan for nearby devices and collect passive sensing data.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            if (viewModel.bluetoothPermissions != null)
              _buildPermissionsList(viewModel),
              
            const SizedBox(height: 24),
            
            if (viewModel.errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        viewModel.errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: viewModel.clearError,
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
              ),
              
            const Spacer(),
            
            ElevatedButton.icon(
              onPressed: viewModel.isLoading ? null : () async {
                await viewModel.requestBluetoothPermissions();
              },
              icon: const Icon(Icons.security),
              label: const Text('Grant Permissions'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            if (viewModel.deniedPermissions.isNotEmpty)
              OutlinedButton.icon(
                onPressed: viewModel.isLoading ? null : () async {
                  await viewModel.openAppSettings();
                },
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsList(PermissionViewModel viewModel) {
    final permissions = viewModel.bluetoothPermissions!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permission Status:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          
          _buildPermissionItem(
            'Bluetooth', 
            permissions.bluetooth.isGranted,
          ),
          
          // Only show location permission on Android
          if (Platform.isAndroid)
            _buildPermissionItem(
              'Location', 
              permissions.location.isGranted,
            ),
          
          if (permissions.bluetoothScan != null)
            _buildPermissionItem(
              'Bluetooth Scan', 
              permissions.bluetoothScan!.isGranted,
            ),
            
          if (permissions.bluetoothConnect != null)
            _buildPermissionItem(
              'Bluetooth Connect', 
              permissions.bluetoothConnect!.isGranted,
            ),
            
          const SizedBox(height: 8),
          
          Text(
            viewModel.getPermissionStatusDescription(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String name, bool granted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(name),
          const Spacer(),
          Text(
            granted ? 'Granted' : 'Required',
            style: TextStyle(
              color: granted ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}