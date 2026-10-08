import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class EclBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 13;

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    return name.startsWith('tableau_ecl_') && name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON pour ECLTBL_V1.',
      );
    }

    final rows = decoded.cast<Map<String, dynamic>>();

    final variant = _extractVariant(filename);
    final charge = _extractCharge(filename);
    final tableId = 'ECL_${variant}_CH$charge';
    final outputName = '$tableId.ecltbl.gz';

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/ECL/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : ECLTBL_V1');
    print('Rows : ${rows.length}');
    print('ECLTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'ECL',
      'variant': variant,
      'charge': charge,
      'format': 'ECLTBL_V1',
      'rows': rows.length,
      'file': 'tableaux/ECL/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final sortedRows = [...rows]..sort((a, b) {
        final am = readBool(a, 'tirMontagne') ? 1 : 0;
        final bm = readBool(b, 'tirMontagne') ? 1 : 0;

        if (am != bm) return am.compareTo(bm);

        final ap = readScaled1(a, 'portee_m');
        final bp = readScaled1(b, 'portee_m');

        return ap.compareTo(bp);
      });

    final bytes = Uint8List(_headerSize + sortedRows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x45, 0x43, 0x4C, 0x54]); // ECLT
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, sortedRows.length, Endian.little);
    offset += 4;

    var previousKey = '';

    for (final row in sortedRows) {
      final portee = readScaled1(row, 'portee_m');
      final hausse = readScaled100(row, 'hausse_mil');
      final corrHausse = readScaled100(row, 'corr_hausse_+50m_mil');
      final corrEvent = readScaled100(row, 'corr_event_+50m_mil');
      final tirMontagne = readBool(row, 'tirMontagne');

      checkRange('portee_m', portee, 0, 65535);
      checkRange('hausse_mil', hausse, -2147483648, 2147483647);
      checkRange('corr_hausse_+50m_mil', corrHausse, -32768, 32767);
      checkRange('corr_event_+50m_mil', corrEvent, -32768, 32767);

      var flags = 0;
      if (tirMontagne) {
        flags |= 0x01;
      }

      final key = '${tirMontagne ? 1 : 0}:$portee';

      if (key == previousKey) {
        throw FormatException(
          'Doublon ECL : tirMontagne=$tirMontagne portee=$portee',
        );
      }

      previousKey = key;

      data.setUint16(offset, portee, Endian.little);
      offset += 2;

      data.setInt32(offset, hausse, Endian.little);
      offset += 4;

      data.setInt16(offset, corrHausse, Endian.little);
      offset += 2;

      data.setInt16(offset, corrEvent, Endian.little);
      offset += 2;

      data.setUint8(offset, flags);
      offset += 1;

      data.setUint16(offset, 0, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  String _extractVariant(String filename) {
    final upper = filename.toUpperCase();

    if (upper.contains('_APPUIRTC_')) return 'APPUIRTC';
    if (upper.contains('_APPUI_')) return 'APPUI';
    if (upper.contains('_OECL_')) return 'OECL';

    throw FormatException('Variant ECL introuvable : $filename');
  }

  int _extractCharge(String filename) {
    final match = RegExp(r'CH(\d+)').firstMatch(filename.toUpperCase());

    if (match == null) {
      throw FormatException('Charge ECL introuvable : $filename');
    }

    return int.parse(match.group(1)!);
  }
}
