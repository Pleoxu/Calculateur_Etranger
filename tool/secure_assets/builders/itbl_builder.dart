import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../table_builder.dart';

class ItblBuilder implements TableBuilder {
  static const String format = 'ITBL_V1';
  static const String extension = 'itbl.gz';

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith('Tableau_I_') && name.endsWith('.json');
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

    final records = _flattenRows(rows, filename);
    if (records.isEmpty) {
      throw FormatException('ITBL vide : $filename');
    }

    final binary = _encode(records);
    final gzipped = gzip.encode(binary);

    final outFile = File('${outputDir.path}/I/$outputName');
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : $format');
    print('Rows : ${records.length}');
    print('ITBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'format': format,
      'path': 'tableaux/I/$outputName',
      'rows': records.length,
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
    if (decoded is List) {
      return decoded
          .cast<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final rows = decoded['rows'] ?? decoded['data'];
      if (rows is List) {
        return rows
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }

    throw FormatException(
      'Le fichier $filename doit contenir une liste JSON ou un objet avec "rows" pour ITBL_V1.',
    );
  }

  List<_ItblRecord> _flattenRows(
    List<Map<String, dynamic>> rows,
    String filename,
  ) {
    final records = <_ItblRecord>[];

    for (var blockIndex = 0; blockIndex < rows.length; blockIndex++) {
      final block = rows[blockIndex];

      final tirMontagne = block['tirMontagne'];
      if (tirMontagne is! bool) {
        throw FormatException(
          'ITBL bloc[$blockIndex] tirMontagne invalide dans $filename : $tirMontagne',
        );
      }

      final data = block['data'];
      if (data is! Map) {
        throw FormatException(
          'ITBL bloc[$blockIndex] data invalide dans $filename : $data',
        );
      }

      for (final latEntry in data.entries) {
        final latitude = _parsePrefixedInt(
          latEntry.key.toString(),
          'latitude_',
          'latitude',
          filename,
        );

        final azimuts = latEntry.value;
        if (azimuts is! Map) {
          throw FormatException(
            'ITBL latitude_$latitude azimuts invalides dans $filename : $azimuts',
          );
        }

        for (final azEntry in azimuts.entries) {
          final azimut = _parsePrefixedInt(
            azEntry.key.toString(),
            'azimut_',
            'azimut',
            filename,
          );

          final distances = azEntry.value;
          if (distances is! Map) {
            throw FormatException(
              'ITBL latitude_$latitude azimut_$azimut distances invalides dans $filename : $distances',
            );
          }

          for (final distEntry in distances.entries) {
            final distance = double.tryParse(distEntry.key.toString());
            final correction = distEntry.value;

            if (distance == null) {
              throw FormatException(
                'ITBL distance invalide dans $filename : ${distEntry.key}',
              );
            }
            if (correction is! num) {
              throw FormatException(
                'ITBL correction invalide dans $filename latitude_$latitude azimut_$azimut distance=$distance : $correction',
              );
            }

            records.add(
              _ItblRecord(
                tirMontagne: tirMontagne,
                latitude: latitude,
                azimut: azimut,
                distance: distance,
                correction: correction.toDouble(),
              ),
            );
          }
        }
      }
    }

    records.sort((a, b) {
      final montagneCmp = (a.tirMontagne ? 1 : 0).compareTo(
        b.tirMontagne ? 1 : 0,
      );
      if (montagneCmp != 0) return montagneCmp;

      final latCmp = a.latitude.compareTo(b.latitude);
      if (latCmp != 0) return latCmp;

      final azCmp = a.azimut.compareTo(b.azimut);
      if (azCmp != 0) return azCmp;

      return a.distance.compareTo(b.distance);
    });

    return records;
  }

  int _parsePrefixedInt(
    String value,
    String prefix,
    String label,
    String filename,
  ) {
    if (!value.startsWith(prefix)) {
      throw FormatException('ITBL $label invalide dans $filename : $value');
    }

    final parsed = int.tryParse(value.substring(prefix.length));
    if (parsed == null) {
      throw FormatException('ITBL $label invalide dans $filename : $value');
    }

    return parsed;
  }

  Uint8List _encode(List<_ItblRecord> records) {
    final builder = BytesBuilder();

    builder.add(ascii.encode('ITBL'));
    builder.addByte(1);
    _writeUint32(builder, records.length);

    for (final record in records) {
      builder.addByte(record.tirMontagne ? 1 : 0);
      _writeInt16(builder, record.latitude);
      _writeUint16(builder, record.azimut);
      _writeFloat32(builder, record.distance);
      _writeFloat32(builder, record.correction);
    }

    return builder.toBytes();
  }

  void _writeUint16(BytesBuilder builder, int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    builder.add(data.buffer.asUint8List());
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

class _ItblRecord {
  const _ItblRecord({
    required this.tirMontagne,
    required this.latitude,
    required this.azimut,
    required this.distance,
    required this.correction,
  });

  final bool tirMontagne;
  final int latitude;
  final int azimut;
  final double distance;
  final double correction;
}
