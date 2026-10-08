import 'package:flutter/services.dart';

class NativeSecurityBridge {
  static const _channel = MethodChannel('native_security');

  static Future<bool> isEnvironmentCompromised() async {
    try {
      final result = await _channel.invokeMethod<bool>('checkSecurity');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }
}
