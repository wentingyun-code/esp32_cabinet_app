import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/cabinet_data.dart';

class HistoryPage extends StatelessWidget {
  final VoidCallback? onRebuild;
  const HistoryPage({super.key, this.onRebuild});

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS || context.watch<CabinetData>().debugForceIOS;
    
    if (isIOS) {
      return CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('历史数据'),
        ),
        child: SafeArea(
          child: _buildHistoryList(context),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史数据'),
      ),
      body: _buildHistoryList(context),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return Consumer<CabinetData>(
      builder: (context, data, child) {
        if (data.historyRecords.isEmpty) {
          return const Center(
            child: Text('暂无历史数据'),
          );
        }
        return ListView.builder(
          itemCount: data.historyRecords.length,
          itemBuilder: (context, index) {
            final record = data.historyRecords[index];
            return ListTile(
              title: Text('温度: ${record.temperature.toStringAsFixed(1)}°C, 湿度: ${record.humidity.toStringAsFixed(1)}%'),
              subtitle: Text(record.timestamp.toString()),
            );
          },
        );
      },
    );
  }
}
