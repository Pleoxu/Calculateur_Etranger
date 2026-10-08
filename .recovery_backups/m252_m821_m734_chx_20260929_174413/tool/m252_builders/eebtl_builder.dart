import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

/// Builder de la table E étrangère M252.
///
/// EEBTL_V1 suit la disposition de ligne de GTBL_V2 (55 octets) pour les
/// données balistiques de portée/hausse, mais possède son propre magic EEBT
/// et sa propre identité de registre. GTBL_V2 reste donc réservé à la table G
/// native.
class EebtlBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 55;
  static const _flagTirMontagne = 0x01;
  static const _magic = <int>[0x45, 0x45, 0x42, 0x54]; // EEBT

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    return name == 'm252_m821a1_table_e_ch3.json' ||
        name == 'm252_m821_m734_ch0_table_e.json' ||
        name == 'm252_table_e_ch3.json' ||
        name == 'tableau_e_m252_ch3.json';
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());
    final data = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
            ? decoded['data']
            : null;

    if (data is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON ou un objet data[].',
      );
    }

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < data.length; index++) {
      final row = data[index];
      if (row is! Map<String, dynamic>) {
        throw FormatException(
          'Ligne E M252 ${index + 1} invalide : objet JSON attendu.',
        );
      }
      rows.add(row);
    }

    for (final row in rows) {
      // La Table E CH0 ne porte pas de colonne « tir montagne » : le profil
      // source est horizontal. L'absence est normalisée explicitement ici.
      row.putIfAbsent('tirMontagne', () => false);
    }
    _validateAndSort(rows);
    final hasUnpublishedRangeError =
        rows.any((row) => row['ecartProbablePortee'] == null);
    final version = hasUnpublishedRangeError ? 2 : 1;

    final charge = _extractCharge(filename);
    final outputName = 'E_CH$charge.eebtl.gz';
    final binary = _encode(rows, version: version);
    final gzipped = gzip.encode(binary);
    final outputFile = File('${outputDir.path}/foreign/m252/E/$outputName');

    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped, flush: true);

    return <String, dynamic>{
      'id': 'foreign.m252.E.CH$charge',
      'tableId': 'E',
      'family': 'foreign',
      'platform': 'M252',
      'charge': charge,
      'format': version == 1 ? 'EEBTL_V1' : 'EEBTL_V2',
      'rows': rows.length,
      'unpublishedProbableRangeRows': hasUnpublishedRangeError,
      'file': 'tableaux/foreign/m252/E/$outputName',
      'keyVersion': 0,
    };
  }

  void _validateAndSort(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      throw FormatException('EEBTL vide');
    }

    rows.sort((left, right) {
      final modeLeft = _readBool(left, 'tirMontagne') ? 1 : 0;
      final modeRight = _readBool(right, 'tirMontagne') ? 1 : 0;
      if (modeLeft != modeRight) return modeLeft.compareTo(modeRight);
      return _readNumber(
        left,
        'distance',
      ).compareTo(_readNumber(right, 'distance'));
    });

    bool? previousMode;
    double? previousDistance;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final distance = _readNumber(row, 'distance');
      final hausse = _readNumber(row, 'hausse');
      final epPortee = _readOptionalNumber(row, 'ecartProbablePortee');
      final epDirection = _readNumber(row, 'ecartProbableDirection');
      final angle = _readNumber(row, 'angleChuteMil');
      final cot = _readNumber(row, 'cotAngleChute');
      final mode = _readBool(row, 'tirMontagne');

      if (distance <= 0 ||
          hausse <= 0 ||
          (epPortee != null && epPortee <= 0) ||
          epDirection <= 0) {
        throw FormatException(
          'EEBTL ligne $index : distance/hausse/EP invalide',
        );
      }
      if (angle <= 0 || cot < 0) {
        throw FormatException('EEBTL ligne $index : angle/cotangente invalide');
      }
      if (previousMode == mode &&
          previousDistance != null &&
          distance <= previousDistance) {
        throw FormatException('EEBTL ligne $index : distances non croissantes');
      }
      previousMode = mode;
      previousDistance = distance;
    }
  }

  Uint8List _encode(List<Map<String, dynamic>> rows, {required int version}) {
    final bytes = Uint8List(_headerSize + rows.length * _rowSize);
    final data = ByteData.sublistView(bytes);
    var offset = 0;

    writeMagic(bytes, _magic);
    offset += 4;
    data.setUint8(offset, version);
    offset += 1;
    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    for (final row in rows) {
      void writeFloat(String field, {bool optional = false}) {
        final value = row[field];
        if (value == null) {
          if (!optional) {
            throw FormatException('EEBTL champ obligatoire manquant : $field');
          }
          data.setFloat32(offset, 0, Endian.little);
          offset += 4;
          return;
        }
        if (value is! num) {
          throw FormatException('EEBTL champ numérique invalide : $field');
        }
        data.setFloat32(offset, value.toDouble(), Endian.little);
        offset += 4;
      }

      writeFloat('distance');
      writeFloat('hausse');
      writeFloat('ecartProbablePortee', optional: true);
      writeFloat('ecartProbableDirection');
      writeFloat('ecartProbableHauteurEclatement', optional: true);
      writeFloat('ecartProbableDelaiEclatement', optional: true);
      writeFloat('ecartProbablePorteeEclatement', optional: true);
      writeFloat('angleChuteMil');
      writeFloat('cotAngleChute');
      writeFloat('vitesseRestante');
      writeFloat('fleche');
      writeFloat('correctionComplementSiteAnglePlus', optional: true);
      writeFloat('correctionComplementSiteAngleMoins', optional: true);

      final mode = _readBool(row, 'tirMontagne');
      var flags = mode ? _flagTirMontagne : 0;
      if (row['ecartProbablePortee'] == null) {
        // EEBTL_V2, bit 1 : écart probable de portée non publié dans le
        // document source. Le zéro encodé est donc explicitement indisponible.
        flags |= 0x02;
      }
      data.setUint8(offset, flags);
      offset += 1;
      data.setUint16(offset, 0, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  double _readNumber(Map<String, dynamic> row, String field) {
    final value = row[field];
    if (value is! num) {
      throw FormatException('EEBTL champ numérique requis invalide : $field');
    }
    return value.toDouble();
  }

  double? _readOptionalNumber(Map<String, dynamic> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! num) {
      throw FormatException('EEBTL champ numérique invalide : $field');
    }
    return value.toDouble();
  }

  bool _readBool(Map<String, dynamic> row, String field) {
    final value = row[field];
    if (value is! bool) {
      throw FormatException('EEBTL champ booléen requis invalide : $field');
    }
    return value;
  }

  int _extractCharge(String filename) {
    final match = RegExp(r'CH(\d+)').firstMatch(filename.toUpperCase());
    if (match == null) {
      throw FormatException('Charge CH<n> manquante dans $filename');
    }
    return int.parse(match.group(1)!);
  }
}
