class Constants {
  // ThingsBoard REST API 配置
  static const String tbServerUrl = 'http://10.16.157.170:9090';
  static const String deviceId = 'f98a74d0-5c91-11f1-8d22-8379b3ee6be3';

  // ThingsBoard 登录凭据 (租户管理员)
  static const String tbUsername = 'tenant@thingsboard.org';
  static const String tbPassword = 'tenant';

  // 数据轮询间隔 (秒)
  static const int pollIntervalSeconds = 3;

  // 遥测数据字段 (timeseries)
  static const List<String> telemetryKeys = [
    'temperature',
    'humidity',
    'pressure',
    'outdoor_temperature',
    'outdoor_humidity',
    'outdoor_pressure',
    'dew_point',
  ];

  // 属性数据字段 (attributes)
  static const List<String> attributeKeys = [
    'weather',
    'condensation_risk',
    'requested_mode',
    'active_mode',
    'target_temp',
    'target_humidity',
    'sensor_present',
    'fan_on',
    'heater_on',
    'dehumidifier_on',
  ];

  // RPC 方法名
  static const String rpcMethodSetFan = 'setFan';
  static const String rpcMethodSetHeater = 'setHeater';
  static const String rpcMethodSetDehum = 'setDehum';

  // 以下为旧MQTT配置，保留兼容
  static const List<String> mqttServers = [
    '10.16.157.170',
  ];
  static const int mqttPort = 1883;
  static const String mqttUsername = 'f98a74d0-5c91-11f1-8d22-8379b3ee6be3';
  static const String mqttPassword = '';
  static String get clientId => 'flutter_app_${DateTime.now().millisecondsSinceEpoch}';

  static const String topicTelemetry = 'v1/devices/me/telemetry';
  static const String topicAttributes = 'v1/devices/me/attributes';
  static const String topicAttributesSubscribe = 'v1/devices/me/attributes';
  static const String topicRpcSubscribe = 'v1/devices/me/rpc/request/+';
  static const String topicRpcResponsePrefix = 'v1/devices/me/rpc/response/';
  static const String topicSensorData = 'v1/devices/me/telemetry';
  static const String topicWeather = 'v1/devices/me/telemetry';
  static const String topicMode = 'v1/devices/me/attributes';
  static const String topicControl = 'v1/devices/me/attributes';
}
