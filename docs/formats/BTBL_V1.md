import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';
import '../table_naming.dart';

class BtblBuilder implements TableBuilder {
static const _headerSize = 9;
static const _rowSize = 8;

@override
bool supports(File file) {
final name = file.uri.pathSegments.last.toUpperCase();

    return RegExp(
      r'^(TABLEAU_B_|MO_B_|MEPAC_B_).+\.JSON$',
    ).hasMatch(name);
}

@override
Future<Map<String, dynamic>> build(
File file,
Directory outputDir,
) async {
final filename = file.uri.pathSegments.last;
final tableId = TableNaming.buildTableId(filename);
final outputName = '$tableId.btbl.gz';
final subDir = _subDirectory(tableId);

    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON pour BTBL_V1.',
      );
    }

    final rows = decoded
        .cast<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File(
      '${outputDir.path}/$subDir/$outputName',
    );

    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(
      gzipped,
      flush: true,
    );

    print('ID : $tableId');
    print('Format : BTBL_V1');
    print('Rows : ${rows.length}');
    print('BTBL : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'family': 'B',
      'variant': TableNaming.extractVariant(filename),
      'charge': TableNaming.extractCharge(filename),
      'format': 'BTBL_V1',
      'rows': rows.length,
      'file': 'tableaux/$subDir/$outputName',
      'keyVersion': 0,
    };
}

String _subDirectory(String tableId) {
if (tableId.startsWith('MO_')) {
return 'MO/B';
}

    if (tableId.startsWith('MEPAC_')) {
      return 'MEPAC/B';
    }

    return 'B';
}

Uint8List _encode(
List<Map<String, dynamic>> rows,
) {
final bytes = Uint8List(
_headerSize + rows.length * _rowSize,
);

    final data = ByteData.sublistView(bytes);

    var offset = 0;

    writeMagic(
      bytes,
      [0x42, 0x54, 0x42, 0x4C],
    ); // BTBL
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(
      offset,
      rows.length,
      Endian.little,
    );
    offset += 4;

    for (final row in rows) {
      final distance = readInt(row, 'distance');
      final denivelee = readInt(row, 'denivelee');
      final correctionSite = readInt(
        row,
        'correctionSite',
      );
      final niveauMeteo = readInt(
        row,
        'niveauMeteo',
      );
      final tirMontagne = readBool(
        row,
        'tirMontagne',
      );

      checkRange(
        'distance',
        distance,
        0,
        65535,
      );
      checkRange(
        'denivelee',
        denivelee,
        -32768,
        32767,
      );
      checkRange(
        'correctionSite',
        correctionSite,
        -32768,
        32767,
      );
      checkRange(
        'niveauMeteo',
        niveauMeteo,
        0,
        255,
      );

      var flags = 0;

      if (tirMontagne) {
        flags |= 0x01;
      }

      data.setUint16(
        offset,
        distance,
        Endian.little,
      );
      offset += 2;

      data.setInt16(
        offset,
        denivelee,
        Endian.little,
      );
      offset += 2;

      data.setInt16(
        offset,
        correctionSite,
        Endian.little,
      );
      offset += 2;

      data.setUint8(
        offset,
        niveauMeteo,
      );
      offset += 1;

      data.setUint8(
        offset,
        flags,
      );
      offset += 1;
    }

    return bytes;
}
}
