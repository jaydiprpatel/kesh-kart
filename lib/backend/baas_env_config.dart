import 'package:flutter/foundation.dart';

enum BaasEnvironment { dev, prod }

class BaasEnvConfig {
  final BaasEnvironment environment;
  final String apiUrl;
  final String realtimeUrl;
  final String androidProjectKey;

  BaasEnvConfig({
    required this.environment,
    required this.apiUrl,
    required this.realtimeUrl,
    required this.androidProjectKey,
  });

  static BaasEnvConfig get current {
    if (kReleaseMode) {
      return prod;
    }
    return dev;
  }

  static final BaasEnvConfig dev = BaasEnvConfig(
    environment: BaasEnvironment.dev,
    apiUrl: 'https://api.dvsptech.com',
    realtimeUrl: 'wss://api.dvsptech.com/ws/',
    androidProjectKey: 'pk_dev_15cff12b887b469c',
  );

  static final BaasEnvConfig prod = BaasEnvConfig(
    environment: BaasEnvironment.prod,
    // Typically these would be HTTPS/WSS in production
    apiUrl: 'https://api.dvsptech.com', 
    realtimeUrl: 'wss://api.dvsptech.com/ws/',
    androidProjectKey: 'pk_prod_xxxxxxxxxxxx', 
  );
}
