import 'package:flutter/material.dart';

void main() {
  runApp(const BluetoothPassiveSensingApp());
}

class BluetoothPassiveSensingApp extends StatelessWidget {
  const BluetoothPassiveSensingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Passive Sensing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const PlaceholderHomeView(),
    );
  }
}

// Temporary placeholder until we create the actual home view
class PlaceholderHomeView extends StatelessWidget {
  const PlaceholderHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Bluetooth Passive Sensing'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.bluetooth_searching,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Bluetooth Passive Sensing',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Looking for Bluetooth devices...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
