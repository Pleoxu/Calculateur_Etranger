import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../table_builder.dart';

class JbistblBuilder implements TableBuilder {
  static const String format = 'JBISTBL_V1';
  static const String extension = 'jbistbl.gz';

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toUpperCase();
    return RegExp(r'^(TABLEAU_)?(MO_|MEPAC_)?JBIS_.*\.JSON$').hasMatch(name);
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
    final temperatures = _extractTemperatures(decoded, filename);
    final rows = _extractRows(decoded, filename);

    _validateRows(rows, temperatures, filename);

    final records = rows
        .map(
          (row) => _JbistblRecord(
            tempage: _requireNum(row, 'tempage', filename).toDouble(),
            corrections: temperatures.map((temp) {
              final corrParTemp = row['corrParTemp'] as Map;
              final value = corrParTemp[temp.toString()];
              if (value is! num) {
                throw FormatException(
                  'JBISTBL correction invalide température $temp dans $filename : $value',
                );
              }
              return value.toDouble();
            }).toList(),
          ),
        )
        .toList();

    records.sort((a, b) => a.tempage.compareTo(b.tempage));

    final binary = _encode(records, temperatures);
    final gzipped = gzip.encode(binary);

    final outFile = File('${outputDir.path}/Jbis/$outputName');
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : $format');
    print('Rows : ${records.length}');
    print('Temperatures : $temperatures');
    print('JBISTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'format': format,
      'path': 'tableaux/Jbis/$outputName',
      'rows': records.length,
      'temperatures': temperatures,
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

  List<int> _extractTemperatures(dynamic decoded, String filename) {
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour JBISTBL_V1.',
      );
    }

    final meta = decoded['meta'];
    if (meta is! Map) {
      throw FormatException('JBISTBL meta invalide dans $filename.');
    }

    final temps = meta['temperaturesC'];
    if (temps is! List || temps.isEmpty) {
      throw FormatException(
        'JBISTBL temperaturesC invalide dans $filename : $temps',
      );
    }

    return temps.map((value) {
      if (value is! num) {
        throw FormatException(
          'JBISTBL température invalide dans $filename : $value',
        );
      }
      return value.toInt();
    }).toList();
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded, String filename) {
    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour JBISTBL_V1.',
      );
    }

    final data = decoded['data'] ?? decoded['rows'];
    if (data is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir "data" ou "rows" pour JBISTBL_V1.',
      );
    }

    return data.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void _validateRows(
    List<Map<String, dynamic>> rows,
    List<int> temperatures,
    String filename,
  ) {
    if (rows.isEmpty) {
      throw FormatException('JBISTBL vide : $filename');
    }

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      _requireNum(row, 'tempage', filename);

      final corrParTemp = row['corrParTemp'];
      if (corrParTemp is! Map) {
        throw FormatException(
          'JBISTBL corrParTemp invalide dans $filename row[$i] : $corrParTemp',
        );
      }

      for (final temp in temperatures) {
        final value = corrParTemp[temp.toString()];
        if (value is! num) {
          throw FormatException(
            'JBISTBL champ corrParTemp[$temp] invalide dans $filename row[$i] : $value',
          );
        }
      }
    }
  }

  num _requireNum(Map<String, dynamic> row, String key, String filename) {
    final value = row[key];
    if (value is num) return value;

    throw FormatException(
      'JBISTBL champ numérique invalide "$key" dans $filename : $value',
    );
  }

  Uint8List _encode(List<_JbistblRecord> records, List<int> temperatures) {
    final builder = BytesBuilder();

    builder.add(ascii.encode('JBIS'));
    builder.addByte(1);
    builder.addByte(temperatures.length);
    _writeUint32(builder, records.length);

    for (final temp in temperatures) {
      _writeInt16(builder, temp);
    }

    for (final record in records) {
      _writeFloat32(builder, record.tempage);
      for (final correction in record.corrections) {
        _writeFloat32(builder, correction);
      }
    }

    return builder.toBytes();
  }

  void _writeInt16(BytesBuilder builder, int value) {
    final data = ByteData(2)..setInt16(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
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

class _JbistblRecord {
  const _JbistblRecord({required this.tempage, required this.corrections});

  final double tempage;
  final List<double> corrections;
}
