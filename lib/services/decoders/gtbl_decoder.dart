import 'dart:convert';
import 'dart:typed_data';

import '../../models/charge_selection_models.dart';

class GtblDecoder {
  static const int _headerSize = 9;
  static const int _rowSizeV1 = 17;
  static const int _rowSizeV2 = 55;
  static const int _flagTirMontagne = 1 << 0;

  const GtblDecoder();

  TableauGTable decode(
    Uint8List bytes, {
    required String typeTir,
    required String charge,
    String? sourcePath,
    String? designation,
  }) {
    final resolvedDesignation = designation ?? sourcePath ?? 'Tableau G';

    if (bytes.length < _headerSize) {
      throw const FormatException('[TableauG] GTBL trop court.');
    }

    final data = ByteData.sublistView(bytes);

    var offset = 0;

    String readMagic() {
      final value = ascii.decode(bytes.sublist(offset, offset + 4));

      offset += 4;

      return value;
    }

    int readUint8() {
      final value = data.getUint8(offset);

      offset += 1;

      return value;
    }

    int readUint16() {
      final value = data.getUint16(offset, Endian.little);

      offset += 2;

      return value;
    }

    int readUint32() {
      final value = data.getUint32(offset, Endian.little);

      offset += 4;

      return value;
    }

    double readFloat32() {
      final value = data.getFloat32(offset, Endian.little);

      offset += 4;

      return value;
    }

    final magic = readMagic();

    if (magic != 'GTBL') {
      throw FormatException(
        '[TableauG] Invalid magic'
        '${sourcePath == null ? '' : ' in $sourcePath'} : $magic',
      );
    }

    final version = readUint8();
    final rowCount = readUint32();

    if (rowCount == 0) {
      throw FormatException(
        '[TableauG] No lines in GTBL file'
        '${sourcePath == null ? '' : ' in $sourcePath'}.',
      );
    }

    final rowSize = switch (version) {
      1 => _rowSizeV1,
      2 => _rowSizeV2,
      _ => throw FormatException(
          '[TableauG] Unsupported version'
          '${sourcePath == null ? '' : ' in $sourcePath'} : $version',
        ),
    };

    final expectedSize = _headerSize + rowCount * rowSize;

    if (bytes.length != expectedSize) {
      throw FormatException(
        '[TableauG] Invalid size'
        '${sourcePath == null ? '' : ' in $sourcePath'} : '
        '${bytes.length} octets, '
        '$expectedSize attendus '
        '($_headerSize + $rowCount × $rowSize).',
      );
    }

    void validateFinite(double value, String field, int rowIndex) {
      if (!value.isFinite) {
        throw FormatException(
          '[TableauG] Incomplete value for $field at line $rowIndex'
          '${sourcePath == null ? '' : ' in $sourcePath'} : $value',
        );
      }
    }

    final rows = <TableauGRow>[];

    for (var index = 0; index < rowCount; index++) {
      final rowStart = offset;

      final distance = readFloat32();
      final hausse = readFloat32();

      var ecartProbablePortee = 0.0;
      var ecartProbableDirection = 0.0;
      var ecartProbableHauteurEclatement = 0.0;
      var ecartProbableDelaiEclatement = 0.0;
      var ecartProbablePorteeEclatement = 0.0;

      var angleChute = 0.0;
      var cotangenteAngleChute = 0.0;
      var vitesseRestante = 0.0;
      var fleche = 0.0;

      if (version == 2) {
        ecartProbablePortee = readFloat32();
        ecartProbableDirection = readFloat32();
        ecartProbableHauteurEclatement = readFloat32();
        ecartProbableDelaiEclatement = readFloat32();
        ecartProbablePorteeEclatement = readFloat32();

        angleChute = readFloat32();
        cotangenteAngleChute = readFloat32();
        vitesseRestante = readFloat32();
        fleche = readFloat32();
      }

      final correctionPlus = readFloat32();
      final correctionMoins = readFloat32();

      final flags = readUint8();

      if (version == 2) {
        readUint16();
      }

      final decodedRowSize = offset - rowStart;

      validateFinite(distance, 'distance', index);
      validateFinite(hausse, 'hausse', index);
      validateFinite(correctionPlus, 'correctionPlus', index);
      validateFinite(correctionMoins, 'correctionMoins', index);

      if (version == 2) {
        validateFinite(ecartProbablePortee, 'ecartProbablePortee', index);
        validateFinite(ecartProbableDirection, 'ecartProbableDirection', index);
        validateFinite(
          ecartProbableHauteurEclatement,
          'ecartProbableHauteurEclatement',
          index,
        );
        validateFinite(
          ecartProbableDelaiEclatement,
          'ecartProbableDelaiEclatement',
          index,
        );
        validateFinite(
          ecartProbablePorteeEclatement,
          'ecartProbablePorteeEclatement',
          index,
        );
        validateFinite(angleChute, 'angleChute', index);
        validateFinite(cotangenteAngleChute, 'cotangenteAngleChute', index);
        validateFinite(vitesseRestante, 'vitesseRestante', index);
        validateFinite(fleche, 'fleche', index);
      }

      if (decodedRowSize != rowSize) {
        throw FormatException(
          '[TableauG] Invalid size for row $index'
          '${sourcePath == null ? '' : ' in $sourcePath'} : '
          '$decodedRowSize bytes instead of $rowSize.',
        );
      }

      rows.add(
        TableauGRow(
          distance: distance,
          hausse: hausse,
          ecartProbablePortee: ecartProbablePortee,
          ecartProbableDirection: ecartProbableDirection,
          ecartProbableHauteurEclatement: ecartProbableHauteurEclatement,
          ecartProbableDelaiEclatement: ecartProbableDelaiEclatement,
          ecartProbablePorteeEclatement: ecartProbablePorteeEclatement,
          angleChute: angleChute,
          cotangenteAngleChute: cotangenteAngleChute,
          vitesseRestante: vitesseRestante,
          fleche: fleche,
          correctionComplementSiteAnglePlus: correctionPlus,
          correctionComplementSiteAngleMoins: correctionMoins,
          tirMontagne: (flags & _flagTirMontagne) != 0,
        ),
      );
    }

    // Les lignes sont triées une seule fois ici.
    // Les services d'interpolation peuvent ensuite supposer cet ordre.
    rows.sort((first, second) => first.distance.compareTo(second.distance));

    return TableauGTable(
      meta: TableauGMeta(
        typeTir: typeTir,
        charge: charge,
        tableau: 'G',
        designation: resolvedDesignation,
      ),
      rows: List<TableauGRow>.unmodifiable(rows),
    );
  }
}
