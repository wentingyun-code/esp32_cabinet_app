import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_data.dart';
import '../services/thingsboard_service.dart';

class DataDisplayPage extends StatelessWidget {
  final VoidCallback? onRebuild;
  const DataDisplayPage({super.key, this.onRebuild});

  void _showConnectionError(BuildContext context) {
    final mqttService = context.read<ThingsBoardService>();
    final content = mqttService.lastErrorDetail.isNotEmpty
        ? mqttService.lastErrorDetail
        : '正在尝试连接...\n请稍后再试';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('连接诊断'),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('确定要退出环网柜监控系统吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              SystemNavigator.pop();
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CabinetData>(
      builder: (context, data, child) {
        final mqttService = context.read<ThingsBoardService>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('环网柜实时监控'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: _ConnectionStatusWidget(
                    isConnected: data.isConnected,
                    errorInfo: data.isConnected ? null : mqttService.lastError,
                    onTap: data.isConnected ? null : () => _showConnectionError(context),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app),
                onPressed: () => _showExitDialog(context),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await mqttService.connect();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 报警横幅
                  if (data.alertMessage != null) ...[
                    _buildAlertBanner(data),
                    const SizedBox(height: 12),
                  ],
                  // 通道A: 环境核心指标
                  _buildSectionTitle('通道A · 环境核心指标', Icons.sensors, Colors.blue),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('柜内温度', data.temperature.toStringAsFixed(1), '°C', Icons.thermostat, Colors.red)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('柜内湿度', data.humidity.toStringAsFixed(1), '%', Icons.water_drop, Colors.blue)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('柜内气压', data.pressure.toStringAsFixed(0), 'hPa', Icons.speed, Colors.teal)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('露点温度', data.dewPoint.toStringAsFixed(1), '°C', Icons.ac_unit, Colors.indigo)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildRiskCard('结露风险', data.condensationRisk)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildStatusCard('传感器', data.sensorPresent ? '在线' : '离线', data.sensorPresent)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 户外环境
                  _buildSectionTitle('户外环境模拟', Icons.wb_sunny, Colors.green),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('户外温度', data.outdoorTemperature.toStringAsFixed(1), '°C', Icons.wb_sunny, Colors.orange)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('户外湿度', data.outdoorHumidity.toStringAsFixed(1), '%', Icons.cloud, Colors.lightBlue)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('户外气压', data.outdoorPressure.toStringAsFixed(0), 'hPa', Icons.air, Colors.cyan)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 通道B: 设备运行状态
                  _buildSectionTitle('通道B · 设备运行状态', Icons.settings_remote, Colors.purple),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildWeatherCard(data.weather)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildModeCard('请求模式', data.requestedMode)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildModeCard('激活模式', data.activeMode)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildDeviceCard('排风扇', data.fanStatus, Icons.toys, Colors.green)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDeviceCard('加热板', data.heaterStatus, Icons.local_fire_department, Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildMetricCard('目标温度', data.targetTemp.toStringAsFixed(1), '°C', Icons.track_changes, Colors.deepOrange)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildMetricCard('目标湿度', data.targetHumidity.toStringAsFixed(1), '%', Icons.tune, Colors.deepPurple)),
                      const SizedBox(width: 8),
                      Expanded(child: SizedBox()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 4),
                Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 2),
                Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard(String label, String risk) {
    final isHigh = risk == 'HIGH';
    final color = isHigh ? Colors.red : Colors.green;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHigh ? BorderSide(color: Colors.red.withValues(alpha: 0.5), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isHigh ? Icons.warning : Icons.check_circle, color: color, size: 18),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(risk, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, String status, bool isOnline) {
    final color = isOnline ? Colors.green : Colors.grey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isOnline ? Icons.sensors : Icons.sensors_off, color: color, size: 18),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(status, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(String weather) {
    final weatherInfo = {
      'SUNNY':  {'icon': Icons.wb_sunny,              'color': Colors.amber,      'label': '晴天', 'desc': '高温低湿'},
      'RAINY':  {'icon': Icons.grain,                  'color': Colors.blueGrey,   'label': '雨天', 'desc': '中温高湿'},
      'SNOW':   {'icon': Icons.ac_unit,                'color': Colors.lightBlue,  'label': '雪天', 'desc': '低温环境'},
      'MEIYU':  {'icon': Icons.water_drop,             'color': Colors.purple,     'label': '梅雨', 'desc': '高温高湿'},
      'CLEAR':  {'icon': Icons.wb_sunny,               'color': Colors.amber,      'label': '晴天', 'desc': ''},
    };
    final info = weatherInfo[weather] ?? {'icon': Icons.cloud, 'color': Colors.grey, 'label': weather, 'desc': ''};
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(info['icon'] as IconData, color: info['color'] as Color, size: 18),
                const SizedBox(width: 4),
                Text('天气模式', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(info['label'] as String, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: info['color'] as Color)),
            if ((info['desc'] as String).isNotEmpty)
              Text(info['desc'] as String, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(String label, String mode) {
    final colorMap = {
      'AUTO': Colors.green, 'MANUAL': Colors.orange,
      'COMFORT': Colors.blue, 'DEW_PREVENT': Colors.purple,
      'HEAT': Colors.red, 'COOL': Colors.cyan,
    };
    final color = colorMap[mode] ?? Colors.grey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: color, size: 18),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(mode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(String label, bool isOn, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOn ? BorderSide(color: color.withValues(alpha: 0.5), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: isOn ? color : Colors.grey, size: 18),
                const SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(isOn ? '运行中' : '已停止', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isOn ? color : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertBanner(CabinetData data) {
    final isDew = data.alertType == 'dew';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDew ? Colors.orange.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDew ? Colors.orange : Colors.red, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(isDew ? Icons.water_drop : Icons.warning_amber, color: isDew ? Colors.orange : Colors.red, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.alertMessage ?? '',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDew ? Colors.orange[800] : Colors.red[800]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusWidget extends StatelessWidget {
  final bool isConnected;
  final String? errorInfo;
  final VoidCallback? onTap;

  const _ConnectionStatusWidget({
    required this.isConnected,
    this.errorInfo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isConnected
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.15);
    final dotColor = isConnected ? Colors.green : Colors.red;
    final textColor = isConnected ? Colors.green : Colors.red;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isConnected ? '在线' : '离线',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (!isConnected && errorInfo != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.info_outline,
                size: 14,
                color: textColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
