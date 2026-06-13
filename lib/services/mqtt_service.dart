import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../utils/constants.dart';
import '../models/cabinet_data.dart';

class MqttService {
  MqttServerClient? _client;
  final CabinetData cabinetData;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  StreamSubscription? _messageSubscription;
  int _reconnectAttempts = 0;
  bool enabled = true;
  String lastError = '';
  String lastErrorDetail = '';

  bool get isConnected => _isConnected;

  MqttService(this.cabinetData);

  Future<void> connect() async {
    if (!enabled || _isConnecting) return;
    _isConnecting = true;
    try {
      await _disconnectInternal();

      for (final server in Constants.mqttServers) {
        final success = await _tryConnect(server);
        if (success) return;
      }

      lastError = '所有服务器都连接失败';
      lastErrorDetail = '尝试了以下服务器:\n${Constants.mqttServers.join("\n")}\n\n请检查:\n1. 手机网络连接\n2. ThingsBoard账号区域\n3. Token是否正确';
      _handleConnectionFailure();
    } finally {
      _isConnecting = false;
    }
  }

  Future<bool> _tryConnect(String server) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('尝试连接: $server:${Constants.mqttPort}');
    debugPrint('使用TCP直连模式');
    debugPrint('ClientID: ${Constants.clientId}');
    debugPrint('Username (Token): ${Constants.mqttUsername}');

    final client = MqttServerClient.withPort(
      server,
      Constants.clientId,
      Constants.mqttPort,
    );
    client.useWebSocket = false;
    client.secure = false;
    _client = client;

    client.logging(on: kDebugMode);
    client.keepAlivePeriod = 120;
    client.connectTimeoutPeriod = 10000;
    client.autoReconnect = true;
    client.onAutoReconnect = _onAutoReconnect;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.setProtocolV311();

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(Constants.clientId)
        .authenticateAs(Constants.mqttUsername, Constants.mqttPassword)
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();
    client.connectionMessage = connMessage;

    try {
      debugPrint('开始连接...');
      await client.connect(
        Constants.mqttUsername,
        Constants.mqttPassword,
      );
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        debugPrint('✅ 连接成功: $server');
        _subscribeTopics();
        return true;
      } else {
        final status = client.connectionStatus;
        debugPrint('❌ $server 连接被拒绝: ${status?.returnCode}');
        lastError = '连接被拒绝';
        lastErrorDetail = '服务器: $server\n返回码: ${status?.returnCode}\n\n可能原因:\n1. Token无效\n2. 设备已被删除\n3. 服务器配置错误';
        await _disconnectInternal();
        return false;
      }
    } on SocketException catch (e) {
      debugPrint('❌ $server 网络错误: $e');
      lastError = '网络错误';
      lastErrorDetail = '服务器: $server\n错误: $e\n\n请检查:\n1. 网络连接\n2. DNS解析\n3. 防火墙设置';
      await _disconnectInternal();
      return false;
    } on TlsException catch (e) {
      debugPrint('❌ $server SSL错误: $e');
      lastError = 'SSL错误';
      lastErrorDetail = '服务器: $server\n错误: $e\n\n请检查:\n1. 服务器SSL证书\n2. 端口是否正确';
      await _disconnectInternal();
      return false;
    } catch (e) {
      debugPrint('❌ $server 异常: ${e.runtimeType}: $e');
      lastError = '连接异常';
      lastErrorDetail = '服务器: $server\n错误类型: ${e.runtimeType}\n错误: $e';
      await _disconnectInternal();
      return false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    _reconnectAttempts = 0;
    cabinetData.updateConnectionStatus(true);
    _subscribeTopics();
    debugPrint('ThingsBoard MQTT 已连接');
  }

  void _onAutoReconnect() {
    debugPrint('ThingsBoard MQTT 自动重连中...');
    _isConnected = false;
    cabinetData.updateConnectionStatus(false);
  }

  void _onDisconnected() {
    final wasConnected = _isConnected;
    _isConnected = false;
    cabinetData.updateConnectionStatus(false);
    debugPrint('ThingsBoard MQTT 断开连接 (之前状态: ${wasConnected ? "已连接" : "未连接"})');
    if (wasConnected && enabled) {
      _scheduleReconnect();
    }
  }

  void _handleConnectionFailure() {
    _isConnected = false;
    cabinetData.updateConnectionStatus(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delay = _calculateBackoffDelay();
    debugPrint('${delay.inSeconds}秒后尝试重连... (第$_reconnectAttempts次)');
    _reconnectTimer = Timer(delay, () {
      if (enabled) connect();
    });
  }

  Duration _calculateBackoffDelay() {
    const baseDelay = Duration(seconds: 5);
    const maxDelay = Duration(seconds: 30);
    final delay = baseDelay * (_reconnectAttempts.clamp(1, 6));
    return delay > maxDelay ? maxDelay : delay;
  }

  Future<void> _disconnectInternal() async {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    if (_client != null) {
      try {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        _client!.onDisconnected = () {};
        if (_isConnected) {
          _client!.disconnect();
        }
      } catch (e) {
        debugPrint('断开旧连接时出错: $e');
      }
      _client = null;
    }
    _isConnected = false;
  }

  void _subscribeTopics() {
    if (_client == null) return;

    _messageSubscription?.cancel();
    _messageSubscription = null;

    // 订阅属性更新推送：ThingsBoard属性变化时实时推送给APP
    _client!.subscribe(Constants.topicAttributesSubscribe, MqttQos.atMostOnce);
    // 订阅RPC请求
    _client!.subscribe(Constants.topicRpcSubscribe, MqttQos.atMostOnce);
    // 订阅属性请求响应（用于主动获取最新属性）
    _client!.subscribe('v1/devices/me/attributes/response/+', MqttQos.atMostOnce);

    _messageSubscription = _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null || messages.isEmpty) return;
      for (final recMess in messages) {
        final pt = recMess.payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(pt.payload.message);
        debugPrint('═══════════════════════════════════════');
        debugPrint('📥 收到 MQTT 消息');
        debugPrint('   Topic: ${recMess.topic}');
        debugPrint('   Payload: $payload');
        debugPrint('═══════════════════════════════════════');

        if (recMess.topic.startsWith(Constants.topicRpcSubscribe.split('/+')[0])) {
          _handleRpcRequest(recMess.topic, payload);
        } else if (recMess.topic.startsWith('v1/devices/me/attributes/response/')) {
          _handleAttributeMessage(payload);
        } else {
          _handleAttributeMessage(payload);
        }
      }
    });

    // 连接后立即主动请求一次最新属性（CLIENT_SCOPE + SHARED_SCOPE）
    _requestAttributes();
  }

  /// 主动请求最新属性，确保连接后立即同步数据
  void _requestAttributes() {
    if (_client == null || !_isConnected) return;
    final requestId = DateTime.now().millisecondsSinceEpoch;
    final topic = 'v1/devices/me/attributes/request/$requestId';
    final payload = json.encode({
      'clientKeys': 'weather,condensation_risk,active_mode,sensor_present',
      'sharedKeys': 'mode,fan_on,heater_on,dehumidifier_on,cooler_on,atomizer_on,target_temp,target_humidity',
    });
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    debugPrint('📤 已发送属性请求: $topic');
  }

  void _handleAttributeMessage(String payload) {
    try {
      final data = json.decode(payload);
      if (data is Map) {
        final keys = data.keys.map((k) => k.toString()).toList();
        
        if (keys.contains('weather') || keys.contains('condensation_risk')) {
          cabinetData.updateTelemetryStatus(payload);
        } else if (keys.contains('mode') || keys.contains('active_mode')) {
          cabinetData.updateMode(payload);
        } else {
          cabinetData.updateControlStatus(payload);
        }
      }
    } catch (e) {
      debugPrint('❌ 解析属性数据失败: $e');
    }
  }

  void _handleRpcRequest(String topic, String payload) {
    try {
      debugPrint('🔧 收到 RPC 请求');
      final data = json.decode(payload);
      if (data is Map && data.containsKey('method')) {
        final method = data['method'] as String;
        final params = data['params'];
        final requestId = topic.split('/').last;

        debugPrint('   方法: $method');
        debugPrint('   参数: $params');
        debugPrint('   请求ID: $requestId');

        bool result = false;
        switch (method) {
          case Constants.rpcMethodSetFan:
            result = _handleSetFan(params);
            break;
          case Constants.rpcMethodSetHeater:
            result = _handleSetHeater(params);
            break;
          case Constants.rpcMethodSetDehum:
            result = _handleSetDehum(params);
            break;
          default:
            debugPrint('⚠️ 未知 RPC 方法: $method');
        }

        _sendRpcResponse(requestId, result);
      }
    } catch (e) {
      debugPrint('❌ 处理 RPC 请求失败: $e');
    }
  }

  bool _handleSetFan(dynamic params) {
    try {
      final value = _parseBool(params);
      cabinetData.fanStatus = value;
      cabinetData.notifyDataChanged();
      debugPrint('🔧 设置风扇: ${value ? '开启' : '关闭'}');
      return true;
    } catch (e) {
      debugPrint('❌ 设置风扇失败: $e');
      return false;
    }
  }

  bool _handleSetHeater(dynamic params) {
    try {
      final value = _parseBool(params);
      cabinetData.heaterStatus = value;
      cabinetData.notifyDataChanged();
      debugPrint('🔧 设置加热器: ${value ? '开启' : '关闭'}');
      return true;
    } catch (e) {
      debugPrint('❌ 设置加热器失败: $e');
      return false;
    }
  }

  bool _handleSetDehum(dynamic params) {
    try {
      final value = _parseBool(params);
      cabinetData.dehumidifierStatus = value;
      cabinetData.notifyDataChanged();
      debugPrint('🔧 设置除湿器: ${value ? '开启' : '关闭'}');
      return true;
    } catch (e) {
      debugPrint('❌ 设置除湿器失败: $e');
      return false;
    }
  }

  void _sendRpcResponse(String requestId, bool success) {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT 未连接，无法发送 RPC 响应');
      return;
    }
    
    final responseTopic = '${Constants.topicRpcResponsePrefix}$requestId';
    final builder = MqttClientPayloadBuilder();
    builder.addString('{"success": $success}');
    _client!.publishMessage(responseTopic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('📤 发送 RPC 响应: $responseTopic -> {"success": $success}');
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final str = value.toString().toLowerCase().trim();
    return str == 'true' || str == '1';
  }

  void publishControl(String device, bool isOn) {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT 未连接，无法发送控制指令');
      return;
    }
    final keyMap = {
      'fan': 'fan_on',
      'heater': 'heater_on',
      'dehumidifier': 'dehumidifier_on',
    };
    final key = keyMap[device] ?? device;
    final builder = MqttClientPayloadBuilder();
    builder.addString('{"$key": $isOn}');
    debugPrint('📤 发送控制指令: $key = $isOn');
    _client!.publishMessage(Constants.topicAttributes, MqttQos.atLeastOnce, builder.payload!);
  }

  void publishModeChange(String newMode) {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT 未连接，无法发送模式切换指令');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString('{"mode": "$newMode"}');
    debugPrint('📤 发送模式切换: mode = $newMode');
    _client!.publishMessage(Constants.topicAttributes, MqttQos.atLeastOnce, builder.payload!);
  }

  void publishTargetTemp(double temp) {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT 未连接，无法发送目标温度');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString('{"target_temp": $temp}');
    debugPrint('📤 发送目标温度: target_temp = $temp');
    _client!.publishMessage(Constants.topicAttributes, MqttQos.atLeastOnce, builder.payload!);
  }

  void publishTargetHumidity(double humidity) {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT 未连接，无法发送目标湿度');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString('{"target_humidity": $humidity}');
    debugPrint('📤 发送目标湿度: target_humidity = $humidity');
    _client!.publishMessage(Constants.topicAttributes, MqttQos.atLeastOnce, builder.payload!);
  }

  void publishAlertConfig(AlertConfig config) {
    if (!_isConnected || _client == null) {
      debugPrint('MQTT 未连接，无法发送报警配置');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(json.encode(config.toJson()));
    debugPrint('📤 发送报警配置: ${config.toJson()}');
    _client!.publishMessage(Constants.topicAttributes, MqttQos.atLeastOnce, builder.payload!);
  }

  void dispose() {
    enabled = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _messageSubscription?.cancel();
    _messageSubscription = null;
    if (_client != null) {
      try {
        _client!.onDisconnected = () {};
        if (_isConnected) {
          _client!.disconnect();
        }
      } catch (e) {
        debugPrint('dispose时出错: $e');
      }
      _client = null;
    }
  }
}
