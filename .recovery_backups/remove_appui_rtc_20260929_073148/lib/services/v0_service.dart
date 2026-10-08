// lib/services/v0_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:calculateur_etranger/security/native_secure_assets.dart';
import 'secure_asset_resolver.dart';

class V0Service {
  final SystemeArme systeme;

  V0Service({this.systeme = SystemeArme.caesar});

  static final Map<SystemeArme, Map<String, Map<String, double>>> _caches =
      <SystemeArme, Map<String, Map<String, double>>>{};

  bool get isLoaded => _caches.containsKey(systeme);

  String get _encryptedPath {
    switch (systeme) {
      case SystemeArme.caesar:
        return 'assets/secure_enc/config/v0.cfg.gz.enc';

      case SystemeArme.mo:
        return 'assets/secure_enc/config/MO/v0.cfg.gz.enc';

      case SystemeArme.mepac:
        return 'assets/secure_enc/config/MEPAC/v0.cfg.gz.enc';
    }
  }

  String _canonType(String s) {
    final x = s
        .trim()
        .toLowerCase()
        .replaceAll('é', 'e')
        .replaceAll('-', '_')
        .replaceAll(' ', '');

    final isAll = x.endsWith('_all');
    final base = isAll ? x.substring(0, x.length - 4) : x;

    final canonicalBase = switch (base) {
      'appui' ||
      'oef5' ||
      'oe' ||
      'oex' ||
      'ofum' ||
      'mo_appui' ||
      'mepac_appui' =>
        'APPUI',
      'appuirtc' ||
      'oef5rtc' ||
      'oef2rtc' ||
      'oef2rtc_all' ||
      'oef5rtc_all' ||
      'mo_appuirtc' ||
      'mepac_appuirtc' =>
        'APPUIRTC',
      'eclairant' || 'oecl' || 'mo_oecl' || 'mepac_oecl' => 'OECL',
      _ => s.trim().toUpperCase().replaceAll('-', '_').replaceAll(' ', ''),
    };

    if (systeme != SystemeArme.caesar) {
      return canonicalBase;
    }

    return isAll ? '${canonicalBase}_ALL' : canonicalBase;
  }

  String _canonCharge(String s) {
    final raw = s.trim();

    final x = raw
        .toUpperCase()
        .replaceAll('CHARGE.', '')
        .replaceAll('CH', '')
        .replaceAll(',', '.')
        .replaceAll('_', '.')
        .trim();

    final value = double.tryParse(x);

    if (value == null) {
      return raw.toUpperCase();
    }

    if ((value - value.roundToDouble()).abs() < 0.0001) {
      return 'CH${value.round()}';
    }

    return 'CH${value.floor()}_5';
  }

  Future<void> load() async {
    if (_caches.containsKey(systeme)) return;

    Uint8List compressed;

    try {
      compressed = await NativeSecureAssets.decryptAsset(_encryptedPath);
    } catch (e) {
      throw StateError('[SECURE] AES V0 decrypt failed $_encryptedPath : $e');
    }

    final raw = utf8.decode(gzip.decode(compressed));
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('[V0] config root invalide');
    }

    final parsed = <String, Map<String, double>>{};

    for (final typeEntry in decoded.entries) {
      final rawKey = typeEntry.key.toString();

      // Métadonnées autorisées dans les configs MO/MEPAC.
      if (rawKey.startsWith('_') ||
          rawKey == 'meta' ||
          rawKey == 'notes' ||
          rawKey == 'systeme' ||
          rawKey == 'version') {
        continue;
      }

      final type = _canonType(rawKey);

      final chargesRaw = typeEntry.value;
      if (chargesRaw is! Map) {
        throw FormatException('[V0] charges invalides pour $type');
      }

      final charges = parsed.putIfAbsent(type, () => <String, double>{});

      for (final chargeEntry in chargesRaw.entries) {
        final charge = _canonCharge(chargeEntry.key.toString());
        final valueRaw = chargeEntry.value;

        final value = valueRaw is num
            ? valueRaw.toDouble()
            : double.tryParse(valueRaw.toString().replaceAll(',', '.'));

        if (value == null) {
          throw FormatException('[V0] valeur invalide $type/$charge');
        }

        charges[charge] = value;
      }
    }

    _caches[systeme] = parsed;

    if (kDebugMode) {
      debugPrint(
        '[V0] config sécurisée chargée systeme=$systeme path=$_encryptedPath',
      );
    }
  }

  Future<double?> v0Ref({
    required String typeTirAssets,
    required String charge,
  }) async {
    await load();

    final type = _canonType(typeTirAssets);
    final ch = _canonCharge(charge);

    final value = _caches[systeme]?[type]?[ch];

    // Les familles CAESAR standard et CAESAR ALL possèdent des références
    // distinctes dans v0.cfg. Aucun repli APPUI_ALL -> APPUI ou
    // APPUIRTC_ALL -> APPUIRTC ne doit être appliqué.
    if (kDebugMode) {
      debugPrint('[V0] systeme=$systeme type=$type charge=$ch -> v0=$value');

      if (value == null) {
        final typesDisponibles =
            _caches[systeme]?.keys.toList() ?? const <String>[];
        final chargesDisponibles =
            _caches[systeme]?[type]?.keys.toList() ?? const <String>[];

        debugPrint(
          '[V0] référence absente '
          'systeme=$systeme type=$type charge=$ch '
          'typesDisponibles=$typesDisponibles '
          'chargesDisponibles=$chargesDisponibles',
        );
      }
    }

    return value;
  }

  static void clearCaches() {
    _caches.clear();
  }
}
