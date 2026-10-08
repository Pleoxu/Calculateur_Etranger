import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../table_builder.dart';

class JtblBuilder implements TableBuilder {
  static const String format = 'JTBL_V1';
  static const String extension = 'jtbl.gz';

  static const List<String> _fields = [
    'correctionV0Moins',
    'correctionV0Plus',
    'correctionVentMoins',
    'correctionVentPlus',
    'correctionTempMoins',
    'correctionTempPlus',
    'correctionPressionMoins',
    'correctionPressionPlus',
    'correctionMasseMoins',
    'correctionMassePlus',
  ];

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toUpperCase();
    return RegExp(r'^(TABLEAU_)?(MO_|MEPAC_)?J_.*\.JSON$').hasMatch(name);
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final tableId = _buildTableId(filename);
    final outputName = '$tableId.$extension';

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      throw FormatException('Le fichier $filename est vide.');
    }

    final decoded = jsonDecode(raw);
    final rows = _extractRows(decoded, filename);

    if (rows.isEmpty) {
      throw FormatException('JTBL vide : $filename');
    }

    _validateRows(rows, filename);

    final binary = _encode(rows, tableId.startsWith('JBIS_') ? 1 : 0);
    final gzipped = gzip.encode(binary);

    final folder = tableId.startsWith('JBIS_') ? 'Jbis' : 'J';
    final outFile = File('${outputDir.path}/$folder/$outputName');

    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : $format');
    print('Rows : ${rows.length}');
    print('JTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'format': format,
      'path': 'tableaux/$folder/$outputName',
      'rows': rows.length,
      'bytes': binary.length,
      'gzipBytes': gzipped.length,
    };
  }

  String _buildTableId(String filename) {
    var base = filename;

    if (base.endsWith('.json')) {
      base = base.substring(0, base.length - '.json'.length);
    }

    if (base.startsWith('Tableau_')) {
      base = base.substring('Tableau_'.length);
    }

    return base.toUpperCase();
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded, String filename) {
    final List<dynamic> decodedRows;

    if (decoded is List) {
      decodedRows = decoded;
    } else if (decoded is Map<String, dynamic> && decoded['rows'] is List) {
      decodedRows = decoded['rows'] as List;
    } else if (decoded is Map<String, dynamic> && decoded['data'] is List) {
      decodedRows = decoded['data'] as List;
    } else {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON ou un objet avec "rows"/"data" pour JTBL_V1.',
      );
    }

    return decodedRows
        .cast<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _validateRows(List<Map<String, dynamic>> rows, String filename) {
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      _requireNum(row, 'tempage', filename, i);

      for (final field in _fields) {
        _requireNum(row, field, filename, i);
      }
    }
  }

  num _requireNum(
    Map<String, dynamic> row,
    String key,
    String filename,
    int index,
  ) {
    final value = row[key];

    if (value is num) return value;

    throw FormatException(
      'JTBL champ numérique invalide "$key" dans $filename row[$index] : $value',
    );
  }

  Uint8List _encode(List<Map<String, dynamic>> rows, int subtype) {
    final builder = BytesBuilder();

    builder.add(ascii.encode('JTBL'));
    builder.addByte(1);
    builder.addByte(subtype); // 0 = J, 1 = Jbis
    _writeUint32(builder, rows.length);

    for (final row in rows) {
      _writeFloat32(builder, _requireNum(row, 'tempage', 'JTBL', 0).toDouble());

      for (final field in _fields) {
        _writeFloat32(builder, _requireNum(row, field, 'JTBL', 0).toDouble());
      }
    }

    return builder.toBytes();
  }

  void _writeUint32(BytesBuilder builder, int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
  }

  void _writeFloat32(BytesBuilder builder, double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
  }
}
