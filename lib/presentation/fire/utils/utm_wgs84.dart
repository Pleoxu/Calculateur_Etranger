import 'dart:math' as math;

/// Conversion UTM ↔ WGS84.
///
/// Réutilise la même implémentation que [FireGeometryResolver],
/// exposée ici comme utilitaire statique accessible depuis toute la présentation.
class UtmWgs84 {
  const UtmWgs84._();

  // ─────────────────────────────────────────────────────────────────────────
  // UTM → WGS84
  // ─────────────────────────────────────────────────────────────────────────

  /// Convertit des coordonnées UTM (easting, northing, zone) en WGS84 (lat, lon).
  ///
  /// [zone] : chaîne de zone UTM, ex. "31N", "31T", "32", etc.
  ///   Si null ou vide, la zone 31N (Europe de l'Ouest) est utilisée par défaut.
  static LatLonDeg utmToLatLon({
    required double easting,
    required double northing,
    String? zone,
  }) {
    final parsed = _parseZone(zone);
    return _utmToWgs84(
      easting: easting,
      northing: northing,
      zoneNumber: parsed.number,
      isNorth: parsed.isNorth,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WGS84 → UTM
  // ─────────────────────────────────────────────────────────────────────────

  /// Convertit des coordonnées WGS84 (lat, lon) en UTM.
  ///
  /// Retourne un [UtmPoint] contenant easting, northing, numéro de zone et
  /// la lettre de bande de latitude (ex. "T" pour la France métropolitaine).
  static UtmPoint latLonToUtm({
    required double latDeg,
    required double lonDeg,
  }) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;

    final latRad = latDeg * math.pi / 180.0;
    final lonRad = lonDeg * math.pi / 180.0;

    final zoneNumber = ((lonDeg + 180) / 6).floor() + 1;
    final lon0Deg = (zoneNumber - 1) * 6 - 180 + 3;
    final lon0Rad = lon0Deg * math.pi / 180.0;

    final e2 = f * (2 - f);
    final ep2 = e2 / (1 - e2);

    final N = a / math.sqrt(1 - e2 * math.sin(latRad) * math.sin(latRad));
    final T = math.tan(latRad) * math.tan(latRad);
    final C = ep2 * math.cos(latRad) * math.cos(latRad);
    final A = math.cos(latRad) * (lonRad - lon0Rad);

    final M = a *
        ((1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256) * latRad -
            (3 * e2 / 8 + 3 * e2 * e2 / 32 + 45 * e2 * e2 * e2 / 1024) *
                math.sin(2 * latRad) +
            (15 * e2 * e2 / 256 + 45 * e2 * e2 * e2 / 1024) *
                math.sin(4 * latRad) -
            (35 * e2 * e2 * e2 / 3072) * math.sin(6 * latRad));

    final easting = k0 *
            N *
            (A +
                (1 - T + C) * math.pow(A, 3) / 6 +
                (5 - 18 * T + T * T + 72 * C - 58 * ep2) *
                    math.pow(A, 5) /
                    120) +
        500000.0;

    var northing = k0 *
        (M +
            N *
                math.tan(latRad) *
                (A * A / 2 +
                    (5 - T + 9 * C + 4 * C * C) * math.pow(A, 4) / 24 +
                    (61 - 58 * T + T * T + 600 * C - 330 * ep2) *
                        math.pow(A, 6) /
                        720));

    final isNorth = latDeg >= 0;
    if (!isNorth) {
      northing += 10000000.0;
    }

    final bandLetter = _utmLatBandLetter(latDeg);

    return UtmPoint(
      easting: easting,
      northing: northing,
      zoneNumber: zoneNumber,
      bandLetter: bandLetter,
    );
  }

  /// Retourne la lettre de bande de latitude UTM (C–X, sans I ni O).
  static String _utmLatBandLetter(double latDeg) {
    const bands = 'CDEFGHJKLMNPQRSTUVWX';
    if (latDeg < -80 || latDeg > 84) return 'Z';
    final idx = ((latDeg + 80) / 8).floor().clamp(0, 19);
    return bands[idx];
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Parsing de zone UTM
  // ─────────────────────────────────────────────────────────────────────────

  static _Zone _parseZone(String? zone) {
    final z = (zone ?? '').trim().toUpperCase();
    if (z.isEmpty) return const _Zone(31, true);

    final m = RegExp(r'^(\d{1,2})([A-Z])?$').firstMatch(z);
    if (m == null) {
      final num = int.tryParse(z.replaceAll(RegExp(r'[^0-9]'), '')) ?? 31;
      return _Zone(num, true);
    }

    final num = int.tryParse(m.group(1)!) ?? 31;
    final letter = m.group(2);
    if (letter == null) return _Zone(num, true);
    return _Zone(num, letter.compareTo('N') >= 0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Algorithme UTM → WGS84 (Transverse Mercator inverse)
  // ─────────────────────────────────────────────────────────────────────────

  static LatLonDeg _utmToWgs84({
    required double easting,
    required double northing,
    required int zoneNumber,
    required bool isNorth,
  }) {
    const a = 6378137.0;
    const f = 1 / 298.257223563;
    const k0 = 0.9996;

    const b = a * (1 - f);
    final e2 = (a * a - b * b) / (a * a);
    final lon0Rad = ((zoneNumber - 1) * 6 - 180 + 3) * (math.pi / 180.0);

    final x = easting - 500000.0;
    final y = isNorth ? northing : northing - 10000000.0;

    final M = y / k0;
    final mu =
        M / (a * (1 - e2 / 4 - 3 * e2 * e2 / 64 - 5 * e2 * e2 * e2 / 256));

    final e1 = (1 - math.sqrt(1 - e2)) / (1 + math.sqrt(1 - e2));
    final j1 = 3 * e1 / 2 - 27 * e1 * e1 * e1 / 32;
    final j2 = 21 * e1 * e1 / 16 - 55 * e1 * e1 * e1 * e1 / 32;
    final j3 = 151 * e1 * e1 * e1 / 96;
    final j4 = 1097 * e1 * e1 * e1 * e1 / 512;

    final fp = mu +
        j1 * math.sin(2 * mu) +
        j2 * math.sin(4 * mu) +
        j3 * math.sin(6 * mu) +
        j4 * math.sin(8 * mu);

    final C1 = e2 * math.pow(math.cos(fp), 2) / (1 - e2);
    final T1 = math.pow(math.tan(fp), 2);
    final N1 = a / math.sqrt(1 - e2 * math.pow(math.sin(fp), 2));
    final R1 = a * (1 - e2) / math.pow(1 - e2 * math.pow(math.sin(fp), 2), 1.5);
    final D = x / (N1 * k0);

    final latRad = fp -
        (N1 * math.tan(fp) / R1) *
            (D * D / 2 -
                (5 + 3 * T1 + 10 * C1 - 4 * C1 * C1 - 9 * e2) *
                    D *
                    D *
                    D *
                    D /
                    24 +
                (61 +
                        90 * T1 +
                        298 * C1 +
                        45 * T1 * T1 -
                        252 * e2 -
                        3 * C1 * C1) *
                    D *
                    D *
                    D *
                    D *
                    D *
                    D /
                    720);

    final lonRad = lon0Rad +
        (D -
                (1 + 2 * T1 + C1) * D * D * D / 6 +
                (5 - 2 * C1 + 28 * T1 - 3 * C1 * C1 + 8 * e2 + 24 * T1 * T1) *
                    D *
                    D *
                    D *
                    D *
                    D /
                    120) /
            math.cos(fp);

    return LatLonDeg(latRad * 180.0 / math.pi, lonRad * 180.0 / math.pi);
  }
}

/// Coordonnées WGS84 (degrés décimaux).
class LatLonDeg {
  const LatLonDeg(this.lat, this.lon);
  final double lat;
  final double lon;

  @override
  String toString() =>
      '${lat.toStringAsFixed(6)}°N, ${lon.toStringAsFixed(6)}°E';
}

/// Coordonnées UTM résultant d'une conversion WGS84 → UTM.
class UtmPoint {
  const UtmPoint({
    required this.easting,
    required this.northing,
    required this.zoneNumber,
    required this.bandLetter,
  });

  final double easting;
  final double northing;
  final int zoneNumber;

  /// Lettre de bande de latitude (ex. "T" pour la France métropolitaine).
  final String bandLetter;

  /// Zone UTM formatée, ex. "31T".
  String get zoneString => '$zoneNumber$bandLetter';
}

class _Zone {
  const _Zone(this.number, this.isNorth);
  final int number;
  final bool isNorth;
}
