import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calculateur_etranger/core/secure_assets/secure_asset_loader.dart';

import 'presentation/fire/pages/ecran_tir_complet.dart';
import 'presentation/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Future.microtask(() async {
    try {
      await SecureAssetLoader().testNativeEncryptedAsset();
    } catch (e, st) {
      debugPrint('[SECURE_TEST][ERROR] $e');
      if (kDebugMode) {
        debugPrint('$st');
      }
    }
  });

  runApp(const ProviderScope(child: CalculateurTirApp()));
}

class CalculateurTirApp extends StatelessWidget {
  const CalculateurTirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fire Calculator',
      debugShowCheckedModeBanner: false,

      // Design system global.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      home: const EcranTirComplet(),
    );
  }
}
