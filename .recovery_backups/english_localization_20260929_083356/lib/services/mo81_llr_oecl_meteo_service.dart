// lib/services/mo81_llr_oecl_meteo_service.dart
//
// Sélection de la ligne météorologique pour MO81 LLR / OECL IR F2.
//
// Méthode OECL :
// 1) Dt = distance du début d'éclairement.
// 2) Lire dans ECL la portée correspondant au point d'impact en absence
//    de dépotage (colonne 7).
// 3) À cette portée, lire/interpoler dans T2 la flèche F (colonne 5).
// 4) Corriger la flèche de la différence d'altitude Batterie / MDP :
//       Fcorr = F + (Zbie - Zmdp)
// 5) Arrondir Fcorr au 100 m le plus proche.
// 6) Déterminer la ligne météo à partir des zones d'utilisation.
//
// Convention aux limites : une valeur exactement égale à une borne commune
// est affectée à la ligne supérieure.
// Exemple : 2500 m -> LN06, et non LN05.

import 'package:flutter/foundation.dart';

@immutable
class Mo81LlrOeclMeteoResult {
  final double distanceTopoM;
  final double porteeSansDepotageM;
  final double flecheM;
  final double zBatterieM;
  final double zMdpM;
  final double deltaZBatterieMdpM;
  final double flecheCorrigeeM;
  final double flecheCorrigeeArrondieM;
  final int ligneMeteo;

  const Mo81LlrOeclMeteoResult({
    required this.distanceTopoM,
    required this.porteeSansDepotageM,
    required this.flecheM,
    required this.zBatterieM,
    required this.zMdpM,
    required this.deltaZBatterieMdpM,
    required this.flecheCorrigeeM,
    required this.flecheCorrigeeArrondieM,
    required this.ligneMeteo,
  });
}

@immutable
class _MeteoZone {
  final int ligne;
  final double hauteurStandardM;
  final double minM;
  final double maxM;

  const _MeteoZone({
    required this.ligne,
    required this.hauteurStandardM,
    required this.minM,
    required this.maxM,
  });
}

class Mo81LlrOeclMeteoService {
  const Mo81LlrOeclMeteoService._();

  static const List<_MeteoZone> _zones = <_MeteoZone>[
    _MeteoZone(ligne: 0, hauteurStandardM: 0, minM: 0, maxM: 100),
    _MeteoZone(ligne: 1, hauteurStandardM: 200, minM: 100, maxM: 350),
    _MeteoZone(ligne: 2, hauteurStandardM: 500, minM: 350, maxM: 750),
    _MeteoZone(ligne: 3, hauteurStandardM: 1000, minM: 750, maxM: 1250),
    _MeteoZone(ligne: 4, hauteurStandardM: 1500, minM: 1250, maxM: 1750),
    _MeteoZone(ligne: 5, hauteurStandardM: 2000, minM: 1750, maxM: 2500),
    _MeteoZone(ligne: 6, hauteurStandardM: 3000, minM: 2500, maxM: 3500),
    _MeteoZone(ligne: 7, hauteurStandardM: 4000, minM: 3500, maxM: 4500),
    _MeteoZone(ligne: 8, hauteurStandardM: 5000, minM: 4500, maxM: 5500),
    _MeteoZone(ligne: 9, hauteurStandardM: 6000, minM: 5500, maxM: 7000),
    _MeteoZone(ligne: 10, hauteurStandardM: 8000, minM: 7000, maxM: 9000),
    _MeteoZone(ligne: 11, hauteurStandardM: 10000, minM: 9000, maxM: 11000),
    _MeteoZone(ligne: 12, hauteurStandardM: 12000, minM: 11000, maxM: 13000),
    _MeteoZone(ligne: 13, hauteurStandardM: 14000, minM: 13000, maxM: 15000),
    _MeteoZone(ligne: 14, hauteurStandardM: 16000, minM: 15000, maxM: 17000),
    _MeteoZone(ligne: 15, hauteurStandardM: 18000, minM: 17000, maxM: 19000),
  ];

  static double _roundToNearest100(double valueM) {
    return (valueM / 100.0).round() * 100.0;
  }

  static int lignePourFlecheCorrigee(double flecheCorrigeeM) {
    if (!flecheCorrigeeM.isFinite) {
      throw StateError(
        'MO81 LLR OECL : flèche corrigée invalide ($flecheCorrigeeM m).',
      );
    }

    final arrondie = _roundToNearest100(flecheCorrigeeM);

    if (arrondie < _zones.first.minM || arrondie > _zones.last.maxM) {
      throw StateError(
        'MO81 LLR OECL : flèche corrigée arrondie hors zones météo '
        '(${arrondie.toStringAsFixed(0)} m).',
      );
    }

    for (var i = 0; i < _zones.length; i++) {
      final zone = _zones[i];
      final isLast = i == _zones.length - 1;

      if (arrondie >= zone.minM &&
          (arrondie < zone.maxM || (isLast && arrondie <= zone.maxM))) {
        return zone.ligne;
      }
    }

    throw StateError(
      'MO81 LLR OECL : aucune ligne météo pour '
      '${arrondie.toStringAsFixed(0)} m.',
    );
  }

  static Mo81LlrOeclMeteoResult computeFromTableValues({
    required double distanceTopoM,
    required double porteeSansDepotageM,
    required double flecheM,
    required double zBatterieM,
    required double zMdpM,
    bool verbose = false,
  }) {
    for (final entry in <MapEntry<String, double>>[
      MapEntry('distanceTopoM', distanceTopoM),
      MapEntry('porteeSansDepotageM', porteeSansDepotageM),
      MapEntry('flecheM', flecheM),
      MapEntry('zBatterieM', zBatterieM),
      MapEntry('zMdpM', zMdpM),
    ]) {
      if (!entry.value.isFinite) {
        throw StateError(
          'MO81 LLR OECL : ${entry.key} invalide (${entry.value}).',
        );
      }
    }

    if (distanceTopoM <= 0 || porteeSansDepotageM <= 0 || flecheM < 0) {
      throw StateError(
        'MO81 LLR OECL : valeurs balistiques invalides '
        '(Dt=$distanceTopoM, portée impact=$porteeSansDepotageM, '
        'flèche=$flecheM).',
      );
    }

    final deltaZ = zBatterieM - zMdpM;
    final flecheCorrigee = flecheM + deltaZ;
    final flecheArrondie = _roundToNearest100(flecheCorrigee);
    final ligne = lignePourFlecheCorrigee(flecheCorrigee);

    if (verbose || kDebugMode) {
      debugPrint(
        '[MO81 LLR OECL MET] '
        'Dt=${distanceTopoM.toStringAsFixed(0)} m '
        'Dimpact=${porteeSansDepotageM.toStringAsFixed(0)} m '
        'F=${flecheM.toStringAsFixed(0)} m '
        'Zbie=${zBatterieM.toStringAsFixed(0)} m '
        'Zmdp=${zMdpM.toStringAsFixed(0)} m '
        'ΔZ=${deltaZ.toStringAsFixed(0)} m '
        'Fcorr=${flecheCorrigee.toStringAsFixed(0)} m '
        'arr=${flecheArrondie.toStringAsFixed(0)} m '
        '=> LN=${ligne.toString().padLeft(2, '0')}',
      );
    }

    return Mo81LlrOeclMeteoResult(
      distanceTopoM: distanceTopoM,
      porteeSansDepotageM: porteeSansDepotageM,
      flecheM: flecheM,
      zBatterieM: zBatterieM,
      zMdpM: zMdpM,
      deltaZBatterieMdpM: deltaZ,
      flecheCorrigeeM: flecheCorrigee,
      flecheCorrigeeArrondieM: flecheArrondie,
      ligneMeteo: ligne,
    );
  }
}
