import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'native_security_bridge.dart';

class SecurityService {
  static const MethodChannel _channel = MethodChannel('security_channel');

  Future<void> verifyExecutionAllowed() async {
    if (kDebugMode) {
      return;
    }

    final compromised = await NativeSecurityBridge.isEnvironmentCompromised();

    if (compromised) {
      throw Exception('Environment not trusted');
    }
  }

  Future<bool> checkSecurity() async {
    final compromised = await _channel.invokeMethod<bool>('checkSecurity');

    return compromised ?? false;
  }
}
