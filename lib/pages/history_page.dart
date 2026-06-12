import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_data.dart';

class HistoryPage extends StatelessWidget {
  final VoidCallback? onRebuild;
  const HistoryPage({super.key, this.onRebuild});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史数据'),
      ),
      body: Consumer<CabinetData>(
        builder: (context, data, child) {
          if (data.historyRecords.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('暂无历史数据', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: data.historyRecords.length,
            itemBuilder: (context, index) {
              final record = data.historyRecords[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.thermostat, size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text('${record.temperature.toStringAsFixed(1)}°C', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.water_drop, size: 16, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text('${record.humidity.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.speed, size: 16, color: Colors.teal),
                              const SizedBox(width: 4),
                              Text('${record.pressure.toStringAsFixed(0)}hPa'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            _formatTime(record.timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                          const Spacer(),
                          if (record.fanStatus)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.toys, size: 14, color: Colors.green),
                            ),
                          if (record.heaterStatus)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
