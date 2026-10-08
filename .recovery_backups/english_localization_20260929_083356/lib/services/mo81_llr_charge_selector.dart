// lib/services/mo81_llr_charge_selector.dart
//
// Sélection automatique de charge MO81 LLR à partir des T2 disponibles.
//
// Règle de sélection :
// 1) privilégier la charge la plus faible dont la hausse T2, à la distance
//    topographique, est comprise entre 1000 et 1100 mil ;
// 2) sinon retenir la solution dont la hausse est la plus proche de cette bande ;
// 3) ignorer une charge dont le T2 n'existe pas encore dans les assets ;
// 4) déclarer le tir hors portée si aucune charge ne possède de solution T2.

import 'package:flutter/foundation.dart';
import 'package:calculateur_etranger/models/calcul_data.dart';

import 'tableau_f_service.dart';
import 'tableau_ecl_service.dart';

@immutable
class Mo81LlrChargeChoice {
  final String charge;
  final double hausseMil;

  const Mo81LlrChargeChoice({required this.charge, required this.hausseMil});
}

@immutable
class _Mo81LlrMunitionConfig {
  final String variant;
  final List<String> charges;

  /// Certaines tables historiques ont été générées sans suffixe _CHx.
  /// La map indique, pour une charge donnée, un nom de fichier alternatif.
  final Map<String, String> legacyTableIds;

  /// Si false, aucune charge n'est proposée lorsque la bande de sélection
  /// n'est satisfaite. Cela évite d'afficher une charge de repli artificielle.
  final bool allowNearestFallback;

  const _Mo81LlrMunitionConfig({
    required this.variant,
    required this.charges,
    this.legacyTableIds = const <String, String>{},
    this.allowNearestFallback = true,
  });
}

class Mo81LlrChargeSelector {
  const Mo81LlrChargeSelector._();

  static _Mo81LlrMunitionConfig _configForMunition(TypeMunition munition) {
    switch (munition) {
      case TypeMunition.oe81F2:
        return const _Mo81LlrMunitionConfig(
          variant: 'MO81_LLR_OE_81_F2',
          charges: <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6'],
        );

      case TypeMunition.oecl81F1:
        return const _Mo81LlrMunitionConfig(
          variant: 'MO81_LLR_OECL_81_F1',
          charges: <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5', 'CH6'],
        );

      case TypeMunition.oecl81F3:
        return const _Mo81LlrMunitionConfig(
          variant: 'MO81_LLR_OECL_81_F3',
          charges: <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5'],
          // Le T2 F3 actuellement généré dans le projet correspond à CH3
          // mais porte encore l'identifiant sans suffixe _CH3.
          legacyTableIds: <String, String>{'CH3': 'MO81_LLR_OECL_81_F3_T2'},
        );

      case TypeMunition.oeclIr81F2:
        return const _Mo81LlrMunitionConfig(
          variant: 'MO81_LLR_OECL_IR_81_F2',
          charges: <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5'],
          allowNearestFallback: false,
        );

      default:
        throw StateError(
          'Sélection automatique de charge MO81 LLR non configurée '
          'pour $munition.',
        );
    }
  }

  /// Sélection doctrinale spécifique à l’OECL IR F2.
  ///
  /// Les tables ECL donnent directement l’AE au début d’éclairement. Elles
  /// sont donc la référence de charge à utiliser pour le tir similaire aussi,
  /// afin que sa V0 de référence corresponde à la charge finale.
  static Future<Mo81LlrChargeChoice> _selectIrF2FromEcl({
    required double distanceM,
    required bool verbose,
  }) async {
    const variant = 'MO81_LLR_OECL_IR_81_F2';
    const charges = <String>['CH1', 'CH2', 'CH3', 'CH4', 'CH5'];
    final candidates = <Mo81LlrChargeChoice>[];

    for (final charge in charges) {
      final service = TableauEclService(
        // Le variant de fichier reste MO81_LLR_OECL_IR_81_F2, mais le
        // lecteur ECL attend son type canonique et le résout en OECL_ART392.
        typeTir: 'OECL',
        charge: charge,
        // Les tables IR F2 validées pour le calcul principal sont lues sur
        // cette branche ; aucun changement de convention n’est appliqué ici.
        tirMontagne: false,
        allowBranchFallback: true,
        verbose: verbose,
        encryptedPathOverride: 'assets/secure_enc/tableaux/MO81_LLR/ECL/'
            '${variant}_ECL_$charge.ecltbl.gz.enc',
      );

      try {
        // hausseMil() borne les lectures historiques hors table. La sélection
        // de charge, elle, doit rejeter strictement une charge hors domaine.
        if (!await service.couvrePortee(distanceM: distanceM)) {
          if (verbose || kDebugMode) {
            debugPrint(
              '[MO81 LLR CHARGE] ECL $variant '
              'D=${distanceM.toStringAsFixed(1)} $charge hors domaine',
            );
          }
          continue;
        }

        final hausse = await service.hausseMil(distanceM: distanceM);
        if (!hausse.isFinite || hausse <= 0.0) continue;

        final candidate = Mo81LlrChargeChoice(
          charge: charge,
          hausseMil: hausse,
        );
        candidates.add(candidate);

        if (verbose || kDebugMode) {
          debugPrint(
            '[MO81 LLR CHARGE] ECL $variant '
            'D=${distanceM.toStringAsFixed(1)} '
            '$charge AE=${hausse.toStringAsFixed(2)} mil',
          );
        }

        // Les charges sont parcourues par ordre croissant : la première dans
        // la bande est nécessairement la charge doctrinale la plus faible.
        if (hausse >= 1000.0 && hausse <= 1100.0) {
          if (verbose || kDebugMode) {
            debugPrint(
              '[MO81 LLR CHARGE] ECL sélection doctrinale '
              '$variant => $charge AE=${hausse.toStringAsFixed(2)} mil',
            );
          }
          return candidate;
        }
      } catch (error) {
        if (verbose || kDebugMode) {
          debugPrint(
            '[MO81 LLR CHARGE] ECL $variant $charge indisponible : $error',
          );
        }
      }
    }

    throw StateError(
      'MO81 LLR / $variant : aucune charge ECL sélectionnable '
      'pour D=${distanceM.toStringAsFixed(0)} m.',
    );
  }

  static String _standardTableId(String variant, String charge) =>
      '${variant}_T2_$charge';

  static String _pathForTableId(String tableId) =>
      'assets/secure_enc/tableaux/MO81_LLR/T2/$tableId.ftbl.gz.enc';

  static List<String> _candidateTableIds(
    _Mo81LlrMunitionConfig config,
    String charge,
  ) {
    final standard = _standardTableId(config.variant, charge);
    final legacy = config.legacyTableIds[charge];

    if (legacy == null || legacy == standard) {
      return <String>[standard];
    }

    // On essaie d'abord le nom actuellement présent, puis le futur nom normalisé.
    return <String>[legacy, standard];
  }

  static double _ecartBande(double hausseMil) {
    if (hausseMil < 1000.0) return 1000.0 - hausseMil;
    if (hausseMil > 1100.0) return hausseMil - 1100.0;
    return 0.0;
  }

  static int _numeroCharge(String charge) {
    return int.tryParse(charge.replaceFirst('CH', '')) ?? 999;
  }

  static Future<double?> _hausseForCharge({
    required _Mo81LlrMunitionConfig config,
    required String charge,
    required double distanceM,
    required bool verbose,
  }) async {
    Object? lastError;

    for (final tableId in _candidateTableIds(config, charge)) {
      try {
        final service = TableauFService(
          typeTir: config.variant,
          charge: charge,
          verbose: verbose,
          encryptedPathOverride: _pathForTableId(tableId),
        );

        final hausse = await service.hausseMil(
          distance: distanceM,
          tirMontagne: true,
        );

        if (hausse != null && hausse.isFinite && hausse > 0.0) {
          return hausse;
        }
      } catch (e) {
        lastError = e;
      }
    }

    if (verbose && lastError != null) {
      debugPrint(
        '[MO81 LLR CHARGE] ${config.variant} $charge ignorée : $lastError',
      );
    }

    return null;
  }

  static Future<Mo81LlrChargeChoice> selectForDistance({
    required double distanceM,
    required TypeMunition munition,
    bool verbose = false,
  }) async {
    if (!distanceM.isFinite || distanceM <= 0) {
      throw StateError(
        'MO81 LLR : distance topographique invalide ($distanceM m).',
      );
    }

    if (munition == TypeMunition.oeclIr81F2) {
      return _selectIrF2FromEcl(distanceM: distanceM, verbose: verbose);
    }

    final config = _configForMunition(munition);
    final candidats = <Mo81LlrChargeChoice>[];

    for (final charge in config.charges) {
      final hausse = await _hausseForCharge(
        config: config,
        charge: charge,
        distanceM: distanceM,
        verbose: verbose,
      );

      if (hausse == null) continue;

      if (verbose || kDebugMode) {
        debugPrint(
          '[MO81 LLR CHARGE] ${config.variant} '
          'D=${distanceM.toStringAsFixed(1)} '
          '$charge hausse=${hausse.toStringAsFixed(2)} mil',
        );
      }

      final candidat = Mo81LlrChargeChoice(charge: charge, hausseMil: hausse);

      candidats.add(candidat);

      // Les charges sont parcourues dans l'ordre croissant : la première
      // solution dans la bande est donc automatiquement la plus faible.
      if (hausse >= 1000.0 && hausse <= 1100.0) {
        if (verbose || kDebugMode) {
          debugPrint(
            '[MO81 LLR CHARGE] sélection doctrinale '
            '${config.variant} => $charge '
            'hausse=${hausse.toStringAsFixed(2)} mil',
          );
        }
        return candidat;
      }
    }

    if (candidats.isNotEmpty && config.allowNearestFallback) {
      candidats.sort((a, b) {
        final cmpEcart = _ecartBande(
          a.hausseMil,
        ).compareTo(_ecartBande(b.hausseMil));
        if (cmpEcart != 0) return cmpEcart;
        return _numeroCharge(a.charge).compareTo(_numeroCharge(b.charge));
      });

      final fallback = candidats.first;

      if (verbose || kDebugMode) {
        debugPrint(
          '[MO81 LLR CHARGE] aucune charge dans 1000–1100 mil ; '
          '${config.variant} fallback => ${fallback.charge} '
          'hausse=${fallback.hausseMil.toStringAsFixed(2)} mil '
          'écart=${_ecartBande(fallback.hausseMil).toStringAsFixed(2)} mil',
        );
      }

      return fallback;
    }

    if (verbose || kDebugMode) {
      debugPrint(
        '[MO81 LLR CHARGE] ${config.variant} : '
        'aucune charge sélectionnable pour '
        'D=${distanceM.toStringAsFixed(0)} m.',
      );
    }

    throw StateError(
      'MO81 LLR / ${config.variant} : aucune charge sélectionnable '
      'pour D=${distanceM.toStringAsFixed(0)} m.',
    );
  }
}
