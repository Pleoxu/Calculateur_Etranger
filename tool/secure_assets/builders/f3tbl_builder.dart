import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class F3tblBuilder implements TableBuilder {
  static const _baseHeaderSize = 10;
  static const _baseRowSize = 5;

  static const _flagTirMontagne = 0x01;

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last;
    return (name.startsWith('Tableau_F3_') ||
            name.startsWith('Tableau_F3i_')) &&
        name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;

    final tableId = _buildTableId(filename);
    final outputName = '$tableId.f3tbl.gz';

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour F3TBL_V1.',
      );
    }

    final meta = decoded['meta'];
    if (meta is! Map<String, dynamic>) {
      throw FormatException(
        'Champ "meta" manquant ou invalide dans $filename.',
      );
    }

    final temperaturesRaw = meta['temperaturesC'];
    if (temperaturesRaw is! List || temperaturesRaw.isEmpty) {
      throw FormatException(
        'Champ "meta.temperaturesC" manquant ou invalide dans $filename.',
      );
    }

    final temperatures = temperaturesRaw.map((v) {
      if (v is! num) {
        throw FormatException('Température F3 invalide : $v');
      }
      final t = v.toInt();
      if (t < -32768 || t > 32767) {
        throw FormatException('Température F3 hors plage int16 : $t');
      }
      return t;
    }).toList();

    final data = decoded['data'];
    if (data is! List) {
      throw FormatException(
        'Champ "data" manquant ou invalide dans $filename.',
      );
    }

    final rows = data.cast<Map<String, dynamic>>();

    _validateRows(rows, temperatures);

    final binary = _encode(rows, temperatures);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/F3/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : F3TBL_V1');
    print('Rows : ${rows.length}');
    print('Temperatures : $temperatures');
    print('F3TBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'F3',
      'variant': _extractVariant(filename),
      'charge': _extractCharge(filename),
      'format': 'F3TBL_V1',
      'rows': rows.length,
      'file': 'tableaux/F3/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<Map<String, dynamic>> rows, List<int> temperatures) {
    final headerSize = _baseHeaderSize + temperatures.length * 2;
    final rowSize = _baseRowSize + temperatures.length * 4;

    final bytes = Uint8List(headerSize + rows.length * rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x46, 0x33, 0x54, 0x42]); // F3TB
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    data.setUint8(offset, temperatures.length);
    offset += 1;

    for (final temp in temperatures) {
      data.setInt16(offset, temp, Endian.little);
      offset += 2;
    }

    for (final row in rows) {
      final distance = _requireNum(row, 'distance').toDouble();
      final tirMontagne = row['tirMontagne'];

      if (tirMontagne is! bool) {
        throw FormatException(
          'Champ F3 booléen invalide "tirMontagne" : $tirMontagne',
        );
      }

      data.setFloat32(offset, distance, Endian.little);
      offset += 4;

      var flags = 0;
      if (tirMontagne) {
        flags |= _flagTirMontagne;
      }

      data.setUint8(offset, flags);
      offset += 1;

      final corrParTemp = row['corrParTemp'];
      if (corrParTemp is! Map<String, dynamic>) {
        throw FormatException('Champ F3 "corrParTemp" invalide : $row');
      }

      for (final temp in temperatures) {
        final key = temp.toString();
        final value = corrParTemp[key];

        if (value is! num) {
          throw FormatException(
            'Correction F3 manquante ou invalide temp=$key : $value',
          );
        }

        data.setFloat32(offset, value.toDouble(), Endian.little);
        offset += 4;
      }
    }

    return bytes;
  }

  void _validateRows(List<Map<String, dynamic>> rows, List<int> temperatures) {
    if (rows.isEmpty) {
      throw FormatException('F3TBL vide');
    }

    bool? currentMode;
    double? previousDistance;
    int direction = 0;

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      final distance = _requireNum(row, 'distance').toDouble();

      if (distance < 0 || distance > 100000) {
        throw FormatException('F3TBL row[$i] distance hors plage : $distance');
      }

      final tirMontagne = row['tirMontagne'];
      if (tirMontagne is! bool) {
        throw FormatException(
          'F3TBL row[$i] tirMontagne invalide : $tirMontagne',
        );
      }

      final corrParTemp = row['corrParTemp'];
      if (corrParTemp is! Map<String, dynamic>) {
        throw FormatException(
          'F3TBL row[$i] corrParTemp invalide : $corrParTemp',
        );
      }

      for (final temp in temperatures) {
        final key = temp.toString();
        final value = corrParTemp[key];

        if (value is! num) {
          throw FormatException(
            'F3TBL row[$i] correction temp=$key invalide : $value',
          );
        }
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
          'F3TBL tri invalide row[$i] : distance=$distance après '
          '$previousDistance pour tirMontagne=$tirMontagne',
        );
      }

      previousDistance = distance;
    }
  }

  num _requireNum(Map<String, dynamic> row, String field) {
    final value = row[field];

    if (value is! num) {
      throw FormatException('Champ F3 numérique invalide "$field" : $value');
    }

    return value;
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
