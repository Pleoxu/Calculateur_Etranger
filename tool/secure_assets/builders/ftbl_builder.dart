import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class FtblBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 75;

  static const _flagTirMontagne = 0x01;

  static const Map<String, int> _validBits = {
    'dAE_per_100m': 0,
    'correctionV0Moins': 1,
    'correctionV0Plus': 2,
    'correctionVentMoins': 3,
    'correctionVentPlus': 4,
    'correctionTempMoins': 5,
    'correctionTempPlus': 6,
    'correctionPressionMoins': 7,
    'correctionPressionPlus': 8,
    'correctionMasseMoins': 9,
    'correctionMassePlus': 10,
  };

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith('Tableau_F_') && name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;

    final tableId = _buildTableId(filename);
    final outputName = '$tableId.ftbl.gz';

    final decoded = jsonDecode(await file.readAsString());

    late final List<Map<String, dynamic>> rows;

    if (decoded is List) {
      rows = decoded.cast<Map<String, dynamic>>();
    } else if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];

      if (data is! List) {
        throw FormatException(
          'Champ "data" manquant ou invalide dans $filename.',
        );
      }

      rows = data.cast<Map<String, dynamic>>();
    } else {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON ou un objet avec data[].',
      );
    }

    _normalizeRows(rows);
    _computeVarHausse(rows);
    _validateRows(rows);

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/F/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : FTBL_V1');
    print('Rows : ${rows.length}');
    print('FTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'F',
      'variant': _extractVariant(filename),
      'charge': _extractCharge(filename),
      'format': 'FTBL_V1',
      'rows': rows.length,
      'file': 'tableaux/F/$outputName',
      'keyVersion': 0,
    };
  }

  void _normalizeRows(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      if (!row.containsKey('tempageS') && row.containsKey('tempage')) {
        row['tempageS'] = row['tempage'];
      }
    }
  }

  void _computeVarHausse(List<Map<String, dynamic>> rows) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      if (row['varHaussePour100m'] != null) {
        continue;
      }

      final currentMode = row['tirMontagne'];

      Map<String, dynamic>? next;

      for (var j = i + 1; j < rows.length; j++) {
        if (rows[j]['tirMontagne'] == currentMode) {
          next = rows[j];
          break;
        }

        break;
      }

      if (next == null) {
        row['varHaussePour100m'] = 0.0;
        continue;
      }

      final currentDistance = (row['distance'] as num).toDouble();
      final currentHausse = (row['hausse'] as num).toDouble();

      final nextDistance = (next['distance'] as num).toDouble();
      final nextHausse = (next['hausse'] as num).toDouble();

      final deltaDistance = (nextDistance - currentDistance).abs();

      if (deltaDistance <= 0.0001) {
        row['varHaussePour100m'] = 0.0;
        continue;
      }

      row['varHaussePour100m'] =
          ((nextHausse - currentHausse).abs() / deltaDistance) * 100.0;
    }
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final bytes = Uint8List(_headerSize + rows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x46, 0x54, 0x42, 0x4C]); // FTBL
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    for (final row in rows) {
      void writeFloat(String field, {bool required = true}) {
        final value = row[field];

        if (value == null) {
          if (required) {
            throw FormatException(
              'Champ FTBL obligatoire manquant "$field" : $row',
            );
          }

          data.setFloat32(offset, 0.0, Endian.little);
          offset += 4;
          return;
        }

        if (value is! num) {
          throw FormatException(
            'Champ FTBL numérique invalide "$field" : $value',
          );
        }

        data.setFloat32(offset, value.toDouble(), Endian.little);
        offset += 4;
      }

      writeFloat('distance');
      writeFloat('hausse');
      writeFloat('derive');
      writeFloat('correctionWz');

      writeFloat('dAE_per_100m', required: false);

      writeFloat('correctionV0Moins', required: false);
      writeFloat('correctionV0Plus', required: false);

      writeFloat('correctionVentMoins', required: false);
      writeFloat('correctionVentPlus', required: false);

      writeFloat('correctionTempMoins', required: false);
      writeFloat('correctionTempPlus', required: false);

      writeFloat('correctionPressionMoins', required: false);
      writeFloat('correctionPressionPlus', required: false);

      writeFloat('correctionMasseMoins', required: false);
      writeFloat('correctionMassePlus', required: false);

      writeFloat('tempageS');
      writeFloat('varHaussePour100m');

      final tirMontagne = row['tirMontagne'];

      if (tirMontagne is! bool) {
        throw FormatException(
          'Champ FTBL booléen invalide "tirMontagne" : $tirMontagne',
        );
      }

      var flags = 0;
      if (tirMontagne) {
        flags |= _flagTirMontagne;
      }

      data.setUint8(offset, flags);
      offset += 1;

      var validMask = 0;

      for (final entry in _validBits.entries) {
        if (row.containsKey(entry.key) && row[entry.key] != null) {
          validMask |= 1 << entry.value;
        }
      }

      data.setUint32(offset, validMask, Endian.little);
      offset += 4;

      data.setUint16(offset, 0, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  void _validateRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      throw FormatException('FTBL vide');
    }

    bool? currentMode;
    double? previousDistance;
    int direction = 0; // 0 = inconnue, 1 = croissant, -1 = décroissant

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      _requireNum(row, 'distance', i);
      _requireNum(row, 'hausse', i);
      _requireNum(row, 'derive', i);
      _requireNum(row, 'correctionWz', i);
      _requireNum(row, 'tempageS', i);
      _requireNum(row, 'varHaussePour100m', i);

      final tirMontagne = row['tirMontagne'];
      if (tirMontagne is! bool) {
        throw FormatException(
          'FTBL row[$i] tirMontagne invalide : $tirMontagne',
        );
      }

      for (final field in _validBits.keys) {
        if (row.containsKey(field) &&
            row[field] != null &&
            row[field] is! num) {
          throw FormatException(
            'FTBL row[$i] champ numérique invalide "$field" : ${row[field]}',
          );
        }
      }

      final distance = (row['distance'] as num).toDouble();

      if (distance < 0 || distance > 100000) {
        throw FormatException('FTBL row[$i] distance hors plage : $distance');
      }

      if (currentMode == null || tirMontagne != currentMode) {
        currentMode = tirMontagne;
        previousDistance = distance;
        direction = 0;
        continue;
      }

      final delta = distance - previousDistance!;

      if (delta.abs() <= 0.0001) {
        previousDistance = distance;
        continue;
      }

      final currentDirection = delta > 0 ? 1 : -1;

      if (direction == 0) {
        direction = currentDirection;
      } else if (currentDirection != direction) {
        throw FormatException(
          'FTBL tri invalide row[$i] : distance=$distance après '
          '$previousDistance pour tirMontagne=$tirMontagne',
        );
      }

      previousDistance = distance;
    }
  }

  void _requireNum(Map<String, dynamic> row, String field, int index) {
    final value = row[field];

    if (value is! num) {
      throw FormatException(
        'FTBL row[$index] champ obligatoire numérique invalide '
        '"$field" : $value',
      );
    }
  }

  String _buildTableId(String filename) {
    final base = filename.replaceAll('.json', '');
    return base.replaceFirst('Tableau_', '').toUpperCase();
  }

  String _extractVariant(String filename) {
    if (filename.contains('AppuiRTC')) return 'APPUIRTC';
    if (filename.contains('Appui')) return 'APPUI';
    if (filename.contains('OECL')) return 'OECL';

    return 'UNKNOWN';
  }

  int _extractCharge(String filename) {
    final match = RegExp(r'CH(\d+)').firstMatch(filename);
    return match == null ? 0 : int.parse(match.group(1)!);
  }
}
