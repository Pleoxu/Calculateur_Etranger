import 'dart:convert';
import 'dart:typed_data';

class EtblRow {
  final double tempPoudre;
  final double deltaVoTemp;

  const EtblRow({required this.tempPoudre, required this.deltaVoTemp});
}

class EtblData {
  final int version;
  final double? v0Tabulaire;
  final double deltaVPerCarreau;
  final List<EtblRow> rows;

  const EtblData({
    required this.version,
    required this.v0Tabulaire,
    required this.deltaVPerCarreau,
    required this.rows,
  });
}

class EtblDecoder {
  static EtblData decode(Uint8List bytes) {
    if (bytes.length < 10) {
      throw FormatException('ETBL trop court');
    }

    final magic = ascii.decode(bytes.sublist(0, 4));
    if (magic != 'ETBL') {
      throw FormatException('Invalid ETBL magic: $magic');
    }

    final bd = ByteData.sublistView(bytes);

    final version = bd.getUint8(4);
    final rowsCount = bd.getUint8(5);

    // offsets validés avec tools/read_etbl.dart
    final int v0Raw = bd.getInt16(8, Endian.big);

    final double? v0Tab = (v0Raw > 0 && v0Raw < 2000) ? v0Raw.toDouble() : null;

    const int dataOffset = 10;
    const int rowSize = 4;

    final rows = <EtblRow>[];

    for (int i = 0; i < rowsCount; i++) {
      final o = dataOffset + i * rowSize;

      final int tempRaw = bd.getInt16(o, Endian.big);
      final int deltaRaw = bd.getInt16(o + 2, Endian.big);

      // FORMAT VALIDÉ PAR read_etbl.dart
      final double temp = tempRaw / 6.4;
      final double delta = deltaRaw / 10.0;

      rows.add(EtblRow(tempPoudre: temp, deltaVoTemp: delta));
    }

    return EtblData(
      version: version,
      v0Tabulaire: v0Tab,
      deltaVPerCarreau: -2.6,
      rows: rows,
    );
  }
}
