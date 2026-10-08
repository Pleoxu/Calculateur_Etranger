import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class DtblBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 6;

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();

    return name == 'tableau_d.json' ||
        name == 'd.json' ||
        name.contains('tableau_d');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    const tableId = 'D';
    const outputName = 'D.dtbl.gz';

    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON pour DTBL_V1.',
      );
    }

    final rows = decoded.cast<Map<String, dynamic>>();

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/D/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : DTBL_V1');
    print('Rows : ${rows.length}');
    print('DTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'D',
      'format': 'DTBL_V1',
      'rows': rows.length,
      'file': 'tableaux/D/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final bytes = Uint8List(_headerSize + rows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x44, 0x54, 0x42, 0x4C]); // DTBL
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    var previousDeltaAlt = -32769;

    for (final row in rows) {
      final deltaAlt = readScaled1(row, 'delta_alt_m');
      final dcTb = readScaled10(row, 'dc_tb_pct');
      final dcPb = readScaled10(row, 'dc_pb_pct');

      checkRange('delta_alt_m', deltaAlt, -32768, 32767);
      checkRange('dc_tb_pct', dcTb, -32768, 32767);
      checkRange('dc_pb_pct', dcPb, -32768, 32767);

      if (deltaAlt % 10 != 0) {
        throw FormatException('delta_alt_m non multiple de 10 : $deltaAlt');
      }

      if (deltaAlt <= previousDeltaAlt) {
        throw FormatException(
          'delta_alt_m non trié : $previousDeltaAlt -> $deltaAlt',
        );
      }

      previousDeltaAlt = deltaAlt;

      data.setInt16(offset, deltaAlt, Endian.little);
      offset += 2;

      data.setInt16(offset, dcTb, Endian.little);
      offset += 2;

      data.setInt16(offset, dcPb, Endian.little);
      offset += 2;
    }

    return bytes;
  }
}
