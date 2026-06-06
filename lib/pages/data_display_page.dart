import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_data.dart';
import '../services/thingsboard_service.dart';

class DataDisplayPage extends StatelessWidget {
  final VoidCallback? onRebuild;
  const DataDisplayPage({super.key, this.onRebuild});

  void _showDebugDialog(BuildContext context) {
    final data = context.read<CabinetData>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('调试模式'),
        content: Text('当前: ${data.debugForceIOS ? "iOS 模式" : "Android 模式"}\n切换后将重启 UI 以应用新主题'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () {
              data.toggleDebugForceIOS();
              Navigator.pop(ctx);
            },
            child: Text('切换为${data.debugForceIOS ? "Android" : "iOS"}模式'),
          ),
        ],
      ),
    );
  }

  void _showConnectionError(BuildContext context) {
    final mqttService = context.read<ThingsBoardService>();
    final isIOS = Platform.isIOS || context.read<CabinetData>().debugForceIOS;
    final content = mqttService.lastErrorDetail.isNotEmpty
        ? mqttService.lastErrorDetail
        : '正在尝试连接...\n请稍后再试';

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('连接诊断'),
          content: Text(content),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } else {
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
  }

  void _showExitDialog(BuildContext context) {
    final isIOS = Platform.isIOS || context.read<CabinetData>().debugForceIOS;
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text('退出应用'),
          content: Text('确定要退出环网柜监控系统吗？'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                SystemNavigator.pop();
              },
              child: Text('退出'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('退出应用'),
          content: Text('确定要退出环网柜监控系统吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                SystemNavigator.pop();
              },
              child: Text('退出', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  // ==================== Android UI ====================
  Widget _buildAndroidUI(BuildContext context, CabinetData data) {
    final mqttService = context.read<ThingsBoardService>();
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onLongPress: () => _showDebugDialog(context),
          child: Text('环网柜实时监控'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: _ConnectionStatusWidget(
                isConnected: data.isConnected,
                isIOS: false,
                errorInfo: data.isConnected ? null : mqttService.lastError,
                onTap: data.isConnected ? null : () => _showConnectionError(context),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.exit_to_app),
            onPressed: () => _showExitDialog(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await mqttService.connect();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 报警横幅
              if (data.alertMessage != null) ...[
                _buildAlertBanner(data),
                SizedBox(height: 8),
              ],
              // 通道A: 环境核心指标
              _buildSectionTitle('通道A · 环境核心指标', Icons.sensors, Colors.blue),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('柜内温度', data.temperature.toStringAsFixed(1), '°C', Icons.thermostat, Colors.red)),
                  SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('柜内湿度', data.humidity.toStringAsFixed(1), '%', Icons.water_drop, Colors.blue)),
                  SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('柜内气压', data.pressure.toStringAsFixed(0), 'hPa', Icons.speed, Colors.teal)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('露点温度', data.dewPoint.toStringAsFixed(1), '°C', Icons.ac_unit, Colors.indigo)),
                  SizedBox(width: 8),
                  Expanded(child: _buildRiskCard('结露风险', data.condensationRisk)),
                  SizedBox(width: 8),
                  Expanded(child: _buildStatusCard('传感器', data.sensorPresent ? '在线' : '离线', data.sensorPresent)),
                ],
              ),
              SizedBox(height: 16),
              // 户外环境
              _buildSectionTitle('户外环境模拟', Icons.outdoor_grill, Colors.green),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('户外温度', data.outdoorTemperature.toStringAsFixed(1), '°C', Icons.wb_sunny, Colors.orange)),
                  SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('户外湿度', data.outdoorHumidity.toStringAsFixed(1), '%', Icons.cloud, Colors.lightBlue)),
                  SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('户外气压', data.outdoorPressure.toStringAsFixed(0), 'hPa', Icons.air, Colors.cyan)),
                ],
              ),
              SizedBox(height: 16),
              // 通道B: 设备运行状态
              _buildSectionTitle('通道B · 设备运行状态', Icons.settings_remote, Colors.purple),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildWeatherCard(data.weather)),
                  SizedBox(width: 8),
                  Expanded(child: _buildModeCard('请求模式', data.requestedMode)),
                  SizedBox(width: 8),
                  Expanded(child: _buildModeCard('激活模式', data.activeMode)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildDeviceCard('排风扇', data.fanStatus, Icons.toys, Colors.green)),
                  SizedBox(width: 8),
                  Expanded(child: _buildDeviceCard('加热板', data.heaterStatus, Icons.local_fire_department, Colors.orange)),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildMetricCard('目标温度', data.targetTemp.toStringAsFixed(1), '°C', Icons.track_changes, Colors.deepOrange)),
                  SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('目标湿度', data.targetHumidity.toStringAsFixed(1), '%', Icons.tune, Colors.deepPurple)),
                  SizedBox(width: 8),
                  Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                SizedBox(width: 4),
                Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
              ],
            ),
            SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), overflow: TextOverflow.ellipsis)),
                SizedBox(width: 2),
                Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isHigh ? BorderSide(color: Colors.red.withValues(alpha: 0.5), width: 2) : BorderSide.none),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isHigh ? Icons.warning : Icons.check_circle, color: color, size: 18),
                SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 8),
            Text(risk, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String label, String status, bool isOnline) {
    final color = isOnline ? Colors.green : Colors.grey;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isOnline ? Icons.sensors : Icons.sensors_off, color: color, size: 18),
                SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 8),
            Text(status, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(String weather) {
    final isClear = weather == 'CLEAR';
    final icon = isClear ? Icons.wb_sunny : Icons.grain;
    final color = isClear ? Colors.amber : Colors.blueGrey;
    final label = isClear ? '晴天' : '雨天';
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                SizedBox(width: 4),
                Text('天气模式', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard(String label, String mode) {
    final colorMap = {'AUTO': Colors.green, 'MANUAL': Colors.orange, 'COMFORT': Colors.blue, 'DEW_PREVENT': Colors.purple, 'HEAT': Colors.red, 'COOL': Colors.cyan};
    final color = colorMap[mode] ?? Colors.grey;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: color, size: 18),
                SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 8),
            Text(mode, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(String label, bool isOn, IconData icon, Color color) {
    return Card(
      elevation: 2,
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
                SizedBox(width: 4),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
            SizedBox(height: 8),
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
          SizedBox(width: 12),
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

  // ==================== iOS UI ====================
  Widget _buildIOSUI(BuildContext context, CabinetData data) {
    final mqttService = context.read<ThingsBoardService>();
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: GestureDetector(
          onLongPress: () => _showDebugDialog(context),
          child: Text('环网柜实时监控'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ConnectionStatusWidget(
              isConnected: data.isConnected,
              isIOS: true,
              errorInfo: data.isConnected ? null : mqttService.lastError,
              onTap: data.isConnected ? null : () => _showConnectionError(context),
            ),
            const SizedBox(width: 4),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Icon(CupertinoIcons.square_arrow_left),
              onPressed: () => _showExitDialog(context),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 报警
              if (data.alertMessage != null) ...[
                _buildIOSAlertBanner(data),
                SizedBox(height: 12),
              ],
              // 通道A: 环境核心指标
              _buildIOSGroupHeader('通道A · 环境核心指标'),
              _buildIOSGroup([
                _buildIOSCell(icon: CupertinoIcons.thermometer, iconColor: CupertinoColors.systemRed, title: '柜内温度', value: '${data.temperature.toStringAsFixed(1)} °C'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.drop, iconColor: CupertinoColors.systemBlue, title: '柜内湿度', value: '${data.humidity.toStringAsFixed(1)} %'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.gauge, iconColor: CupertinoColors.systemTeal, title: '柜内气压', value: '${data.pressure.toStringAsFixed(0)} hPa'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.snow, iconColor: CupertinoColors.systemIndigo, title: '露点温度', value: '${data.dewPoint.toStringAsFixed(1)} °C'),
                _buildIOSSeparator(),
                _buildIOSRiskCell(data.condensationRisk),
                _buildIOSSeparator(),
                _buildIOSCell(icon: data.sensorPresent ? CupertinoIcons.antenna_radiowaves_left_right : CupertinoIcons.wifi_slash, iconColor: data.sensorPresent ? CupertinoColors.systemGreen : CupertinoColors.systemGrey, title: '传感器状态', value: data.sensorPresent ? '在线' : '离线'),
              ]),
              SizedBox(height: 24),
              // 户外环境
              _buildIOSGroupHeader('户外环境模拟'),
              _buildIOSGroup([
                _buildIOSCell(icon: CupertinoIcons.sun_max, iconColor: CupertinoColors.systemOrange, title: '户外温度', value: '${data.outdoorTemperature.toStringAsFixed(1)} °C'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.cloud, iconColor: CupertinoColors.systemBlue, title: '户外湿度', value: '${data.outdoorHumidity.toStringAsFixed(1)} %'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.wind, iconColor: CupertinoColors.systemCyan, title: '户外气压', value: '${data.outdoorPressure.toStringAsFixed(0)} hPa'),
              ]),
              SizedBox(height: 24),
              // 通道B: 设备运行状态
              _buildIOSGroupHeader('通道B · 设备运行状态'),
              _buildIOSGroup([
                _buildIOSCell(icon: data.weather == 'CLEAR' ? CupertinoIcons.sun_max : CupertinoIcons.cloud_rain, iconColor: data.weather == 'CLEAR' ? CupertinoColors.systemYellow : CupertinoColors.systemGrey, title: '天气模式', value: data.weather == 'CLEAR' ? '晴天' : '雨天'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.arrow_3_trianglepath, iconColor: CupertinoColors.systemGreen, title: '请求模式', value: data.requestedMode),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.gear, iconColor: CupertinoColors.systemPurple, title: '激活模式', value: data.activeMode),
                _buildIOSSeparator(),
                _buildIOSDeviceCell('排风扇', data.fanStatus, CupertinoIcons.arrow_clockwise, data.requestedMode != 'MANUAL'),
                _buildIOSSeparator(),
                _buildIOSDeviceCell('加热板', data.heaterStatus, CupertinoIcons.flame, data.requestedMode != 'MANUAL'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.scope, iconColor: CupertinoColors.systemOrange, title: '目标温度', value: '${data.targetTemp.toStringAsFixed(1)} °C'),
                _buildIOSSeparator(),
                _buildIOSCell(icon: CupertinoIcons.gauge, iconColor: CupertinoColors.systemPurple, title: '目标湿度', value: '${data.targetHumidity.toStringAsFixed(1)} %'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIOSAlertBanner(CabinetData data) {
    final isDew = data.alertType == 'dew';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDew ? CupertinoColors.systemOrange.withValues(alpha: 0.1) : CupertinoColors.systemRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDew ? CupertinoColors.systemOrange : CupertinoColors.systemRed, width: 1),
      ),
      child: Row(
        children: [
          Icon(isDew ? CupertinoIcons.drop : CupertinoIcons.exclamationmark_triangle, color: isDew ? CupertinoColors.systemOrange : CupertinoColors.systemRed, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              data.alertMessage ?? '',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDew ? CupertinoColors.systemOrange : CupertinoColors.systemRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSRiskCell(String risk) {
    final isHigh = risk == 'HIGH';
    return _buildIOSCell(
      icon: isHigh ? CupertinoIcons.exclamationmark_triangle : CupertinoIcons.checkmark_shield,
      iconColor: isHigh ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
      title: '结露风险',
      value: risk,
      valueColor: isHigh ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
    );
  }

  Widget _buildIOSDeviceCell(String label, bool isOn, IconData icon, bool isAuto) {
    return _buildIOSCell(
      icon: icon,
      iconColor: isOn ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
      title: label,
      value: isOn ? '运行中' : '已停止',
      valueColor: isOn ? CupertinoColors.systemGreen : CupertinoColors.systemGrey,
    );
  }

  Widget _buildIOSGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey,
        ),
      ),
    );
  }

  Widget _buildIOSGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildIOSCell({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 16, color: CupertinoColors.black),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 16, color: valueColor ?? CupertinoColors.systemGrey, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 8),
          Icon(CupertinoIcons.chevron_right, color: CupertinoColors.systemGrey3, size: 18),
        ],
      ),
    );
  }

  Widget _buildIOSSeparator() {
    return Container(
      margin: const EdgeInsets.only(left: 60.0),
      height: 0.5,
      color: CupertinoColors.systemGrey4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CabinetData>(
      builder: (context, data, child) {
        final isIOS = Platform.isIOS || data.debugForceIOS;
        if (isIOS) {
          return _buildIOSUI(context, data);
        } else {
          return _buildAndroidUI(context, data);
        }
      },
    );
  }
}

class _ConnectionStatusWidget extends StatelessWidget {
  final bool isConnected;
  final bool isIOS;
  final String? errorInfo;
  final VoidCallback? onTap;

  const _ConnectionStatusWidget({
    required this.isConnected,
    required this.isIOS,
    this.errorInfo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isConnected
        ? (isIOS ? CupertinoColors.systemGreen : Colors.green).withValues(alpha: 0.15)
        : (isIOS ? CupertinoColors.systemRed : Colors.red).withValues(alpha: 0.15);
    final dotColor = isConnected
        ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
        : (isIOS ? CupertinoColors.systemRed : Colors.red);
    final textColor = isConnected
        ? (isIOS ? CupertinoColors.systemGreen : Colors.green)
        : (isIOS ? CupertinoColors.systemRed : Colors.red);

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
                isIOS ? CupertinoIcons.info_circle : Icons.info_outline,
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
