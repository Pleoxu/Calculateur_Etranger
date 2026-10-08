// lib/domain/meteo/metb_parser.dart

import '../entities/meteo_row.dart';
import 'meteo_parse_result.dart';

/// Parser pour les messages MET B.
class MetBParser {
  /// Parse un contenu MET B et retourne MeteoParseResult avec altitude station
  /// et informations temporelles.
  ///
  /// Format MET B :
  /// - En-tête : MET B 3 3 470 022 24 094 4 018 997
  ///   - 470 022 : latitude/longitude
  ///   - 24 : jour du mois
  ///   - 094 : heure au format HHQ
  ///   - 4 : durée de validité
  ///   - 018 : altitude station (180 m)
  ///   - 997 : pression station (information brute, non utilisée ici)
  ///
  /// - Lignes de données : LL DD VV TTT PPP
  ///   Exemple : "07 63 07 987 011"
  static MeteoParseResult parseWithAltitude(String content) {
    final rows = <MeteoRow>[];
    int? stationAltM;
    MeteoTemporalInfo? temporalInfo;

    if (content.isEmpty) {
      return const MeteoParseResult(rows: <MeteoRow>[], stationAltitudeM: null);
    }

    final lines = content.split(RegExp(r'\r?\n'));

    // Lecture robuste de l'en-tête par champs séparés.
    //
    // Exemple :
    // MET B 3 3 453 035 22 095 2 036 004
    //
    // Index :
    // 0 MET
    // 1 B
    // 2 version/type
    // 3 octant
    // 4 latitude
    // 5 longitude
    // 6 jour
    // 7 heure HHQ
    // 8 validité
    // 9 altitude station
    // 10 pression station
    for (final raw in lines) {
      final t = raw.trim();
      if (t.isEmpty) continue;

      if (t.startsWith('MET B')) {
        final parts = t.split(RegExp(r'\s+'));

        if (parts.length >= 11 && parts[0] == 'MET' && parts[1] == 'B') {
          final day = int.tryParse(parts[6]);
          final hourCode = int.tryParse(parts[7]);
          final validityCode = int.tryParse(parts[8]);
          final altCode = int.tryParse(parts[9]);

          if (altCode != null) {
            stationAltM = altCode * 10;
          }

          if (day != null && hourCode != null && validityCode != null) {
            final int validityHours;

            if (validityCode == 0) {
              validityHours = 0;
            } else if (validityCode == 9) {
              validityHours = 12;
            } else if (validityCode >= 1 && validityCode <= 8) {
              validityHours = validityCode;
            } else {
              validityHours = 0;
            }

            temporalInfo = MeteoTemporalInfo(
              day: day,
              hourCode: hourCode,
              validityHours: validityHours,
            );
          }
        }

        continue;
      }
    }

    // Format MET B : "07 63 07 987 011"
    // Accepte les variations d'espacement.
    final dataRegex = RegExp(
      r'^\s*(\d{2})\s+(\d{2,3})\s+(\d{2,3})\s+(\d{3})\s+(\d{3})\s*$',
    );

    for (final raw in lines) {
      final t = raw.trim();
      if (t.isEmpty) continue;

      // Ignorer l'en-tête.
      if (t.startsWith('MET B')) continue;

      final m = dataRegex.firstMatch(t);
      if (m == null) continue;

      final ll = int.parse(m.group(1)!);
      final dd = int.parse(m.group(2)!);
      final vv = int.parse(m.group(3)!);
      final ttt = int.parse(m.group(4)!);
      final ppp = int.parse(m.group(5)!);

      // Décodage MET B :
      // si < 500, on ajoute 1000 (ratio ISA encodé sur 3 chiffres).
      final tempFinal = ttt < 500 ? 1000 + ttt : ttt;
      final pressFinal = ppp < 500 ? 1000 + ppp : ppp;

      rows.add(
        MeteoRow(
          level: ll,
          azimutMils: dd * 100,
          vKn: vv,
          tempPermil: tempFinal,
          pressPermil: pressFinal,
          sourceType: 'METB',
        ),
      );
    }

    return MeteoParseResult(
      rows: rows,
      stationAltitudeM: stationAltM,
      temporalInfo: temporalInfo,
    );
  }

  /// Parse un contenu MET B et retourne seulement la liste de MeteoRow.
  static List<MeteoRow> parse(String content) {
    return parseWithAltitude(content).rows;
  }
}
