import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../table_builder.dart';

class HtblBuilder implements TableBuilder {
  static const String format = 'HTBL_V1';
  static const String extension = 'htbl.gz';

  @override
  bool supports(File input) {
    final name = input.uri.pathSegments.last;
    return name.startsWith('Tableau_H_') && name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File input, Directory outputRoot) async {
    final fileName = input.uri.pathSegments.last;
    final raw = await input.readAsString();

    if (raw.trim().isEmpty) {
      throw FormatException('Le fichier $fileName est vide.');
    }

    final decoded = jsonDecode(raw);
    final id = _idFromFileName(fileName);
    final isLatitude = _isLatitudeFile(fileName);

    if (isLatitude) {
      final bytes = _buildLatitudeTable(decoded, fileName);
      final gzipped = gzip.encode(bytes);

      final outFile = File('${outputRoot.path}/H/$id.$extension');
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(gzipped);

      final rows = decoded is Map ? decoded.length : 0;

      print('ID : $id');
      print('Format : $format');
      print('Rows : $rows');
      print('HTBL : ${bytes.length} bytes');
      print('GZIP : ${gzipped.length} bytes');

      return {
        'id': id,
        'format': format,
        'path': 'tableaux/H/$id.$extension',
        'rows': rows,
        'bytes': bytes.length,
        'gzipBytes': gzipped.length,
      };
    }

    final rows = _extractRows(decoded, fileName);
    _validateRows(rows, fileName);

    final bytes = _buildMainTable(rows);
    final gzipped = gzip.encode(bytes);

    final outFile = File('${outputRoot.path}/H/$id.$extension');
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(gzipped);

    print('ID : $id');
    print('Format : $format');
    print('Rows : ${rows.length}');
    print('HTBL : ${bytes.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': id,
      'format': format,
      'path': 'tableaux/H/$id.$extension',
      'rows': rows.length,
      'bytes': bytes.length,
      'gzipBytes': gzipped.length,
    };
  }

  bool _isLatitudeFile(String fileName) {
    return fileName == 'Tableau_H_FacteurLatitude.json' ||
        fileName == 'Tableau_H_FactuerLatitude.json';
  }

  String _idFromFileName(String fileName) {
    var base = fileName;

    if (base.endsWith('.json')) {
      base = base.substring(0, base.length - '.json'.length);
    }

    if (base.startsWith('Tableau_')) {
      base = base.substring('Tableau_'.length);
    }

    if (base == 'H_FactuerLatitude') {
      base = 'H_FacteurLatitude';
    }

    return base.toUpperCase();
  }

  List<Map<String, dynamic>> _extractRows(dynamic decoded, String fileName) {
    if (decoded is List) {
      return decoded
          .cast<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final rows = decoded['rows'] ?? decoded['data'];

      if (rows is List) {
        return rows
            .cast<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      }
    }

    throw FormatException(
      'Le fichier $fileName doit contenir une liste JSON ou un objet avec "rows" pour HTBL_V1.',
    );
  }

  Uint8List _buildLatitudeTable(dynamic decoded, String fileName) {
    if (decoded is! Map) {
      throw FormatException(
        'Le fichier $fileName doit contenir un objet JSON latitude -> facteur.',
      );
    }

    final entries = decoded.entries.map((entry) {
      final latitude = int.tryParse(entry.key.toString());
      final factor = entry.value;

      if (latitude == null) {
        throw FormatException(
          'Latitude invalide dans $fileName : ${entry.key}',
        );
      }

      if (factor is! num) {
        throw FormatException(
          'Facteur latitude invalide dans $fileName pour $latitude : $factor',
        );
      }

      return MapEntry(latitude, factor.toDouble());
    }).toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final builder = BytesBuilder();

    builder.add(ascii.encode('HTBL'));
    builder.addByte(1);
    builder.addByte(1); // subtype 1 = facteur latitude
    _writeUint16(builder, entries.length);

    for (final entry in entries) {
      _writeInt16(builder, entry.key);
      _writeFloat32(builder, entry.value);
    }

    return builder.toBytes();
  }

  Uint8List _buildMainTable(List<Map<String, dynamic>> rows) {
    final correctionKeys = _extractCorrectionKeys(rows);

    final builder = BytesBuilder();

    builder.add(ascii.encode('HTBL'));
    builder.addByte(1);
    builder.addByte(0); // subtype 0 = table H principale
    _writeUint16(builder, rows.length);
    _writeUint16(builder, correctionKeys.length);

    for (final key in correctionKeys) {
      _writeUint16(builder, key);
    }

    for (final row in rows) {
      _writeFloat32(builder, _requireNum(row, 'distance').toDouble());
      builder.addByte(_requireBool(row, 'tirMontagne') ? 1 : 0);

      for (final key in correctionKeys) {
        _writeFloat32(builder, _requireNum(row, key.toString()).toDouble());
      }
    }

    return builder.toBytes();
  }

  List<int> _extractCorrectionKeys(List<Map<String, dynamic>> rows) {
    final keys = <int>{};

    for (final row in rows) {
      for (final key in row.keys) {
        if (key == 'distance' || key == 'tirMontagne') {
          continue;
        }

        final parsed = int.tryParse(key);
        if (parsed != null) {
          keys.add(parsed);
        }
      }
    }

    final sorted = keys.toList()..sort();

    if (sorted.isEmpty) {
      throw const FormatException('HTBL aucune colonne numérique trouvée.');
    }

    return sorted;
  }

  void _validateRows(List<Map<String, dynamic>> rows, String fileName) {
    if (rows.isEmpty) {
      throw FormatException('HTBL vide : $fileName');
    }

    final correctionKeys = _extractCorrectionKeys(rows);

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];

      try {
        _requireNum(row, 'distance');
        _requireBool(row, 'tirMontagne');

        for (final key in correctionKeys) {
          _requireNum(row, key.toString());
        }
      } on FormatException catch (e) {
        throw FormatException('HTBL $fileName row[$i] : ${e.message}');
      }
    }
  }

  num _requireNum(Map<String, dynamic> row, String key) {
    final value = row[key];

    if (value is num) {
      return value;
    }

    throw FormatException(
      'champ obligatoire numérique invalide "$key" : $value',
    );
  }

  bool _requireBool(Map<String, dynamic> row, String key) {
    final value = row[key];

    if (value is bool) {
      return value;
    }

    throw FormatException('champ obligatoire booléen invalide "$key" : $value');
  }

  void _writeUint16(BytesBuilder builder, int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
  }

  void _writeInt16(BytesBuilder builder, int value) {
    final data = ByteData(2)..setInt16(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
  }

  void _writeFloat32(BytesBuilder builder, double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
  }
}
