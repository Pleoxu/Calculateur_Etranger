// lib/domain/meteo/meteo_parse_result.dart

import '../entities/meteo_row.dart';

/// Résultat unifié de parsing météo (METCM ou METB)
class MeteoParseResult {
  /// Lignes météo unifiées (toujours en ‰ pour T et P)
  final List<MeteoRow> rows;

  /// Altitude station (m) si connue
  final int? stationAltitudeM;

  /// Infos temporelles (jour, heure HHQ, validité en heures)
  final MeteoTemporalInfo? temporalInfo;

  const MeteoParseResult({
    required this.rows,
    required this.stationAltitudeM,
    this.temporalInfo,
  });
}

/// Infos temporelles extraites du header
///
/// - day: 1..31
/// - hourCode: HHQ sur 3 digits (ex: 094 => 09h24 car Q=4 => 24min)
/// - validityHours: 4 / 6 / 8 / 12 / 0 (= indéterminée)
class MeteoTemporalInfo {
  final int day; // 1-31
  final int hourCode; // ex: 094 (HHQ)
  final int validityHours; // 4,6,8,12 ou 0

  const MeteoTemporalInfo({
    required this.day,
    required this.hourCode,
    required this.validityHours,
  });

  /// Décodage "094" => 09h24 (HHQ où Q = pas de 6 minutes)
  static ({int hour, int minute}) decodeHourCode(int code) {
    final s = code.toString().padLeft(3, '0'); // "094"
    final hh = int.parse(s.substring(0, 2)); // 09
    final q = int.parse(s.substring(2, 3)); // 4
    final mm = q * 6; // 24
    return (hour: hh, minute: mm);
  }

  /// Emission: choisit la date la plus plausible (mois-1 / mois / mois+1)
  DateTime getEmissionDateTime({DateTime? now}) {
    final base = now ?? DateTime.now();
    final decoded = decodeHourCode(hourCode);

    final candidates = <DateTime>[
      _safeDateTime(
        base.year,
        base.month - 1,
        day,
        decoded.hour,
        decoded.minute,
      ),
      _safeDateTime(base.year, base.month, day, decoded.hour, decoded.minute),
      _safeDateTime(
        base.year,
        base.month + 1,
        day,
        decoded.hour,
        decoded.minute,
      ),
    ];

    DateTime best = candidates.first;
    Duration bestDelta = _absDuration(best.difference(base));

    for (final c in candidates.skip(1)) {
      final delta = _absDuration(c.difference(base));
      if (delta < bestDelta) {
        best = c;
        bestDelta = delta;
      }
    }

    return best;
  }

  /// Expiration: émission + validityHours (null si indéterminée)
  DateTime? getExpirationDateTime({DateTime? now}) {
    if (validityHours <= 0) return null;
    final emission = getEmissionDateTime(now: now);
    return emission.add(Duration(hours: validityHours));
  }

  // ---- helpers internes ----

  static Duration _absDuration(Duration d) => d.isNegative ? -d : d;

  static int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  static DateTime _safeDateTime(
    int year,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    var y = year;
    var m = month;

    while (m <= 0) {
      m += 12;
      y -= 1;
    }
    while (m >= 13) {
      m -= 12;
      y += 1;
    }

    final lastDay = _daysInMonth(y, m);
    final d = day.clamp(1, lastDay);

    return DateTime(y, m, d, hour, minute);
  }
}
