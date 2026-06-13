import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

class AlertConfig {
  double highHumidityThreshold;
  double highTempThreshold;
  double maxHumidityThreshold;
  double dewPointDiffThreshold;

  AlertConfig({
    this.highHumidityThreshold = 80.0,
    this.highTempThreshold = 50.0,
    this.maxHumidityThreshold = 90.0,
    this.dewPointDiffThreshold = 3.0,
  });

  Map<String, dynamic> toJson() => {
        'highHumidityThreshold': highHumidityThreshold,
        'highTempThreshold': highTempThreshold,
        'maxHumidityThreshold': maxHumidityThreshold,
        'dewPointDiffThreshold': dewPointDiffThreshold,
      };

  factory AlertConfig.fromJson(Map<String, dynamic> json) => AlertConfig(
        highHumidityThreshold: (json['highHumidityThreshold'] ?? 80.0).toDouble(),
        highTempThreshold: (json['highTempThreshold'] ?? 50.0).toDouble(),
        maxHumidityThreshold: (json['maxHumidityThreshold'] ?? 90.0).toDouble(),
        dewPointDiffThreshold: (json['dewPointDiffThreshold'] ?? 3.0).toDouble(),
      );
}

class HistoryRecord {
  final int? id;
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double pressure;
  final double dewPoint;
  final double outdoorTemperature;
  final double outdoorHumidity;
  final double outdoorPressure;
  final String weather;
  final String condensationRisk;
  final String mode;
  final String activeMode;
  final bool fanStatus;
  final bool heaterStatus;
  final bool dehumidifierStatus;
  final bool coolerStatus;
  final bool atomizerStatus;

  HistoryRecord({
    this.id,
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    this.pressure = 0.0,
    required this.dewPoint,
    this.outdoorTemperature = 0.0,
    this.outdoorHumidity = 0.0,
    this.outdoorPressure = 0.0,
    required this.weather,
    this.condensationRisk = 'SAFE',
    required this.mode,
    this.activeMode = 'COMFORT',
    required this.fanStatus,
    required this.heaterStatus,
    required this.dehumidifierStatus,
    this.coolerStatus = false,
    this.atomizerStatus = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'temperature': temperature,
        'humidity': humidity,
        'pressure': pressure,
        'dewPoint': dewPoint,
        'outdoorTemperature': outdoorTemperature,
        'outdoorHumidity': outdoorHumidity,
        'outdoorPressure': outdoorPressure,
        'weather': weather,
        'condensationRisk': condensationRisk,
        'mode': mode,
        'activeMode': activeMode,
        'fanStatus': fanStatus ? 1 : 0,
        'heaterStatus': heaterStatus ? 1 : 0,
        'dehumidifierStatus': dehumidifierStatus ? 1 : 0,
        'coolerStatus': coolerStatus ? 1 : 0,
        'atomizerStatus': atomizerStatus ? 1 : 0,
      };

  factory HistoryRecord.fromMap(Map<String, dynamic> map) => HistoryRecord(
        id: map['id'] as int?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        temperature: (map['temperature'] as num).toDouble(),
        humidity: (map['humidity'] as num).toDouble(),
        pressure: (map['pressure'] as num?)?.toDouble() ?? 0.0,
        dewPoint: (map['dewPoint'] as num).toDouble(),
        outdoorTemperature: (map['outdoorTemperature'] as num?)?.toDouble() ?? 0.0,
        outdoorHumidity: (map['outdoorHumidity'] as num?)?.toDouble() ?? 0.0,
        outdoorPressure: (map['outdoorPressure'] as num?)?.toDouble() ?? 0.0,
        weather: map['weather'] as String,
        condensationRisk: map['condensationRisk'] as String? ?? 'SAFE',
        mode: map['mode'] as String,
        activeMode: map['activeMode'] as String? ?? 'COMFORT',
        fanStatus: map['fanStatus'] == 1,
        heaterStatus: map['heaterStatus'] == 1,
        dehumidifierStatus: map['dehumidifierStatus'] == 1,
        coolerStatus: (map['coolerStatus'] as int?) == 1,
        atomizerStatus: (map['atomizerStatus'] as int?) == 1,
      );
}

class CabinetData extends ChangeNotifier {
  double temperature = 0.0;
  double humidity = 0.0;
  double pressure = 1013.25;
  double outdoorTemperature = 0.0;
  double outdoorHumidity = 0.0;
  double outdoorPressure = 1013.25;
  String weather = 'CLEAR';
  String condensationRisk = 'SAFE';
  String requestedMode = 'AUTO';
  String activeMode = 'COMFORT';
  double targetTemp = 25.0;
  double targetHumidity = 60.0;
  bool sensorPresent = false;
  bool fanStatus = false;
  bool heaterStatus = false;
  bool dehumidifierStatus = false;
  bool coolerStatus = false;
  bool atomizerStatus = false;
  bool isConnected = false;

  // 用户手动覆盖标志：用户关闭自动模式后，轮询不再自动恢复
  bool userOverrideAutoMode = false;

  // 设备状态冷却期：防止APP控制后被旧数据覆盖
  final Map<String, DateTime> _cooldownFields = {};
  static const Duration _cooldownDuration = Duration(seconds: 30);

  AlertConfig alertConfig = AlertConfig();
  String? alertMessage;
  String? alertType;

  List<HistoryRecord> historyRecords = [];

  double get dewPoint {
    if (humidity <= 0.01 || temperature <= -50) return 0.0;
    const a = 17.62;
    const b = 243.12;
    if (temperature <= -b + 0.01) return 0.0;
    final alpha = log(humidity / 100.0) + (a * temperature) / (b + temperature);
    final dp = (b * alpha) / (a - alpha);
    return dp.isNaN || dp.isInfinite ? 0.0 : dp;
  }

  void updateConnectionStatus(bool connected) {
    isConnected = connected;
    // 不再重置userOverrideAutoMode：用户的手动模式设置应跨连接持久化
    // 只有用户主动开启自动模式时才会重置该标志（在control_page中处理）
    notifyListeners();
  }

  void updateAlertConfig(AlertConfig config) {
    alertConfig = config;
    _checkAlert();
    notifyListeners();
  }

  void _checkAlert() {
    final dp = dewPoint;
    final tempDiff = temperature - dp;

    if (condensationRisk == 'HIGH') {
      alertType = 'dew';
      alertMessage = '高结露风险！当前风险等级: HIGH';
    } else if (humidity > alertConfig.highHumidityThreshold && temperature < dp) {
      alertType = 'dew';
      alertMessage = '高结露风险！湿度 ${humidity.toStringAsFixed(1)}%，温度 ${temperature.toStringAsFixed(1)}°C，露点 ${dp.toStringAsFixed(1)}°C';
    } else if (temperature > alertConfig.highTempThreshold) {
      alertType = 'device';
      alertMessage = '设备温度过高！当前温度 ${temperature.toStringAsFixed(1)}°C，超过阈值 ${alertConfig.highTempThreshold}°C';
    } else if (humidity > alertConfig.maxHumidityThreshold) {
      alertType = 'device';
      alertMessage = '湿度过高！当前湿度 ${humidity.toStringAsFixed(1)}%，超过阈值 ${alertConfig.maxHumidityThreshold}%';
    } else if (tempDiff < alertConfig.dewPointDiffThreshold && humidity > 70) {
      alertType = 'dew';
      alertMessage = '结露风险！温度与露点差值 ${tempDiff.toStringAsFixed(1)}°C，湿度 ${humidity.toStringAsFixed(1)}%';
    } else {
      alertType = null;
      alertMessage = null;
    }
  }

  void clearAlert() {
    alertType = null;
    alertMessage = null;
    notifyListeners();
  }

  void setTargetTemp(double value) {
    targetTemp = value;
    notifyListeners();
  }

  void setTargetHumidity(double value) {
    targetHumidity = value;
    notifyListeners();
  }

  bool _batchUpdating = false;

  void beginBatchUpdate() => _batchUpdating = true;

  void endBatchUpdate() {
    _batchUpdating = false;
    checkAlerts();
    notifyDataChanged();
  }

  void notifyDataChanged() {
    if (_batchUpdating) return;
    notifyListeners();
  }

  /// 设置字段冷却期
  void setCooldown(String field) {
    _cooldownFields[field] = DateTime.now().add(_cooldownDuration);
  }

  /// 检查字段是否在冷却期内
  bool isInCooldown(String field) {
    final cooldownEnd = _cooldownFields[field];
    if (cooldownEnd == null) return false;
    if (DateTime.now().isAfter(cooldownEnd)) {
      _cooldownFields.remove(field);
      return false;
    }
    return true;
  }

  void checkAlerts() {
    _checkAlert();
  }

  void addHistory() {
    _addHistoryRecord();
  }

  Map<String, dynamic> _parsePayload(String payload) {
    final decoded = json.decode(payload);
    if (decoded is List && decoded.isNotEmpty) {
      final firstItem = decoded[0];
      if (firstItem is Map && firstItem.containsKey('values')) {
        return (firstItem['values'] as Map).map((k, v) => MapEntry(k.toString(), v));
      } else if (firstItem is Map) {
        return firstItem.map((k, v) => MapEntry(k.toString(), v));
      }
    } else if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }

  void updateTelemetryMetrics(String payload) {
    try {
      debugPrint('🔍 解析通道A - 环境核心指标...');
      final data = _parsePayload(payload);
      debugPrint('   原始数据: $data');

      if (data.isNotEmpty) {
        if (data.containsKey('temperature')) {
          temperature = _parseDouble(data['temperature']);
          debugPrint('   温度: $temperature°C');
        }
        if (data.containsKey('humidity')) {
          humidity = _parseDouble(data['humidity']);
          debugPrint('   湿度: $humidity%');
        }
        if (data.containsKey('pressure')) {
          pressure = _parseDouble(data['pressure']);
          debugPrint('   气压: $pressure hPa');
        }
        if (data.containsKey('dew_point')) {
          final externalDewPoint = _parseDouble(data['dew_point']);
          if (externalDewPoint > 0) {
            debugPrint('   外部露点: $externalDewPoint°C (内部计算: ${dewPoint.toStringAsFixed(1)}°C)');
          }
        }
        if (data.containsKey('outdoor_temperature')) {
          outdoorTemperature = _parseDouble(data['outdoor_temperature']);
          debugPrint('   户外温度: $outdoorTemperature°C');
        }
        if (data.containsKey('outdoor_humidity')) {
          outdoorHumidity = _parseDouble(data['outdoor_humidity']);
          debugPrint('   户外湿度: $outdoorHumidity%');
        }
        if (data.containsKey('outdoor_pressure')) {
          outdoorPressure = _parseDouble(data['outdoor_pressure']);
          debugPrint('   户外气压: $outdoorPressure hPa');
        }

        _checkAlert();
        _addHistoryRecord();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ 解析环境核心指标失败: $e');
      debugPrint('   原始 payload: $payload');
    }
  }

  void updateTelemetryStatus(String payload) {
    try {
      debugPrint('🔍 解析通道B - 设备运行状态...');
      final data = _parsePayload(payload);
      debugPrint('   原始数据: $data');

      if (data.isNotEmpty) {
        if (data.containsKey('weather')) {
          weather = (data['weather']?.toString() ?? 'CLEAR').toUpperCase();
          debugPrint('   天气模式: $weather');
        }
        if (data.containsKey('condensation_risk')) {
          condensationRisk = (data['condensation_risk']?.toString() ?? 'SAFE').toUpperCase();
          debugPrint('   结露风险: $condensationRisk');
        }
        if (data.containsKey('mode')) {
          requestedMode = (data['mode']?.toString() ?? 'AUTO').toUpperCase();
          debugPrint('   请求模式: $requestedMode');
        }
        if (data.containsKey('active_mode')) {
          activeMode = (data['active_mode']?.toString() ?? 'COMFORT').toUpperCase();
          debugPrint('   激活模式: $activeMode');
        }
        if (data.containsKey('target_temp')) {
          targetTemp = _parseDouble(data['target_temp']);
          debugPrint('   目标温度: $targetTemp°C');
        }
        if (data.containsKey('target_humidity')) {
          targetHumidity = _parseDouble(data['target_humidity']);
          debugPrint('   目标湿度: $targetHumidity%');
        }
        if (data.containsKey('sensor_present')) {
          sensorPresent = _parseBool(data['sensor_present']);
          debugPrint('   传感器状态: ${sensorPresent ? "在线" : "离线"}');
        }
        // 设备开关状态从ESP32上报的遥测数据读取
        if (data.containsKey('fan_on')) {
          fanStatus = _parseBool(data['fan_on']);
          debugPrint('   风扇状态: ${fanStatus ? "开启" : "关闭"}');
        }
        if (data.containsKey('heater_on')) {
          heaterStatus = _parseBool(data['heater_on']);
          debugPrint('   加热器状态: ${heaterStatus ? "开启" : "关闭"}');
        }
        if (data.containsKey('dehumidifier_on')) {
          dehumidifierStatus = _parseBool(data['dehumidifier_on']);
          debugPrint('   除湿器状态: ${dehumidifierStatus ? "开启" : "关闭"}');
        }
        if (data.containsKey('cooler_on')) {
          coolerStatus = _parseBool(data['cooler_on']);
          debugPrint('   制冷器状态: ${coolerStatus ? "开启" : "关闭"}');
        }
        if (data.containsKey('atomizer_on')) {
          atomizerStatus = _parseBool(data['atomizer_on']);
          debugPrint('   雾化器状态: ${atomizerStatus ? "开启" : "关闭"}');
        }

        _checkAlert();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ 解析设备运行状态失败: $e');
      debugPrint('   原始 payload: $payload');
    }
  }

  void updateSensorData(String payload) {
    try {
      debugPrint('🔍 解析传感器数据(兼容模式)...');
      final data = _parsePayload(payload);

      if (data.isNotEmpty) {
        if (data.containsKey('temperature') || data.containsKey('temp')) {
          updateTelemetryMetrics(payload);
        } else if (data.containsKey('weather') || data.containsKey('condensation_risk')) {
          updateTelemetryStatus(payload);
        } else {
          double newTemp = temperature;
          double newHum = humidity;

          newTemp = _extractTemperature(data);
          newHum = _extractHumidity(data);

          temperature = newTemp;
          humidity = newHum;
          _checkAlert();
          _addHistoryRecord();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ 解析传感器数据失败: $e');
    }
  }

  double _extractTemperature(Map<String, dynamic> data) {
    final keys = ['temp', 'temperature', 'T', 't', 'Temp'];
    for (final key in keys) {
      if (data.containsKey(key)) {
        return _parseDouble(data[key]);
      }
    }
    return temperature;
  }

  double _extractHumidity(Map<String, dynamic> data) {
    final keys = ['humi', 'humidity', 'H', 'h', 'Humi', 'RH'];
    for (final key in keys) {
      if (data.containsKey(key)) {
        return _parseDouble(data[key]);
      }
    }
    return humidity;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    return parsed ?? 0.0;
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final str = value.toString().toLowerCase().trim();
    return str == 'true' || str == '1';
  }

  void updateWeather(String payload) {
    weather = payload;
    notifyListeners();
  }

  void updateMode(String payload) {
    try {
      final data = _parsePayload(payload);
      if (data.isNotEmpty) {
        if (data.containsKey('mode')) {
          requestedMode = (data['mode']?.toString() ?? 'AUTO').toUpperCase();
        }
        if (data.containsKey('active_mode')) {
          activeMode = (data['active_mode']?.toString() ?? 'COMFORT').toUpperCase();
        }
      }
    } catch (e) {
      debugPrint('解析模式数据失败: $e');
    }
    notifyListeners();
  }

  void updateControlStatus(String payload) {
    try {
      final data = _parsePayload(payload);
      if (data.isNotEmpty) {
        // SHARED_SCOPE推送的是目标状态，不更新设备开关（实际状态由CLIENT_SCOPE/遥测决定）
        // 仅处理非设备状态字段
      }
      notifyListeners();
    } catch (e) {
      debugPrint('解析控制状态失败: $e');
    }
  }

  void _addHistoryRecord() {
    final record = HistoryRecord(
      timestamp: DateTime.now(),
      temperature: temperature,
      humidity: humidity,
      pressure: pressure,
      dewPoint: dewPoint,
      outdoorTemperature: outdoorTemperature,
      outdoorHumidity: outdoorHumidity,
      outdoorPressure: outdoorPressure,
      weather: weather,
      condensationRisk: condensationRisk,
      mode: requestedMode,
      activeMode: activeMode,
      fanStatus: fanStatus,
      heaterStatus: heaterStatus,
      dehumidifierStatus: dehumidifierStatus,
      coolerStatus: coolerStatus,
      atomizerStatus: atomizerStatus,
    );
    historyRecords.insert(0, record);
    if (historyRecords.length > 1000) {
      historyRecords = historyRecords.sublist(0, 1000);
    }
  }

  void addHistoryRecord(HistoryRecord record) {
    historyRecords.insert(0, record);
    if (historyRecords.length > 1000) {
      historyRecords = historyRecords.sublist(0, 1000);
    }
    notifyListeners();
  }

  void setHistoryRecords(List<HistoryRecord> records) {
    historyRecords = records;
    notifyListeners();
  }

  void removeHistoryRecord(int id) {
    historyRecords.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  void clearHistoryRecords() {
    historyRecords.clear();
    notifyListeners();
  }
}
