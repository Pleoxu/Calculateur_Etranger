import 'dart:typed_data';

import 'btbl_table.dart';

class BtblDecoder {
  static const int _headerSize = 9;
  static const int _rowSize = 8;

  BtblTable decode({required String id, required Uint8List bytes}) {
    if (bytes.length < _headerSize) {
      throw const FormatException('Invalid BTBL: incomplete header.');
    }

    final data = ByteData.sublistView(bytes);

    final magic = String.fromCharCodes(bytes.sublist(0, 4));
    if (magic != 'BTBL') {
      throw FormatException('Invalid BTBL magic: $magic');
    }

    final version = data.getUint8(4);
    if (version != 1) {
      throw FormatException('BTBL version not supported: $version');
    }

    final rowCount = data.getUint32(5, Endian.little);
    final expectedSize = _headerSize + rowCount * _rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        'Invalid BTBL size: ${bytes.length}, expected: $expectedSize',
      );
    }

    final rows = <BtblRow>[];
    var offset = _headerSize;

    for (var i = 0; i < rowCount; i++) {
      final distance = data.getUint16(offset, Endian.little);
      offset += 2;

      final denivelee = data.getInt16(offset, Endian.little);
      offset += 2;

      final correctionSite = data.getInt16(offset, Endian.little);
      offset += 2;

      final niveauMeteo = data.getUint8(offset);
      offset += 1;

      final flags = data.getUint8(offset);
      offset += 1;

      if ((flags & 0xFE) != 0) {
        throw FormatException('Reserved BTBL flags used at line $i.');
      }

      rows.add(
        BtblRow(
          distance: distance,
          denivelee: denivelee,
          correctionSite: correctionSite,
          niveauMeteo: niveauMeteo,
          tirMontagne: (flags & 0x01) != 0,
        ),
      );
    }

    return BtblTable(id: id, rows: rows);
  }
}
