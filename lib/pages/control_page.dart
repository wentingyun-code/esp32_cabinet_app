import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_data.dart';
import '../services/thingsboard_service.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  Widget _buildPlatformSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color activeColor,
  }) {
    if (Platform.isIOS) {
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor,
      );
    } else {
      return Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: activeColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: Consumer<CabinetData>(
        builder: (context, data, child) {
          bool isAutoMode = data.requestedMode == 'AUTO';
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // 运行模式
              Card(
                elevation: 4,
                child: SwitchListTile(
                  title: const Text('自动模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isAutoMode ? '系统自动控制执行机构' : '手动控制执行机构'),
                  value: isAutoMode,
                  activeThumbColor: Colors.green,
                  onChanged: (bool value) {
                    data.requestedMode = value ? 'AUTO' : 'MANUAL';
                    data.userOverrideAutoMode = !value;
                    data.notifyDataChanged();
                    context.read<ThingsBoardService>().publishModeChange(value ? 'AUTO' : 'MANUAL');
                  },
                ),
              ),
              const SizedBox(height: 20),
              // 执行机构控制
              Text('执行机构控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const SizedBox(height: 10),
              Card(
                elevation: 4,
                child: ListTile(
                  title: const Text('排风扇'),
                  subtitle: const Text('通风降温'),
                  trailing: _buildPlatformSwitch(
                    value: data.fanStatus,
                    activeColor: isAutoMode ? Colors.grey : Colors.green,
                    onChanged: isAutoMode ? null : (value) {
                      data.fanStatus = value;
                      data.notifyDataChanged();
                      context.read<ThingsBoardService>().publishControl('fan', value);
                    },
                  ),
                ),
              ),
              Card(
                elevation: 4,
                child: ListTile(
                  title: const Text('加热器'),
                  subtitle: const Text('升温除凝露'),
                  trailing: _buildPlatformSwitch(
                    value: data.heaterStatus,
                    activeColor: isAutoMode ? Colors.grey : Colors.orange,
                    onChanged: isAutoMode ? null : (value) {
                      data.heaterStatus = value;
                      data.notifyDataChanged();
                      context.read<ThingsBoardService>().publishControl('heater', value);
                    },
                  ),
                ),
              ),
              Card(
                elevation: 4,
                child: ListTile(
                  title: const Text('制冷器'),
                  subtitle: const Text('降温除湿'),
                  trailing: _buildPlatformSwitch(
                    value: data.coolerStatus,
                    activeColor: isAutoMode ? Colors.grey : Colors.cyan,
                    onChanged: isAutoMode ? null : (value) {
                      data.coolerStatus = value;
                      data.notifyDataChanged();
                      context.read<ThingsBoardService>().publishControl('cooler', value);
                    },
                  ),
                ),
              ),
              Card(
                elevation: 4,
                child: ListTile(
                  title: const Text('雾化器'),
                  subtitle: const Text('加湿防干燥'),
                  trailing: _buildPlatformSwitch(
                    value: data.atomizerStatus,
                    activeColor: isAutoMode ? Colors.grey : Colors.teal,
                    onChanged: isAutoMode ? null : (value) {
                      data.atomizerStatus = value;
                      data.notifyDataChanged();
                      context.read<ThingsBoardService>().publishControl('atomizer', value);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
