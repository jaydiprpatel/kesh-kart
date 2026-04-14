import '../../baas_options.dart';

class BaasConfig {
  /// Feature flag to switch between Firebase and Custom Backend
  static const bool useFirebase = false;


  /// REST API Base URL
  static String get restUrl => DefaultBaasOptions.apiUrl;

  /// WebSocket URL
  static String get wsUrl => DefaultBaasOptions.realtimeUrl;

  /// Timeout for requests
  static const Duration timeout = Duration(seconds: 10);
}
