import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bluetooth_device_model.dart';
import '../viewmodels/bluetooth_scanning_viewmodel.dart';
import '../services/bluetooth_scanning_service.dart';
import 'simple_charts_widget.dart';

// Main Bluetooth scanning screen
class BluetoothScanningScreen extends StatelessWidget {
  const BluetoothScanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Scanner'),
        actions: [
          Consumer<BluetoothScanningViewModel>(
            builder: (context, viewModel, child) {
              return IconButton(
                icon: Icon(viewModel.isScanning ? Icons.stop : Icons.play_arrow),
                onPressed: () => viewModel.toggleScanning(),
                tooltip: viewModel.isScanning ? 'Stop Scan' : 'Start Scan',
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Scan Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Devices'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: const Column(
        children: [
          ScanningStatusCard(),
          SimpleChartsWidget(),
          ScanningFilters(),
          Expanded(child: DeviceList()),
        ],
      ),
      floatingActionButton: Consumer<BluetoothScanningViewModel>(
        builder: (context, viewModel, child) {
          return FloatingActionButton(
            onPressed: viewModel.isScanning ? null : () => viewModel.startScanning(),
            backgroundColor: viewModel.isScanning ? Colors.grey : null,
            child: Icon(viewModel.isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
          );
        },
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    final viewModel = context.read<BluetoothScanningViewModel>();
    
    switch (action) {
      case 'settings':
        _showScanSettings(context);
        break;
      case 'clear':
        _showClearConfirmation(context, viewModel);
        break;
    }
  }

  void _showScanSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ScanSettingsDialog(),
    );
  }

  void _showClearConfirmation(BuildContext context, BluetoothScanningViewModel viewModel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Devices'),
        content: Text('Remove all ${viewModel.deviceCount} discovered devices?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              viewModel.clearDevices();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

}

// Scanning status card
class ScanningStatusCard extends StatelessWidget {
  const ScanningStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothScanningViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getStatusColor(viewModel.state).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStatusColor(viewModel.state),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(viewModel.state),
                    color: _getStatusColor(viewModel.state),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      viewModel.getStatusDescription(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _getStatusColor(viewModel.state),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (viewModel.isScanning)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              
              if (viewModel.hasDevices) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ScanStatistics(),
              ],
              
              if (viewModel.hasError) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        viewModel.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: viewModel.clearError,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(ScanningState state) {
    switch (state) {
      case ScanningState.idle:
        return Colors.blue;
      case ScanningState.initializing:
        return Colors.orange;
      case ScanningState.scanning:
        return Colors.green;
      case ScanningState.stopping:
        return Colors.orange;
      case ScanningState.error:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(ScanningState state) {
    switch (state) {
      case ScanningState.idle:
        return Icons.bluetooth;
      case ScanningState.initializing:
        return Icons.bluetooth_searching;
      case ScanningState.scanning:
        return Icons.bluetooth_connected;
      case ScanningState.stopping:
        return Icons.stop;
      case ScanningState.error:
        return Icons.error;
    }
  }
}

// Scan statistics widget
class ScanStatistics extends StatelessWidget {
  const ScanStatistics({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothScanningViewModel>(
      builder: (context, viewModel, child) {
        final stats = viewModel.scanStatistics;
        final session = viewModel.getCurrentSession();
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
              icon: Icons.devices,
              label: 'Devices',
              value: '${viewModel.filteredDeviceCount}/${viewModel.deviceCount}',
            ),
            _StatItem(
              icon: Icons.signal_cellular_alt,
              label: 'Avg RSSI',
              value: '${stats['averageRssi'] ?? 0}',
            ),
            _StatItem(
              icon: Icons.timer,
              label: 'Duration',
              value: session != null 
                ? '${session.sessionDuration.inSeconds}s' 
                : '0s',
            ),
          ],
        );
      },
    );
  }
}

// Individual statistic item
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// Scanning filters widget
class ScanningFilters extends StatelessWidget {
  const ScanningFilters({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothScanningViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter by name...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: viewModel.setNameFilter,
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filter & Sort options',
                    onSelected: (value) => _handleFilterAction(viewModel, value),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'rssi_strong',
                        child: Row(
                          children: [
                            const Icon(Icons.signal_cellular_4_bar),
                            const SizedBox(width: 8),
                            Text('Strong Signals Only (>-60dBm)'),
                            if (viewModel.minRssi > -70) const Icon(Icons.check),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rssi_medium',
                        child: Row(
                          children: [
                            const Icon(Icons.signal_cellular_alt),
                            const SizedBox(width: 8),
                            Text('Medium+ Signals (>-80dBm)'),
                            if (viewModel.minRssi == -80) const Icon(Icons.check),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'rssi_all',
                        child: Row(
                          children: [
                            const Icon(Icons.signal_cellular_alt),
                            const SizedBox(width: 8),
                            Text('All Signal Strengths'),
                            if (viewModel.minRssi <= -100) const Icon(Icons.check),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      // Dynamic device type filters based on discovered devices
                      ...viewModel.getAvailableDeviceTypes().map((deviceType) => PopupMenuItem(
                        value: 'type_$deviceType',
                        child: Row(
                          children: [
                            Icon(_getDeviceTypeIcon(deviceType)),
                            const SizedBox(width: 8),
                            Text('${deviceType}s'),
                            if (viewModel.deviceTypeFilter == deviceType) const Icon(Icons.check),
                          ],
                        ),
                      )),
                      if (viewModel.getAvailableDeviceTypes().isNotEmpty)
                        PopupMenuItem(
                          value: 'type_all',
                          child: Row(
                            children: [
                              const Icon(Icons.devices),
                              const SizedBox(width: 8),
                              const Text('All Device Types'),
                              if (viewModel.deviceTypeFilter.isEmpty) const Icon(Icons.check),
                            ],
                          ),
                        ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'sort_rssi',
                        child: Row(
                          children: [
                            const Icon(Icons.signal_cellular_alt),
                            const SizedBox(width: 8),
                            const Text('Sort by Signal Strength'),
                            if (viewModel.sortBy == 'rssi') 
                              Icon(viewModel.sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'sort_name',
                        child: Row(
                          children: [
                            const Icon(Icons.sort_by_alpha),
                            const SizedBox(width: 8),
                            const Text('Sort by Name'),
                            if (viewModel.sortBy == 'name')
                              Icon(viewModel.sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                          ],
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      viewModel.showRecentOnly ? Icons.history : Icons.history_outlined,
                      color: viewModel.showRecentOnly ? Colors.blue : null,
                    ),
                    tooltip: 'Show recent devices only',
                    onPressed: () => viewModel.setShowRecentOnly(!viewModel.showRecentOnly),
                  ),
                ],
              ),
              // Filter status indicator
              if (viewModel.minRssi > -100 || viewModel.nameFilter.isNotEmpty || viewModel.deviceTypeFilter.isNotEmpty || viewModel.showRecentOnly)
                Container(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    children: [
                      if (viewModel.minRssi > -100)
                        Chip(
                          label: Text('RSSI > ${viewModel.minRssi}dBm'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => viewModel.setMinRssi(-100),
                        ),
                      if (viewModel.nameFilter.isNotEmpty)
                        Chip(
                          label: Text('Name: "${viewModel.nameFilter}"'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => viewModel.setNameFilter(''),
                        ),
                      if (viewModel.deviceTypeFilter.isNotEmpty)
                        Chip(
                          label: Text('Type: ${viewModel.deviceTypeFilter}'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => viewModel.setDeviceTypeFilter(''),
                        ),
                      if (viewModel.showRecentOnly)
                        Chip(
                          label: const Text('Recent only'),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => viewModel.setShowRecentOnly(false),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleFilterAction(BluetoothScanningViewModel viewModel, String action) {
    switch (action) {
      // RSSI Filtering
      case 'rssi_strong':
        viewModel.setMinRssi(-60); // Strong signals only
        break;
      case 'rssi_medium':
        viewModel.setMinRssi(-80); // Medium+ signals
        break;
      case 'rssi_all':
        viewModel.setMinRssi(-100); // All signals
        break;
      
      // Device Type Filtering (Based on dynamically discovered device types)
      case String deviceTypeAction when deviceTypeAction.startsWith('type_'):
        final deviceType = deviceTypeAction.substring(5); // Remove 'type_' prefix
        if (deviceType == 'all') {
          viewModel.setDeviceTypeFilter('');
        } else {
          viewModel.setDeviceTypeFilter(deviceType);
        }
        break;
      
      // Sorting
      case 'sort_rssi':
        if (viewModel.sortBy == 'rssi') {
          viewModel.setSortBy('rssi', ascending: !viewModel.sortAscending);
        } else {
          viewModel.setSortBy('rssi', ascending: false);
        }
        break;
      case 'sort_name':
        if (viewModel.sortBy == 'name') {
          viewModel.setSortBy('name', ascending: !viewModel.sortAscending);
        } else {
          viewModel.setSortBy('name', ascending: true);
        }
        break;
    }
  }

  IconData _getDeviceTypeIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'hid device':
        return Icons.keyboard;
      case 'heart rate monitor':
        return Icons.favorite;
      case 'battery service':
        return Icons.battery_std;
      case 'generic access':
      case 'generic attribute':
        return Icons.bluetooth;
      case 'device information':
        return Icons.info;
      default:
        return Icons.device_unknown;
    }
  }
}

// Device list widget
class DeviceList extends StatelessWidget {
  const DeviceList({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothScanningViewModel>(
      builder: (context, viewModel, child) {
        final devices = viewModel.devices;
        
        if (devices.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bluetooth_disabled,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  viewModel.isScanning 
                    ? 'Searching for devices...' 
                    : 'No devices found',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                if (!viewModel.isScanning) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap the scan button to start discovering devices',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return DeviceListTile(
              device: device,
              isSelected: viewModel.selectedDevice?.id == device.id,
              onTap: () => viewModel.selectDevice(device),
            );
          },
        );
      },
    );
  }
}

// Individual device list tile
class DeviceListTile extends StatelessWidget {
  final BluetoothDeviceModel device;
  final bool isSelected;
  final VoidCallback onTap;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Colors.blue.shade50 : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSignalColor(device.rssi),
          child: Text(
            device.rssi.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          device.displayName,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${device.deviceType} • ${device.signalStrengthDescription}'),
            Text(
              'ID: ${device.id.substring(0, 8)}... • Seen ${device.scanCount}x',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              device.isRecentlyActive ? Icons.circle : Icons.circle_outlined,
              color: device.isRecentlyActive ? Colors.green : Colors.grey,
              size: 12,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(device.lastSeen),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -50) return Colors.green;
    if (rssi >= -70) return Colors.orange;
    if (rssi >= -80) return Colors.red.shade300;
    return Colors.red;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else {
      return '${diff.inHours}h';
    }
  }
}

// Scan settings dialog
class ScanSettingsDialog extends StatefulWidget {
  const ScanSettingsDialog({super.key});

  @override
  State<ScanSettingsDialog> createState() => _ScanSettingsDialogState();
}

class _ScanSettingsDialogState extends State<ScanSettingsDialog> {
  late BluetoothScanConfig _config;

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<BluetoothScanningViewModel>();
    _config = viewModel.scanConfig;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scan Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Scan Duration'),
              subtitle: Text('${_config.scanDuration.inSeconds} seconds'),
              trailing: DropdownButton<int>(
                value: _config.scanDuration.inSeconds,
                items: [10, 30, 60, 120, 300].map((seconds) {
                  return DropdownMenuItem(
                    value: seconds,
                    child: Text('${seconds}s'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _config = BluetoothScanConfig(
                        scanDuration: Duration(seconds: value),
                        scanTimeout: _config.scanTimeout,
                        serviceUuids: _config.serviceUuids,
                        allowDuplicates: _config.allowDuplicates,
                        scanMode: _config.scanMode,
                      );
                    });
                  }
                },
              ),
            ),
            SwitchListTile(
              title: const Text('Allow Duplicates'),
              subtitle: const Text('Receive multiple results from same device'),
              value: _config.allowDuplicates,
              onChanged: (value) {
                setState(() {
                  _config = BluetoothScanConfig(
                    scanDuration: _config.scanDuration,
                    scanTimeout: _config.scanTimeout,
                    serviceUuids: _config.serviceUuids,
                    allowDuplicates: value,
                    scanMode: _config.scanMode,
                  );
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            context.read<BluetoothScanningViewModel>().updateScanConfig(_config);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}