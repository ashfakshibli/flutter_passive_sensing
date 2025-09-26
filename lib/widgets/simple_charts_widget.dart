import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../viewmodels/bluetooth_scanning_viewmodel.dart';

class SimpleChartsWidget extends StatelessWidget {
  const SimpleChartsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothScanningViewModel>(
      builder: (context, viewModel, child) {
        return Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device count chart
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Device Count',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: LineChart(
                              _buildDeviceCountChart(viewModel),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Signal strength chart
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Avg Signal Strength',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: LineChart(
                              _buildSignalStrengthChart(viewModel),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  LineChartData _buildDeviceCountChart(BluetoothScanningViewModel viewModel) {
    final scanHistory = viewModel.scanHistory;
    
    if (scanHistory.isEmpty) {
      return LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [const FlSpot(0, 0)],
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      );
    }

    // Get the last 20 data points for display
    final displayData = scanHistory.length > 20 
        ? scanHistory.sublist(scanHistory.length - 20) 
        : scanHistory;

    final spots = displayData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.deviceCount.toDouble());
    }).toList();

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.blue,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade300),
      ),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
    );
  }

  LineChartData _buildSignalStrengthChart(BluetoothScanningViewModel viewModel) {
    final scanHistory = viewModel.scanHistory;
    
    if (scanHistory.isEmpty) {
      return LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: [const FlSpot(0, -60)],
            isCurved: true,
            color: Colors.green,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      );
    }

    // Get the last 20 data points for display
    final displayData = scanHistory.length > 20 
        ? scanHistory.sublist(scanHistory.length - 20) 
        : scanHistory;

    final spots = displayData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.averageRssi);
    }).toList();

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: Colors.green,
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      ],
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  '${value.toInt()}dBm',
                  style: const TextStyle(fontSize: 8),
                ),
              );
            },
          ),
        ),
        bottomTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.shade300),
      ),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey.shade200,
            strokeWidth: 1,
          );
        },
      ),
    );
  }
}