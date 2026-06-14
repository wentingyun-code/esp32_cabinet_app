import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/cabinet_data.dart';

class ThingsBoardService {
  final CabinetData cabinetData;
  String? _jwtToken;
  Timer? _pollTimer;
  Timer? _refreshTokenTimer;
  bool _isConnected = false;
  bool _isConnecting = false;
  String lastError = '';
  String lastErrorDetail = '';
  bool enabled = true;
  int _reconnectAttempts = 0;
  int _consecutiveFailures = 0; // 连续失败计数，用于降低轮询频率


  bool get isConnected => _isConnected;

  ThingsBoardService(this.cabinetData);

  Future<bool> connect() async {
    return login();
  }

  Future<bool> login() async {
    if (_isConnecting) return false;
    _isConnecting = true;

    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔑 登录 ThingsBoard REST API...');
      debugPrint('   服务器: ${Constants.tbServerUrl}');
      debugPrint('   用户: ${Constants.tbUsername}');
      debugPrint('   设备ID: ${Constants.deviceId}');

      final response = await http.post(
        Uri.parse('${Constants.tbServerUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': Constants.tbUsername,
          'password': Constants.tbPassword,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _jwtToken = data['token'];
        _isConnected = true;
        _reconnectAttempts = 0;
        lastError = '';
        lastErrorDetail = '';
        cabinetData.updateConnectionStatus(true);
        debugPrint('✅ 登录成功！JWT Token 已获取');
        _startPolling();
        _startTokenRefresh();
        return true;
      } else {
        lastError = '登录失败 (${response.statusCode})';
        lastErrorDetail = '服务器返回: ${response.body}';
        debugPrint('❌ 登录失败: ${response.statusCode} - ${response.body}');
        _handleConnectionFailure();
        return false;
      }
    } catch (e) {
      lastError = '连接失败';
      lastErrorDetail = e.toString();
      debugPrint('❌ 连接异常: $e');
      _handleConnectionFailure();
      return false;
    } finally {
      _isConnecting = false;
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: Constants.pollIntervalSeconds), (_) {
      _fetchData();
    });
    _fetchData();
  }

  void _startTokenRefresh() {
    _refreshTokenTimer?.cancel();
    _refreshTokenTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      login();
    });
  }

  Future<void> _fetchData() async {
    if (_jwtToken == null || !enabled) return;

    // 连续失败时降低轮询频率：3次失败→10秒间隔，5次失败→30秒间隔
    if (_consecutiveFailures >= 5) {
      await Future.delayed(const Duration(seconds: 27)); // 3秒间隔+27秒=30秒
    } else if (_consecutiveFailures >= 3) {
      await Future.delayed(const Duration(seconds: 7)); // 3秒间隔+7秒=10秒
    }

    try {
      cabinetData.beginBatchUpdate();
      // 并行请求三个数据源，提升响应速度
      await Future.wait([
        _fetchSharedAttributes(),
        _fetchClientAttributes(),
        _fetchTelemetry(),
      ]);
    } catch (e) {
      debugPrint('❌ 数据拉取失败: $e');
    } finally {
      cabinetData.endBatchUpdate();
    }
  }

  Future<void> _fetchTelemetry() async {
    try {
      final uri = Uri.parse(
        '${Constants.tbServerUrl}/api/plugins/telemetry/DEVICE/${Constants.deviceId}/values/timeseries'
        '?keys=${Constants.telemetryKeys.join(",")}',
      );

      final response = await http.get(
        uri,
        headers: {'X-Authorization': 'Bearer $_jwtToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _consecutiveFailures = 0;
        final data = json.decode(response.body) as Map<String, dynamic>;
        _processTelemetryData(data);
      } else if (response.statusCode == 401) {
        debugPrint('🔑 Token 过期，重新登录...');
        await login();
      } else {
        _consecutiveFailures++;
        debugPrint('⚠️ 获取遥测数据失败: ${response.statusCode}');
      }
    } catch (e) {
      _consecutiveFailures++;
      debugPrint('❌ 获取遥测数据异常: $e (连续失败: $_consecutiveFailures次)');
    }
  }

  void _processTelemetryData(Map<String, dynamic> data) {
    bool updated = false;

    for (final entry in data.entries) {
      final key = entry.key;
      final values = entry.value as List;
      if (values.isEmpty) continue;

      final latestValue = (values[0] as Map)['value'];

      switch (key) {
        case 'temperature':
          cabinetData.temperature = _parseDouble(latestValue);
          updated = true;
          break;
        case 'humidity':
          cabinetData.humidity = _parseDouble(latestValue);
          updated = true;
          break;
        case 'pressure':
          cabinetData.pressure = _parseDouble(latestValue);
          updated = true;
          break;
        case 'outdoor_temperature':
          cabinetData.outdoorTemperature = _parseDouble(latestValue);
          updated = true;
          break;
        case 'outdoor_humidity':
          cabinetData.outdoorHumidity = _parseDouble(latestValue);
          updated = true;
          break;
        case 'dew_point':
          // dewPoint 是根据 temperature 和 humidity 计算得出的 getter，不可赋值
          debugPrint('   遥测 dew_point: ${_parseDouble(latestValue)}°C (内部计算: ${cabinetData.dewPoint.toStringAsFixed(1)}°C)');
          break;
        case 'in_comfort_zone':
          cabinetData.inComfortZone = _parseBool(latestValue);
          updated = true;
          break;
        case 'current_weather':
          cabinetData.currentWeather = (latestValue?.toString() ?? 'CLEAR').toUpperCase();
          updated = true;
          break;
        case 'simulated_weather':
          cabinetData.simulatedWeather = (latestValue?.toString() ?? 'CLEAR').toUpperCase();
          updated = true;
          break;
        case 'condensation_risk':
          cabinetData.condensationRisk = (latestValue?.toString() ?? 'SAFE').toUpperCase();
          updated = true;
          break;
        case 'active_mode':
          cabinetData.activeMode = (latestValue?.toString() ?? 'COMFORT').toUpperCase();
          updated = true;
          break;
        case 'fan_on':
          cabinetData.fanStatus = _parseBool(latestValue);
          updated = true;
          break;
        case 'heater_on':
          cabinetData.heaterStatus = _parseBool(latestValue);
          updated = true;
          break;
        case 'dehumidifier_on':
          cabinetData.dehumidifierStatus = _parseBool(latestValue);
          updated = true;
          break;
        case 'cooler_on':
          cabinetData.coolerStatus = _parseBool(latestValue);
          updated = true;
          break;
        case 'atomizer_on':
          cabinetData.atomizerStatus = _parseBool(latestValue);
          updated = true;
          break;
      }
    }

    if (updated) {
      cabinetData.checkAlerts();
      cabinetData.addHistory();
      cabinetData.notifyDataChanged();
      debugPrint('📊 遥测数据已更新');
    }
  }

  /// CLIENT_SCOPE属性：ESP32通过MQTT上报的设备状态（只读）
  static const List<String> _clientAttributeKeys = [
    'current_weather', 'in_comfort_zone', 'simulated_weather', 'condensation_risk', 'active_mode', 'sensor_present',
    'fan_on', 'heater_on', 'dehumidifier_on', 'cooler_on', 'atomizer_on',
  ];

  /// SHARED_SCOPE属性：APP下发的控制命令（可读写，ESP32可订阅接收）
  static const List<String> _sharedAttributeKeys = [
    'fan_on', 'heater_on', 'dehumidifier_on', 'cooler_on', 'atomizer_on',
    'mode', 'target_temp', 'target_humidity', 'simulated_weather',
  ];

  Future<void> _fetchClientAttributes() async {
    try {
      final uri = Uri.parse(
        '${Constants.tbServerUrl}/api/plugins/telemetry/DEVICE/${Constants.deviceId}/values/attributes/CLIENT_SCOPE'
        '?keys=${_clientAttributeKeys.join(",")}',
      );

      final response = await http.get(
        uri,
        headers: {'X-Authorization': 'Bearer $_jwtToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _consecutiveFailures = 0;
        final data = json.decode(response.body) as List;
        _processClientAttributes(data);
      } else if (response.statusCode == 401) {
        await login();
      } else {
        _consecutiveFailures++;
        debugPrint('⚠️ 获取CLIENT_SCOPE属性失败: ${response.statusCode}');
      }
    } catch (e) {
      _consecutiveFailures++;
      debugPrint('❌ 获取CLIENT_SCOPE属性异常: $e (连续失败: $_consecutiveFailures次)');
    }
  }

  Future<void> _fetchSharedAttributes() async {
    try {
      final uri = Uri.parse(
        '${Constants.tbServerUrl}/api/plugins/telemetry/DEVICE/${Constants.deviceId}/values/attributes/SHARED_SCOPE'
        '?keys=${_sharedAttributeKeys.join(",")}',
      );

      final response = await http.get(
        uri,
        headers: {'X-Authorization': 'Bearer $_jwtToken'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _consecutiveFailures = 0;
        final data = json.decode(response.body) as List;
        _processSharedAttributes(data);
      } else if (response.statusCode == 401) {
        await login();
      } else {
        _consecutiveFailures++;
        debugPrint('⚠️ 获取SHARED_SCOPE属性失败: ${response.statusCode}');
      }
    } catch (e) {
      _consecutiveFailures++;
      debugPrint('❌ 获取SHARED_SCOPE属性异常: $e (连续失败: $_consecutiveFailures次)');
    }
  }

  /// 处理CLIENT_SCOPE属性（ESP32上报，APP只读）
  void _processClientAttributes(List data) {
    bool updated = false;

    for (final item in data) {
      if (item is! Map) continue;
      final key = item['key']?.toString();
      final value = item['value'];

      switch (key) {
        case 'in_comfort_zone':
          cabinetData.inComfortZone = _parseBool(value);
          updated = true;
          break;
        case 'current_weather':
          cabinetData.currentWeather = (value?.toString() ?? 'CLEAR').toUpperCase();
          updated = true;
          break;
        case 'simulated_weather':
          cabinetData.simulatedWeather = (value?.toString() ?? 'CLEAR').toUpperCase();
          updated = true;
          break;
        case 'condensation_risk':
          cabinetData.condensationRisk = (value?.toString() ?? 'SAFE').toUpperCase();
          updated = true;
          break;
        case 'active_mode':
          cabinetData.activeMode = (value?.toString() ?? 'COMFORT').toUpperCase();
          updated = true;
          break;
        case 'sensor_present':
          cabinetData.sensorPresent = _parseBool(value);
          updated = true;
          break;
        case 'fan_on':
          cabinetData.fanStatus = _parseBool(value);
          updated = true;
          break;
        case 'heater_on':
          cabinetData.heaterStatus = _parseBool(value);
          updated = true;
          break;
        case 'dehumidifier_on':
          cabinetData.dehumidifierStatus = _parseBool(value);
          updated = true;
          break;
        case 'cooler_on':
          cabinetData.coolerStatus = _parseBool(value);
          updated = true;
          break;
        case 'atomizer_on':
          cabinetData.atomizerStatus = _parseBool(value);
          updated = true;
          break;
      }
    }

    if (updated) {
      cabinetData.checkAlerts();
      cabinetData.notifyDataChanged();
      debugPrint('📋 CLIENT_SCOPE属性已更新 (设备状态)');
    }
  }

  /// 处理SHARED_SCOPE属性（APP下发的控制命令）
  /// SHARED_SCOPE是「目标状态」，设备状态应从CLIENT_SCOPE/遥测（实际状态）读取
  /// 因此这里只处理 mode/target 等控制字段，不更新设备开关状态
  void _processSharedAttributes(List data) {
    bool updated = false;

    for (final item in data) {
      if (item is! Map) continue;
      final key = item['key']?.toString();
      final value = item['value'];

      // 冷却期内的字段跳过
      if (cabinetData.isInCooldown(key ?? '')) {
        debugPrint('   ⏳ $key 在冷却期内，跳过更新 (SHARED_SCOPE)');
        continue;
      }

      switch (key) {
        // 设备开关状态不从此处读取，由CLIENT_SCOPE/遥测决定实际状态
        case 'fan_on':
        case 'heater_on':
        case 'dehumidifier_on':
        case 'cooler_on':
        case 'atomizer_on':
          break;
        case 'mode':
          cabinetData.requestedMode = (value?.toString() ?? 'AUTO').toUpperCase();
          // 同步更新userOverrideAutoMode
          cabinetData.userOverrideAutoMode = (cabinetData.requestedMode == 'MANUAL');
          updated = true;
          break;
        case 'target_temp':
          cabinetData.targetTemp = _parseDouble(value);
          updated = true;
          break;
        case 'target_humidity':
          cabinetData.targetHumidity = _parseDouble(value);
          updated = true;
          break;
        case 'simulated_weather':
          cabinetData.simulatedWeather = (value?.toString() ?? 'CLEAR').toUpperCase();
          updated = true;
          break;
      }
    }

    if (updated) {
      cabinetData.checkAlerts();
      cabinetData.notifyDataChanged();
      debugPrint('📋 SHARED_SCOPE属性已更新 (控制状态)');
    }
  }

  Future<bool> sendRpcCommand(String method, Map<String, dynamic> params) async {
    if (_jwtToken == null) return false;

    try {
      // 使用oneway RPC，不需要设备回复，避免超时
      final response = await http.post(
        Uri.parse('${Constants.tbServerUrl}/api/plugins/rpc/oneway/${Constants.deviceId}'),
        headers: {
          'X-Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'method': method,
          'params': params,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ RPC命令已发送: $method');
        return true;
      } else {
        debugPrint('❌ RPC命令失败: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ RPC命令异常: $e');
      return false;
    }
  }

  /// 直接更新ThingsBoard设备属性到SHARED_SCOPE
  /// SHARED_SCOPE的属性变更会被ESP32通过MQTT订阅(v1/devices/me/attributes)接收到
  Future<bool> _updateDeviceAttributes(Map<String, dynamic> attrs) async {
    if (_jwtToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('${Constants.tbServerUrl}/api/plugins/telemetry/DEVICE/${Constants.deviceId}/attributes/SHARED_SCOPE'),
        headers: {
          'X-Authorization': 'Bearer $_jwtToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(attrs),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        debugPrint('✅ 属性已更新到SHARED_SCOPE: $attrs');
        return true;
      } else {
        debugPrint('⚠️ SHARED_SCOPE属性更新失败: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ SHARED_SCOPE属性更新异常: $e');
      return false;
    }
  }

  Future<bool> publishModeChange(String mode) async {
    cabinetData.setCooldown('mode');
    // 先更新属性（确保ThingsBoard端可见），再异步发送RPC（不阻塞）
    _updateDeviceAttributes({'mode': mode});
    sendRpcCommand('setMode', {'mode': mode}); // 不await，异步发送
    return true;
  }

  Future<bool> publishControl(String device, bool state) async {
    switch (device) {
      case 'fan':
        cabinetData.setCooldown('fan_on');
        _updateDeviceAttributes({'fan_on': state});
        sendRpcCommand('setFan', {'enabled': state}); // 不await
        return true;
      case 'heater':
        cabinetData.setCooldown('heater_on');
        _updateDeviceAttributes({'heater_on': state});
        sendRpcCommand('setHeater', {'enabled': state}); // 不await
        return true;
      case 'dehumidifier':
        cabinetData.setCooldown('dehumidifier_on');
        _updateDeviceAttributes({'dehumidifier_on': state});
        sendRpcCommand('setDehum', {'enabled': state}); // 不await
        return true;
      case 'cooler':
        cabinetData.setCooldown('cooler_on');
        _updateDeviceAttributes({'cooler_on': state});
        sendRpcCommand('setCooler', {'enabled': state}); // 不await
        return true;
      case 'atomizer':
        cabinetData.setCooldown('atomizer_on');
        _updateDeviceAttributes({'atomizer_on': state});
        sendRpcCommand('setAtomizer', {'enabled': state}); // 不await
        return true;
      default:
        return false;
    }
  }

  Future<bool> publishTargetTemp(double temp) async {
    cabinetData.setCooldown('target_temp');
    _updateDeviceAttributes({'target_temp': temp});
    sendRpcCommand('setTargetTemp', {'temperature': temp}); // 不await
    return true;
  }

  Future<bool> publishTargetHumidity(double humidity) async {
    cabinetData.setCooldown('target_humidity');
    _updateDeviceAttributes({'target_humidity': humidity});
    sendRpcCommand('setTargetHumidity', {'humidity': humidity}); // 不await
    return true;
  }

  Future<bool> publishAlertConfig(Map<String, dynamic> config) async {
    return sendRpcCommand('setAlertConfig', config);
  }

  void _handleConnectionFailure() {
    _isConnected = false;
    cabinetData.updateConnectionStatus(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectAttempts++;
    final delay = Duration(seconds: (_reconnectAttempts * 5).clamp(5, 30));
    debugPrint('${delay.inSeconds}秒后尝试重连... (第$_reconnectAttempts次)');
    Timer(delay, () {
      if (enabled) login();
    });
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

  void dispose() {
    enabled = false;
    _pollTimer?.cancel();
    _refreshTokenTimer?.cancel();
  }
}
