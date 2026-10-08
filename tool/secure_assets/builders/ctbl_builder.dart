import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class CtblBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 6;

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();

    return name == 'tableau_c.json' ||
        name == 'c.json' ||
        name.contains('tableau_c');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    const tableId = 'C';
    const outputName = 'C.ctbl.gz';

    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour CTBL_V1.',
      );
    }

    final entries = decoded.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    final binary = _encode(entries);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/C/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : CTBL_V1');
    print('Rows : ${entries.length}');
    print('CTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'C',
      'format': 'CTBL_V1',
      'rows': entries.length,
      'file': 'tableaux/C/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<MapEntry<String, dynamic>> entries) {
    final bytes = Uint8List(_headerSize + entries.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x43, 0x54, 0x42, 0x4C]); // CTBL
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, entries.length, Endian.little);
    offset += 4;

    var previousAngle = -1;

    for (final entry in entries) {
      final angle = int.parse(entry.key);

      if (entry.value is! Map<String, dynamic>) {
        throw FormatException(
          'Entrée CTBL invalide pour angle $angle : ${entry.value}',
        );
      }

      final values = entry.value as Map<String, dynamic>;

      final wz = readScaled100(values, 'Wz');
      final wx = readScaled100(values, 'Wx');

      checkRange('angle', angle, 0, 6400);
      checkRange('Wz', wz, 0, 100);
      checkRange('Wx', wx, 0, 100);

      if (angle % 100 != 0) {
        throw FormatException('Angle CTBL non multiple de 100 : $angle');
      }

      if (angle <= previousAngle) {
        throw FormatException(
          'Angles CTBL non triés : $previousAngle -> $angle',
        );
      }

      previousAngle = angle;

      data.setUint16(offset, angle, Endian.little);
      offset += 2;

      data.setUint16(offset, wz, Endian.little);
      offset += 2;

      data.setUint16(offset, wx, Endian.little);
      offset += 2;
    }

    return bytes;
  }
}
