import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

class EtblBuilder implements TableBuilder {
  static const _headerSize = 11;
  static const _rowSize = 4;

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();

    return name.startsWith('tableau_e_') &&
        !name.startsWith('tableau_ecl_') &&
        name.endsWith('.json');
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour ETBL_V1.',
      );
    }

    final meta = decoded['meta'];

    if (meta is! Map<String, dynamic>) {
      throw FormatException('Meta ETBL invalide dans $filename');
    }

    final data = decoded['data'];

    if (data is! List) {
      throw FormatException('Data ETBL invalide dans $filename');
    }

    final rows = data.cast<Map<String, dynamic>>();

    final variant = _extractVariant(filename, meta['typeTir']);
    final charge = _extractCharge(meta['charge'] ?? filename);

    final tableId = 'E_${variant}_CH$charge';
    final outputName = '$tableId.etbl.gz';

    final binary = _encode(meta, rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/E/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID : $tableId');
    print('Format : ETBL_V1');
    print('Rows : ${rows.length}');
    print('ETBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'E',
      'variant': variant,
      'charge': charge,
      'format': 'ETBL_V1',
      'rows': rows.length,
      'file': 'tableaux/E/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(
    Map<String, dynamic> meta,
    List<Map<String, dynamic>> rows,
  ) {
    final sortedRows = [...rows]..sort(
        (a, b) => readScaled1(
          a,
          'tempPoudre',
        ).compareTo(readScaled1(b, 'tempPoudre')),
      );

    final bytes = Uint8List(_headerSize + sortedRows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(bytes, [0x45, 0x54, 0x42, 0x4C]); // ETBL
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, sortedRows.length, Endian.little);
    offset += 4;

    final deltaVPerCarreau = readScaled10(meta, 'deltaV_per_carreau_ms');
    checkRange('deltaV_per_carreau_ms', deltaVPerCarreau, -32768, 32767);

    data.setInt16(offset, deltaVPerCarreau, Endian.little);
    offset += 2;

    var previousTemp = -32769;

    for (final row in sortedRows) {
      final tempPoudre = readScaled1(row, 'tempPoudre');
      final deltaVoTemp = readScaled10(row, 'deltaVo_temp');

      checkRange('tempPoudre', tempPoudre, -32768, 32767);
      checkRange('deltaVo_temp', deltaVoTemp, -32768, 32767);

      if (tempPoudre <= previousTemp) {
        throw FormatException(
          'tempPoudre non triée : $previousTemp -> $tempPoudre',
        );
      }

      previousTemp = tempPoudre;

      data.setInt16(offset, tempPoudre, Endian.little);
      offset += 2;

      data.setInt16(offset, deltaVoTemp, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  String _extractVariant(String filename, dynamic metaTypeTir) {
    final upper = filename.toUpperCase();

    if (upper.contains('_APPUIRTC_')) {
      return 'APPUIRTC';
    }

    if (upper.contains('_APPUI_')) {
      return 'APPUI';
    }

    if (upper.contains('_OECL_')) {
      return 'OECL';
    }

    return _normalizeVariant(metaTypeTir);
  }

  String _normalizeVariant(dynamic value) {
    if (value is! String) {
      throw FormatException('typeTir invalide : $value');
    }

    final normalized = value.trim().toUpperCase();

    switch (normalized) {
      case 'APPUI':
        return 'APPUI';
      case 'APPUIRTC':
        return 'APPUIRTC';
      case 'OECL':
        return 'OECL';
      default:
        throw FormatException('typeTir non supporté : $value');
    }
  }

  int _extractCharge(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is String) {
      final match = RegExp(r'CH(\d+)').firstMatch(value.toUpperCase());

      if (match != null) {
        return int.parse(match.group(1)!);
      }
    }

    throw FormatException('charge invalide : $value');
  }
}
