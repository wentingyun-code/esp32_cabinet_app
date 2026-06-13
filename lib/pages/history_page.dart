import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cabinet_data.dart';

class HistoryPage extends StatelessWidget {
  final VoidCallback? onRebuild;
  const HistoryPage({super.key, this.onRebuild});

  @override
  Widget build(BuildContext context) {
    final isAndroid = Platform.isAndroid;
    return Scaffold(
      backgroundColor: isAndroid ? const Color(0xFF0A1929) : const Color(0xFFF2F6FA),
      appBar: isAndroid ? _buildAndroidAppBar() : _buildIOSAppBar(),
      body: Consumer<CabinetData>(
        builder: (context, data, child) {
          if (data.historyRecords.isEmpty) {
            return _buildEmptyState(isAndroid);
          }
          final groups = _groupByDay(data.historyRecords);
          return _buildGroupedList(groups, isAndroid);
        },
      ),
    );
  }

  AppBar _buildAndroidAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A1929),
      elevation: 0,
      title: const Text(
        '历史数据',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan.withOpacity(0), Colors.cyan, Colors.cyan.withOpacity(0)],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildIOSAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF2F6FA),
      elevation: 0,
      centerTitle: false,
      title: const Padding(
        padding: EdgeInsets.only(left: 8),
        child: Text(
          '历史数据',
          style: TextStyle(
            color: Color(0xFF1C1C1E),
            fontWeight: FontWeight.w700,
            fontSize: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isAndroid) {
    return Container(
      color: isAndroid ? const Color(0xFF0A1929) : const Color(0xFFF2F6FA),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 72, color: isAndroid ? Colors.white24 : Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              '暂无历史数据',
              style: TextStyle(
                fontSize: 16,
                color: isAndroid ? Colors.white38 : Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '数据将自动记录到此处',
              style: TextStyle(
                fontSize: 13,
                color: isAndroid ? Colors.white24 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, List<HistoryRecord>> _groupByDay(List<HistoryRecord> records) {
    final groups = <String, List<HistoryRecord>>{};
    for (final record in records) {
      final key =
          '${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(record);
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in sortedKeys) k: groups[k]!};
  }

  Widget _buildGroupedList(Map<String, List<HistoryRecord>> groups, bool isAndroid) {
    final items = <dynamic>[];
    for (final entry in groups.entries) {
      items.add(_DayHeaderData(entry.key, entry.value));
      items.addAll(entry.value);
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: isAndroid ? 12 : 16, vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is _DayHeaderData) {
          return isAndroid
              ? _buildAndroidDayHeader(item)
              : _buildIOSDayHeader(item);
        }
        return isAndroid
            ? _buildAndroidRecordCard(item as HistoryRecord)
            : _buildIOSRecordCard(item as HistoryRecord);
      },
    );
  }

  // ==================== Android 深色科技风格 ====================

  Widget _buildAndroidDayHeader(_DayHeaderData data) {
    final date = data.records.first.timestamp;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.cyan,
              borderRadius: BorderRadius.circular(2),
              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${date.month}月${date.day}日',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '共 ${data.records.length} 条',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidRecordCard(HistoryRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // 顶部：时间 + 天气大图标
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _formatTime(record.timestamp),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _weatherLargeIcon(record.weather, true),
                ],
              ),
            ),
            // 中部：温湿压
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _androidMetricItem(Icons.thermostat, '${record.temperature.toStringAsFixed(1)}°C', Colors.orangeAccent),
                  _androidMetricItem(Icons.water_drop, '${record.humidity.toStringAsFixed(1)}%', Colors.cyanAccent),
                  _androidMetricItem(Icons.speed, '${record.pressure.toStringAsFixed(0)}hPa', Colors.purpleAccent),
                ],
              ),
            ),
            // 底部：设备状态指示灯
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  if (record.fanStatus) _androidDeviceDot('排风', Colors.greenAccent),
                  if (record.heaterStatus) _androidDeviceDot('加热', Colors.orangeAccent),
                  if (record.coolerStatus) _androidDeviceDot('制冷', Colors.cyanAccent),
                  if (record.atomizerStatus) _androidDeviceDot('雾化', Colors.tealAccent),
                  if (record.dehumidifierStatus) _androidDeviceDot('除湿', Colors.blueAccent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _androidMetricItem(IconData icon, String value, Color color) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _androidDeviceDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color.withOpacity(0.85), fontSize: 11)),
      ],
    );
  }

  // ==================== iOS 玻璃拟态风格 ====================

  Widget _buildIOSDayHeader(_DayHeaderData data) {
    final date = data.records.first.timestamp;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
      child: Row(
        children: [
          Text(
            '${date.month}月${date.day}日',
            style: const TextStyle(
              color: Color(0xFF1C1C1E),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '${data.records.length} 条记录',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildIOSRecordCard(HistoryRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTime(record.timestamp),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _iosMetricPill(Icons.thermostat, '${record.temperature.toStringAsFixed(1)}°C', const Color(0xFFFF6B6B)),
                                const SizedBox(width: 8),
                                _iosMetricPill(Icons.water_drop, '${record.humidity.toStringAsFixed(1)}%', const Color(0xFF4ECDC4)),
                                const SizedBox(width: 8),
                                _iosMetricPill(Icons.speed, record.pressure.toStringAsFixed(0), const Color(0xFFA29BFE)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _weatherLargeIcon(record.weather, false),
                    ],
                  ),
                ),
                if (record.fanStatus || record.heaterStatus || record.coolerStatus || record.atomizerStatus || record.dehumidifierStatus)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                    child: Row(
                      children: [
                        if (record.fanStatus) _iosDeviceBadge('排风', const Color(0xFF4ECDC4)),
                        if (record.heaterStatus) _iosDeviceBadge('加热', const Color(0xFFFF6B6B)),
                        if (record.coolerStatus) _iosDeviceBadge('制冷', const Color(0xFF45B7D1)),
                        if (record.atomizerStatus) _iosDeviceBadge('雾化', const Color(0xFF96CEB4)),
                        if (record.dehumidifierStatus) _iosDeviceBadge('除湿', const Color(0xFF74B9FF)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iosMetricPill(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _iosDeviceBadge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ==================== 通用组件 ====================

  Widget _weatherLargeIcon(String weather, bool isDark) {
    final info = _weatherInfo(weather);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: info.color.withOpacity(isDark ? 0.1 : 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(info.icon, size: 28, color: info.color),
    );
  }

  _WeatherInfo _weatherInfo(String weather) {
    switch (weather.toUpperCase()) {
      case 'SUNNY':
      case 'CLEAR':
        return _WeatherInfo(Icons.wb_sunny, '晴天', const Color(0xFFFFB74D));
      case 'RAINY':
        return _WeatherInfo(Icons.water_drop, '雨天', const Color(0xFF4FC3F7));
      case 'SNOW':
        return _WeatherInfo(Icons.ac_unit, '雪天', const Color(0xFFB0BEC5));
      case 'MEIYU':
        return _WeatherInfo(Icons.cloud, '梅雨', const Color(0xFF90A4AE));
      case 'CLOUDY':
        return _WeatherInfo(Icons.cloud, '多云', const Color(0xFF90A4AE));
      default:
        return _WeatherInfo(Icons.wb_sunny, '晴天', const Color(0xFFFFB74D));
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _DayHeaderData {
  final String dayKey;
  final List<HistoryRecord> records;
  _DayHeaderData(this.dayKey, this.records);
}

class _WeatherInfo {
  final IconData icon;
  final String label;
  final Color color;
  _WeatherInfo(this.icon, this.label, this.color);
}
