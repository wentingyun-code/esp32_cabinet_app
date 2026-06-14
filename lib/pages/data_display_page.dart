import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_data.dart';
import '../services/thingsboard_service.dart';

class DataDisplayPage extends StatelessWidget {
  final VoidCallback? onRebuild;
  const DataDisplayPage({super.key, this.onRebuild});

  @override
  Widget build(BuildContext context) {
    return Consumer<CabinetData>(
      builder: (context, data, child) {
        final mqttService = context.read<ThingsBoardService>();
        return Scaffold(
          backgroundColor: const Color(0xFFE3F2FD),
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
                  const SizedBox(height: 20),
                  // 通道B: 设备运行状态
                  _buildSectionTitle('通道B · 设备运行状态', Icons.settings_remote, Colors.purple),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildComfortZoneCard(data.inComfortZone)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildWeatherCard('当前天气', data.currentWeather)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildWeatherCard('模拟天气', data.simulatedWeather)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildModeCard('请求模式', data.requestedMode)),
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
                      Expanded(child: _buildDeviceCard('制冷器', data.coolerStatus, Icons.ac_unit, Colors.cyan)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDeviceCard('雾化器', data.atomizerStatus, Icons.water_drop, Colors.teal)),
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
                Flexible(child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.clip, softWrap: false)),
                const SizedBox(width: 2),
                Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComfortZoneCard(bool inComfortZone) {
    final color = inComfortZone ? Colors.green : Colors.red;
    final icon = inComfortZone ? Icons.check_circle : Icons.warning;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 4),
                Text('舒适区', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 8),
            Text(inComfortZone ? '在舒适区' : '不在舒适区', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(String label, String weather) {
    final weatherInfo = {
      'SUNNY':  {'icon': Icons.wb_sunny,              'color': Colors.amber,      'label': '高温', 'desc': '高温低湿'},
      'RAINY':  {'icon': Icons.grain,                  'color': Colors.blueGrey,   'label': '暴雨', 'desc': '中温高湿'},
      'SNOW':   {'icon': Icons.ac_unit,                'color': Colors.lightBlue,  'label': '低温', 'desc': '低温环境'},
      'MEIYU':  {'icon': Icons.water_drop,             'color': Colors.purple,     'label': '梅雨', 'desc': '高温高湿'},
      'CLEAR':  {'icon': Icons.wb_sunny,               'color': Colors.amber,      'label': '高温', 'desc': ''},
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
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
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
    final type = data.alertType;
    final isDew = type == 'dew';
    final isTempLow = type == 'temp_low';
    final isTempHigh = type == 'temp_high';
    final isHumidityLow = type == 'humidity_low';
    final isHumidityHigh = type == 'humidity_high';

    Color bannerColor;
    IconData bannerIcon;
    if (isDew) {
      bannerColor = Colors.orange;
      bannerIcon = Icons.water_drop;
    } else if (isTempLow) {
      bannerColor = Colors.blue;
      bannerIcon = Icons.ac_unit;
    } else if (isTempHigh) {
      bannerColor = Colors.red;
      bannerIcon = Icons.thermostat;
    } else if (isHumidityLow) {
      bannerColor = Colors.amber;
      bannerIcon = Icons.water_drop_outlined;
    } else if (isHumidityHigh) {
      bannerColor = Colors.deepOrange;
      bannerIcon = Icons.water_drop;
    } else {
      bannerColor = Colors.red;
      bannerIcon = Icons.warning_amber;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bannerColor, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.alertMessage ?? '',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: bannerColor.withValues(alpha: 1.0)),
            ),
          ),
        ],
      ),
    );
  }
}
