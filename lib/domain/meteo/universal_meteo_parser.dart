// lib/domain/meteo/universal_meteo_parser.dart

import '../entities/meteo_row.dart';
import 'metcm_to_metb_transformer.dart';
import 'metb_parser.dart';
import 'meteo_parse_result.dart';

/// Parser universel qui détecte automatiquement le format météo.
class UniversalMeteoParser {
  /// Parse un contenu météo (METCM ou MET B) et retourne MeteoParseResult.
  ///
  /// Détecte automatiquement le format après normalisation du texte :
  /// - METCM  -> transformation METCM vers MeteoRow ;
  /// - MET B  -> lecture directe du message MET B.
  static MeteoParseResult parseWithAltitude(String content) {
    final normalized = _normalizeContent(content);

    if (normalized.trim().isEmpty) {
      throw Exception('Empty weather content');
    }

    final lines = normalized
        .split('\n')
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      throw Exception('Weather content empty after normalization');
    }

    final firstLine = lines.first;

    if (_isMetcmHeader(firstLine)) {
      return _parseMetcm(normalized, lines);
    }

    if (_isMetBHeader(firstLine)) {
      final result = MetBParser.parseWithAltitude(normalized);

      if (result.rows.isEmpty) {
        throw Exception(
          'MET B message recognized, but no valid weather line found. '
          'First line: $firstLine',
        );
      }

      return result;
    }

    throw Exception(
      'Unrecognized weather format. Expected: METCM or MET B\n'
      'Normalized first line: $firstLine',
    );
  }

  /// Parse un contenu météo et retourne seulement la liste de MeteoRow.
  static List<MeteoRow> parse(String content) {
    return parseWithAltitude(content).rows;
  }

  /// Normalise les caractères fréquemment introduits par un copier-coller
  /// depuis un PDF, un traitement de texte ou un navigateur.
  static String _normalizeContent(String raw) {
    var value = raw;

    // BOM Unicode éventuel.
    if (value.isNotEmpty && value.codeUnitAt(0) == 0xFEFF) {
      value = value.substring(1);
    }

    value = value
        // Espaces Unicode.
        .replaceAll('\u00A0', ' ') // NO-BREAK SPACE
        .replaceAll('\u202F', ' ') // NARROW NO-BREAK SPACE
        .replaceAll('\u2007', ' ') // FIGURE SPACE
        .replaceAll('\u2009', ' ') // THIN SPACE
        .replaceAll('\u200A', ' ') // HAIR SPACE
        .replaceAll('\u200B', '') // ZERO WIDTH SPACE
        .replaceAll('\u2060', '') // WORD JOINER
        // Signes typographiques.
        .replaceAll('\u2212', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2014', '-')
        // Retours et tabulations.
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', ' ');

    return value;
  }

  /// Nettoie une ligne sans modifier sa structure logique.
  static String _normalizeLine(String raw) {
    return raw.trim().replaceAll(RegExp(r'[ ]+'), ' ');
  }

  static bool _isMetcmHeader(String line) {
    return RegExp(r'^METCM\s*3?\b', caseSensitive: false).hasMatch(line);
  }

  static bool _isMetBHeader(String line) {
    return RegExp(r'^MET\s+B\b', caseSensitive: false).hasMatch(line);
  }

  /// Parse un message METCM et le transforme en MeteoParseResult.
  static MeteoParseResult _parseMetcm(
    String content,
    List<String> normalizedLines,
  ) {
    final metcmLayers = <MetcmLayer>[];
    int? stationAltM;

    // Format attendu :
    // METCM3 DDMMYY HHMMSS 018997
    final headerRegex = RegExp(
      r'^METCM\s*3?\s+\d{6}\s+\d{6}\s+(\d{3})\d{3}\s*$',
      caseSensitive: false,
    );

    var currentLine = 0;

    for (final rawLine in normalizedLines) {
      final line = _normalizeLine(rawLine);

      if (line.isEmpty) {
        continue;
      }

      if (_isMetcmHeader(line)) {
        final match = headerRegex.firstMatch(line);

        if (match != null) {
          final altCode = int.tryParse(match.group(1)!);
          if (altCode != null) {
            stationAltM = altCode * 10;
          }
        }

        continue;
      }

      if (line.startsWith('99999')) {
        break;
      }

      try {
        final metcmLayer = MetcmLayer.fromLine(line, currentLine);
        metcmLayers.add(metcmLayer);
        currentLine++;
      } catch (_) {
        // Une ligne mal formée est ignorée, mais le message entier n'est pas
        // rejeté si d'autres couches sont valides.
      }
    }

    if (metcmLayers.isEmpty) {
      throw Exception('No valid METCM data found');
    }

    final rows = MeteoTransformer.transformToMeteoRows(metcmLayers);

    if (rows.isEmpty) {
      throw Exception('METCM transformation successful, but no line created');
    }

    return MeteoParseResult(rows: rows, stationAltitudeM: stationAltM);
  }
}
