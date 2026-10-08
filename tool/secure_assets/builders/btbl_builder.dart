import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class BtblBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 8;

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith('Tableau_B_') && name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;

    final tableId = _buildTableId(filename);
    final outputName = '$tableId.btbl.gz';

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON pour BTBL_V1.',
      );
    }

    final rows = decoded.cast<Map<String, dynamic>>();

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/B/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : BTBL_V1');
    print('Rows : ${rows.length}');
    print('BTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'B',
      'variant': _extractVariant(filename),
      'charge': _extractCharge(filename),
      'format': 'BTBL_V1',
      'rows': rows.length,
      'file': 'tableaux/B/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final bytes = Uint8List(_headerSize + rows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x42, 0x54, 0x42, 0x4C]); // BTBL
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    for (final row in rows) {
      final distance = readInt(row, 'distance');
      final denivelee = readInt(row, 'denivelee');
      final correctionSite = readInt(row, 'correctionSite');
      final niveauMeteo = readInt(row, 'niveauMeteo');
      final tirMontagne = readBool(row, 'tirMontagne');

      checkRange('distance', distance, 0, 65535);
      checkRange('denivelee', denivelee, -32768, 32767);
      checkRange('correctionSite', correctionSite, -32768, 32767);
      checkRange('niveauMeteo', niveauMeteo, 0, 255);

      var flags = 0;

      if (tirMontagne) {
        flags |= 0x01;
      }

      data.setUint16(offset, distance, Endian.little);
      offset += 2;

      data.setInt16(offset, denivelee, Endian.little);
      offset += 2;

      data.setInt16(offset, correctionSite, Endian.little);
      offset += 2;

      data.setUint8(offset, niveauMeteo);
      offset += 1;

      data.setUint8(offset, flags);
      offset += 1;
    }

    return bytes;
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
