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

  void _showTargetTempDialog(BuildContext context, CabinetData data) {
    final mqttService = context.read<ThingsBoardService>();
    double temp = data.targetTemp;

    if (Platform.isIOS || data.debugForceIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => CupertinoAlertDialog(
            title: Text('设置目标温度'),
            content: Column(
              children: [
                SizedBox(height: 12),
                Text('当前: ${temp.toStringAsFixed(1)} °C'),
                SizedBox(height: 12),
                CupertinoSlider(
                  value: temp,
                  min: 10.0,
                  max: 50.0,
                  divisions: 40,
                  onChanged: (v) => setState(() => temp = v),
                  onChangeEnd: (v) {
                    mqttService.publishTargetTemp(v);
                    data.setTargetTemp(v);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('10°C'), Text('50°C')],
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text('确定'),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('设置目标温度'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('当前: ${temp.toStringAsFixed(1)} °C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Slider(
                  value: temp,
                  min: 10.0,
                  max: 50.0,
                  divisions: 40,
                  label: '${temp.toStringAsFixed(1)} °C',
                  onChanged: (v) => setState(() => temp = v),
                  onChangeEnd: (v) {
                    mqttService.publishTargetTemp(v);
                    data.setTargetTemp(v);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('10°C'), Text('50°C')],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('确定'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showTargetHumidityDialog(BuildContext context, CabinetData data) {
    final mqttService = context.read<ThingsBoardService>();
    double humidity = data.targetHumidity;

    if (Platform.isIOS || data.debugForceIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => CupertinoAlertDialog(
            title: Text('设置目标湿度'),
            content: Column(
              children: [
                SizedBox(height: 12),
                Text('当前: ${humidity.toStringAsFixed(1)} %'),
                SizedBox(height: 12),
                CupertinoSlider(
                  value: humidity,
                  min: 20.0,
                  max: 90.0,
                  divisions: 70,
                  onChanged: (v) => setState(() => humidity = v),
                  onChangeEnd: (v) {
                    mqttService.publishTargetHumidity(v);
                    data.setTargetHumidity(v);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('20%'), Text('90%')],
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(ctx),
                child: Text('确定'),
              ),
            ],
          ),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('设置目标湿度'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('当前: ${humidity.toStringAsFixed(1)} %', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Slider(
                  value: humidity,
                  min: 20.0,
                  max: 90.0,
                  divisions: 70,
                  label: '${humidity.toStringAsFixed(1)} %',
                  onChanged: (v) => setState(() => humidity = v),
                  onChangeEnd: (v) {
                    mqttService.publishTargetHumidity(v);
                    data.setTargetHumidity(v);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text('20%'), Text('90%')],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('确定'),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showAlertConfigDialog(BuildContext context, CabinetData data) {
    final mqttService = context.read<ThingsBoardService>();
    double highHum = data.alertConfig.highHumidityThreshold;
    double highTemp = data.alertConfig.highTempThreshold;
    double maxHum = data.alertConfig.maxHumidityThreshold;
    double dewDiff = data.alertConfig.dewPointDiffThreshold;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('报警阈值配置'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('高湿度报警阈值: ${highHum.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w500)),
                Slider(value: highHum, min: 50, max: 100, divisions: 50, label: '${highHum.toStringAsFixed(0)}%', onChanged: (v) => setState(() => highHum = v)),
                SizedBox(height: 8),
                Text('高温报警阈值: ${highTemp.toStringAsFixed(0)}°C', style: TextStyle(fontWeight: FontWeight.w500)),
                Slider(value: highTemp, min: 30, max: 80, divisions: 50, label: '${highTemp.toStringAsFixed(0)}°C', onChanged: (v) => setState(() => highTemp = v)),
                SizedBox(height: 8),
                Text('极限湿度阈值: ${maxHum.toStringAsFixed(0)}%', style: TextStyle(fontWeight: FontWeight.w500)),
                Slider(value: maxHum, min: 60, max: 100, divisions: 40, label: '${maxHum.toStringAsFixed(0)}%', onChanged: (v) => setState(() => maxHum = v)),
                SizedBox(height: 8),
                Text('露点差报警阈值: ${dewDiff.toStringAsFixed(1)}°C', style: TextStyle(fontWeight: FontWeight.w500)),
                Slider(value: dewDiff, min: 1, max: 10, divisions: 18, label: '${dewDiff.toStringAsFixed(1)}°C', onChanged: (v) => setState(() => dewDiff = v)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final config = AlertConfig(
                  highHumidityThreshold: highHum,
                  highTempThreshold: highTemp,
                  maxHumidityThreshold: maxHum,
                  dewPointDiffThreshold: dewDiff,
                );
                data.updateAlertConfig(config);
                mqttService.publishAlertConfig(config.toJson());
                Navigator.pop(ctx);
              },
              child: Text('保存', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设备控制')),
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
                  title: Text('自动模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(isAutoMode ? '系统自动控制执行机构' : '手动控制执行机构'),
                  value: isAutoMode,
                  activeThumbColor: Colors.green,
                  onChanged: (bool value) {
                    data.requestedMode = value ? 'AUTO' : 'MANUAL';
                    data.userOverrideAutoMode = !value; // 关闭自动模式时设置覆盖标志
                    data.notifyDataChanged();
                    context.read<ThingsBoardService>().publishModeChange(value ? 'AUTO' : 'MANUAL');
                  },
                ),
              ),
              SizedBox(height: 20),
              // 目标参数设置
              Text('目标参数', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.thermostat, color: Colors.deepOrange),
                      title: Text('目标温度'),
                      subtitle: Text('${data.targetTemp.toStringAsFixed(1)} °C'),
                      trailing: Icon(Icons.edit),
                      onTap: () => _showTargetTempDialog(context, data),
                    ),
                    Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.water_drop, color: Colors.deepPurple),
                      title: Text('目标湿度'),
                      subtitle: Text('${data.targetHumidity.toStringAsFixed(1)} %'),
                      trailing: Icon(Icons.edit),
                      onTap: () => _showTargetHumidityDialog(context, data),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              // 执行机构控制
              Text('执行机构控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                child: ListTile(
                  title: Text('排风扇'),
                  subtitle: Text('通风降温'),
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
                  title: Text('加热器'),
                  subtitle: Text('升温除凝露'),
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
              SizedBox(height: 20),
              // 报警配置
              Text('报警配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              SizedBox(height: 10),
              Card(
                elevation: 4,
                child: ListTile(
                  leading: Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text('报警阈值设置'),
                  subtitle: Text('湿度>${data.alertConfig.highHumidityThreshold.toStringAsFixed(0)}% / 温度>${data.alertConfig.highTempThreshold.toStringAsFixed(0)}°C'),
                  trailing: Icon(Icons.settings),
                  onTap: () => _showAlertConfigDialog(context, data),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
