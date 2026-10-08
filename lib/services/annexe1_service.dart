// lib/services/annexe1_service.dart

import 'package:flutter/foundation.dart';

class Annexe1Entry {
  final double siteCalcule;
  final double correction;

  const Annexe1Entry(this.siteCalcule, this.correction);
}

class Annexe1Service {
  static const bool _verbose = true;

  /// Annexe 1 :
  /// "Tableau des corrections pour passer du site calculé par
  /// ΔZ(m) / X(km) au SITE VRAI ARTILLERIE (6400)".
  ///
  /// Les valeurs 5 à 400 sont reprises du tableau fourni.
  /// Le point 0 -> 0.0 est ajouté comme origine technique afin de permettre
  /// l'interpolation entre 0 et 5.
  static const List<Annexe1Entry> _table = <Annexe1Entry>[
    Annexe1Entry(0.0, 0.0),
    Annexe1Entry(5.0, 0.1),
    Annexe1Entry(10.0, 0.2),
    Annexe1Entry(20.0, 0.3),
    Annexe1Entry(30.0, 0.5),
    Annexe1Entry(40.0, 0.7),
    Annexe1Entry(50.0, 0.9),
    Annexe1Entry(60.0, 1.0),
    Annexe1Entry(70.0, 1.2),
    Annexe1Entry(80.0, 1.3),
    Annexe1Entry(90.0, 1.4),
    Annexe1Entry(100.0, 1.5),
    Annexe1Entry(110.0, 1.6),
    Annexe1Entry(120.0, 1.6),
    Annexe1Entry(130.0, 1.7),
    Annexe1Entry(140.0, 1.7),
    Annexe1Entry(150.0, 1.7),
    Annexe1Entry(160.0, 1.6),
    Annexe1Entry(170.0, 1.5),
    Annexe1Entry(180.0, 1.4),
    Annexe1Entry(190.0, 1.3),
    Annexe1Entry(200.0, 1.1),
    Annexe1Entry(210.0, 0.8),
    Annexe1Entry(220.0, 0.6),
    Annexe1Entry(230.0, 0.3),
    Annexe1Entry(240.0, -0.1),
    Annexe1Entry(250.0, -0.5),
    Annexe1Entry(260.0, -0.9),
    Annexe1Entry(270.0, -1.4),
    Annexe1Entry(280.0, -1.9),
    Annexe1Entry(290.0, -2.5),
    Annexe1Entry(300.0, -3.1),
    Annexe1Entry(310.0, -3.8),
    Annexe1Entry(320.0, -4.5),
    Annexe1Entry(330.0, -5.3),
    Annexe1Entry(340.0, -6.2),
    Annexe1Entry(350.0, -7.1),
    Annexe1Entry(360.0, -8.0),
    Annexe1Entry(370.0, -9.0),
    Annexe1Entry(380.0, -10.1),
    Annexe1Entry(390.0, -11.2),
    Annexe1Entry(400.0, -12.4),
  ];

  /// Renvoie la correction Annexe 1, en mil.
  ///
  /// [siteBrutMil] correspond au site calculé par ΔZ(m) / X(km).
  ///
  /// - valeur exacte du tableau -> correction exacte ;
  /// - valeur intermédiaire -> interpolation linéaire entre les deux lignes ;
  /// - |site| > 400 -> RangeError : l'Annexe 1 fournie ne donne aucune
  ///   correction au-delà de 400, donc le service n'extrapole pas.
  ///
  /// IMPORTANT :
  /// l'Annexe 1 fournie ne présente que des valeurs positives du site calculé.
  /// Le service précédent appliquait la table sur |site| puis réappliquait
  /// le signe. Cette convention est conservée ici pour compatibilité :
  /// correction(-site) = -correction(+site).
  static Future<double> correctionSiteVrai(double siteBrutMil) async {
    if (!siteBrutMil.isFinite) {
      throw ArgumentError.value(
        siteBrutMil,
        'siteBrutMil',
        'The calculated site must be a finite value.',
      );
    }

    final sign = siteBrutMil < 0 ? -1.0 : 1.0;
    final s = siteBrutMil.abs();

    if (s > _table.last.siteCalcule) {
      throw RangeError.range(
        s,
        _table.first.siteCalcule.toInt(),
        _table.last.siteCalcule.toInt(),
        'siteBrutMil',
        'Annex 1 available only up to 400.',
      );
    }

    for (final entry in _table) {
      if (s == entry.siteCalcule) {
        final result = entry.correction * sign;

        if (_verbose || kDebugMode) {
          debugPrint(
            '[Annexe1] siteBrut=$siteBrutMil '
            'siteAbs=$s correctionSiteVrai=$result (table value)',
          );
        }

        return result;
      }
    }

    for (var i = 0; i < _table.length - 1; i++) {
      final lo = _table[i];
      final hi = _table[i + 1];

      if (s > lo.siteCalcule && s < hi.siteCalcule) {
        final t = (s - lo.siteCalcule) / (hi.siteCalcule - lo.siteCalcule);

        final corr = lo.correction + (hi.correction - lo.correction) * t;

        final result = corr * sign;

        if (_verbose || kDebugMode) {
          debugPrint(
            '[Annexe1] siteBrut=$siteBrutMil '
            'siteAbs=$s '
            'borneBasse=${lo.siteCalcule}/${lo.correction} '
            'borneHaute=${hi.siteCalcule}/${hi.correction} '
            'correctionSiteVrai=$result (interpolation)',
          );
        }

        return result;
      }
    }

    throw StateError(
      'Unable to determine Annex 1 correction for $siteBrutMil.',
    );
  }
}
