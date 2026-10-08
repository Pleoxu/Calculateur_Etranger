import 'package:flutter/services.dart';

class NativeSecureAssets {
  static const MethodChannel _channel = MethodChannel('secure_assets');

  static Future<Uint8List> decryptAsset(String assetPath) async {
    final result = await _channel.invokeMethod<Uint8List>('decryptAsset', {
      'path': assetPath,
    });

    if (result == null) {
      throw Exception('decryptAsset returned null');
    }

    return result;
  }

  static Future<bool> verifyRuntime() async {
    final result = await _channel.invokeMethod<bool>('verifyRuntime');

    return result ?? false;
  }
}
