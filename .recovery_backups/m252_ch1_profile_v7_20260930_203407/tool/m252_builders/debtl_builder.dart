import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

/// Builder de la table D étrangère M252, normalisée sur le schéma de lignes F.
///
/// DEBTL_V2 signifie : table D étrangère M252. Le magic DEBT tient sur
/// quatre octets afin de conserver l'en-tête existant :
/// magic[4], version[1], nombre de lignes[uint32].
///
/// Chaque ligne garde la disposition binaire FTBL (75 octets). Les quatre bits
/// de poids fort des flags portent la colonne doctrinale `LINE NO.` (0..15),
/// tandis que les deux derniers octets portent `nombreToursPar100m` (uint16).
class DebtlBuilder implements TableBuilder {
  static const _headerSize = 9;
  static const _rowSize = 75;
  static const _version = 2;
  static const _flagTirMontagne = 0x01;
  static const _weatherLineShift = 4;

  static const _validBits = <String, int>{
    'dAE_per_100m': 0,
    'correctionV0Moins': 1,
    'correctionV0Plus': 2,
    'correctionVentMoins': 3,
    'correctionVentPlus': 4,
    'correctionTempMoins': 5,
    'correctionTempPlus': 6,
    'correctionPressionMoins': 7,
    'correctionPressionPlus': 8,
    'correctionMasseMoins': 9,
    'correctionMassePlus': 10,
  };

  static const _optionalFields = <String>{
    'dAE_per_100m',
    'correctionV0Moins',
    'correctionV0Plus',
    'correctionVentMoins',
    'correctionVentPlus',
    'correctionTempMoins',
    'correctionTempPlus',
    'correctionPressionMoins',
    'correctionPressionPlus',
    'correctionMasseMoins',
    'correctionMassePlus',
  };

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    return name == 'm252_m821_part6_ch3_table_d.json' ||
        name == 'm252_m821_m734_ch3_table_d.json' ||
        name == 'm252_m821a1_table_d_ch3.json' ||
        name == 'm252_m821_m734_ch0_table_d.json' ||
        name == 'm252_table_d_ch3.json' ||
        name == 'tableau_d_m252_ch3.json';
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());
    final sourceRows = _readSourceRows(decoded, filename);
    final rows = _normalizeRows(sourceRows);

    _computeVarHausse(rows);
    _validateRows(rows);

    final charge = _extractCharge(filename);
    final tableId = 'foreign.m252.D.CH$charge';
    final outputName = 'D_CH$charge.debtl.gz';
    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/foreign/m252/D/$outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID de registre : $tableId');
    print('Table source : D');
    print('Plateforme : M252');
    print('Format : DEBTL_V2');
    print('Charge : CH$charge');
    print('Rows : ${rows.length}');
    print('DEBT : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': tableId,
      'tableId': 'D',
      'family': 'foreign',
      'platform': 'M252',
      'charge': charge,
      'format': 'DEBTL_V2',
      'rows': rows.length,
      'file': 'tableaux/foreign/m252/D/$outputName',
      'keyVersion': 0,
    };
  }

  List<Map<String, dynamic>> _readSourceRows(dynamic decoded, String filename) {
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
          'Ligne D M252 ${index + 1} invalide : objet JSON attendu.',
        );
      }
      rows.add(row);
    }
    return rows;
  }

  /// Mappe les noms M252 vers le contrat de ligne F.
  ///
  /// `derive` n'existe pas dans la source M252 : 0.0 est la valeur neutre.
  /// `tirMontagne` n'est pas fourni : false.
  /// Les corrections de masse n'existent pas : null + bits de validité absents.
  /// Les tours sont conservés ; 1 est injecté uniquement quand ils sont absents.
  List<Map<String, dynamic>> _normalizeRows(
    List<Map<String, dynamic>> sourceRows,
  ) {
    return [
      for (final source in sourceRows)
        {
          'distance': source['distance'],
          'hausse': source['hausse'],
          'derive': 0.0,
          'correctionWz': source['correctionWz'],
          'dAE_per_100m': source['dAE_per_100m'],
          'nombreToursPar100m': _readTurnsOrDefault(source),
          'ligneMeteo': _readWeatherLine(source),
          'correctionV0Moins':
              source['correctionV0Moins'] ?? source['correctionV0Dec'],
          'correctionV0Plus':
              source['correctionV0Plus'] ?? source['correctionV0Inc'],
          'correctionVentMoins':
              source['correctionVentMoins'] ?? source['correctionVentFace'],
          'correctionVentPlus':
              source['correctionVentPlus'] ?? source['correctionVentArriere'],
          'correctionTempMoins':
              source['correctionTempMoins'] ?? source['correctionTempAirDec'],
          'correctionTempPlus':
              source['correctionTempPlus'] ?? source['correctionTempAirInc'],
          'correctionPressionMoins': source['correctionPressionMoins'] ??
              source['correctionDensiteAirDec'],
          'correctionPressionPlus': source['correctionPressionPlus'] ??
              source['correctionDensiteAirInc'],
          'correctionMasseMoins': null,
          'correctionMassePlus': null,
          'tirMontagne': false,
          'tempageS': source['tempageS'],
          'varHaussePour100m': null,
        },
    ];
  }

  int _readWeatherLine(Map<String, dynamic> source) {
    // `niveauMeteo` est le nom de la colonne LINE NO. dans le recueil CH0.
    // Sa valeur est encodée telle quelle dans le DEBTL : aucun défaut ou
    // calcul de substitution n'est admis.
    final value = source['ligneMeteo'] ?? source['niveauMeteo'];
    if (value is int && value >= 0 && value <= 15) return value;
    if (value is num &&
        value.isFinite &&
        value == value.round() &&
        value >= 0 &&
        value <= 15) {
      return value.toInt();
    }
    throw FormatException('ligneMeteo invalide : $value');
  }

  int _readTurnsOrDefault(Map<String, dynamic> source) {
    final value = source['nombreToursPar100m'];
    if (value == null) {
      return 1;
    }
    if (value is int && value >= 1 && value <= 65535) {
      return value;
    }
    if (value is num &&
        value.isFinite &&
        value == value.round() &&
        value >= 1 &&
        value <= 65535) {
      return value.toInt();
    }
    throw FormatException('nombreToursPar100m invalide : $value');
  }

  void _computeVarHausse(List<Map<String, dynamic>> rows) {
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row['varHaussePour100m'] != null) {
        continue;
      }
      if (index + 1 == rows.length) {
        row['varHaussePour100m'] = 0.0;
        continue;
      }

      final next = rows[index + 1];
      final distance = _asNum(row, 'distance').toDouble();
      final hausse = _asNum(row, 'hausse').toDouble();
      final nextDistance = _asNum(next, 'distance').toDouble();
      final nextHausse = _asNum(next, 'hausse').toDouble();
      final deltaDistance = (nextDistance - distance).abs();

      if (deltaDistance <= 0.0001) {
        row['varHaussePour100m'] = 0.0;
      } else {
        row['varHaussePour100m'] =
            ((nextHausse - hausse).abs() / deltaDistance) * 100.0;
      }
    }
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final bytes = Uint8List(_headerSize + rows.length * _rowSize);
    final data = ByteData.sublistView(bytes);
    var offset = 0;

    writeMagic(bytes, [0x44, 0x45, 0x42, 0x54]); // DEBT
    offset += 4;
    data.setUint8(offset, _version);
    offset += 1;
    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    for (final row in rows) {
      void writeFloat(String field, {bool required = true}) {
        final value = row[field];
        if (value == null) {
          if (required) {
            throw FormatException('Champ DEBTL obligatoire manquant "$field"');
          }
          data.setFloat32(offset, 0.0, Endian.little);
          offset += 4;
          return;
        }
        if (value is! num) {
          throw FormatException('Champ DEBTL numérique invalide "$field"');
        }
        data.setFloat32(offset, value.toDouble(), Endian.little);
        offset += 4;
      }

      writeFloat('distance');
      writeFloat('hausse');
      writeFloat('derive');
      writeFloat('correctionWz');
      writeFloat('dAE_per_100m', required: false);
      writeFloat('correctionV0Moins', required: false);
      writeFloat('correctionV0Plus', required: false);
      writeFloat('correctionVentMoins', required: false);
      writeFloat('correctionVentPlus', required: false);
      writeFloat('correctionTempMoins', required: false);
      writeFloat('correctionTempPlus', required: false);
      writeFloat('correctionPressionMoins', required: false);
      writeFloat('correctionPressionPlus', required: false);
      writeFloat('correctionMasseMoins', required: false);
      writeFloat('correctionMassePlus', required: false);
      writeFloat('tempageS');
      writeFloat('varHaussePour100m');

      if (row['tirMontagne'] is! bool) {
        throw FormatException('Champ DEBTL booléen tirMontagne invalide');
      }
      var flags = 0;
      if (row['tirMontagne'] as bool) {
        flags |= _flagTirMontagne;
      }
      final ligneMeteo = row['ligneMeteo'];
      if (ligneMeteo is! int || ligneMeteo < 0 || ligneMeteo > 15) {
        throw FormatException('ligneMeteo invalide dans la ligne DEBTL');
      }
      flags |= ligneMeteo << _weatherLineShift;
      data.setUint8(offset, flags);
      offset += 1;

      var validMask = 0;
      for (final entry in _validBits.entries) {
        if (row[entry.key] != null) {
          validMask |= 1 << entry.value;
        }
      }
      data.setUint32(offset, validMask, Endian.little);
      offset += 4;

      // En FTBL, ces deux octets sont réservés. En DEBTL, ils stockent les
      // tours par 100 m et permettent la réutilisation de la disposition F.
      data.setUint16(offset, row['nombreToursPar100m'] as int, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  void _validateRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) {
      throw FormatException('DEBTL vide');
    }

    double? previousDistance;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      for (final field in [
        'distance',
        'hausse',
        'derive',
        'correctionWz',
        'tempageS',
        'varHaussePour100m',
      ]) {
        _asNum(row, field);
      }
      for (final field in _optionalFields) {
        final value = row[field];
        if (value != null && value is! num) {
          throw FormatException('Champ DEBTL optionnel invalide $field');
        }
      }
      if (row['tirMontagne'] is! bool) {
        throw FormatException('tirMontagne invalide à la ligne $index');
      }
      final turns = row['nombreToursPar100m'];
      if (turns is! int || turns < 1 || turns > 65535) {
        throw FormatException('nombreToursPar100m invalide à la ligne $index');
      }
      final ligneMeteo = row['ligneMeteo'];
      if (ligneMeteo is! int || ligneMeteo < 0 || ligneMeteo > 15) {
        throw FormatException('ligneMeteo invalide à la ligne $index');
      }

      final distance = _asNum(row, 'distance').toDouble();
      if (distance < 0 || distance > 100000) {
        throw FormatException('distance hors plage à la ligne $index');
      }
      if (previousDistance != null && distance <= previousDistance) {
        throw FormatException(
          'distances DEBTL non croissantes à la ligne $index',
        );
      }
      previousDistance = distance;
    }
  }

  num _asNum(Map<String, dynamic> row, String field) {
    final value = row[field];
    if (value is! num) {
      throw FormatException('Champ DEBTL numérique requis invalide $field');
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

/// Sortie : tableaux/foreign/m252/D/D_CH3.debtl.gz
///
/// Le lecteur DEBTL_V2 vérifie le magic DEBT, la version 2, les flags et les
/// 2 derniers octets de chaque ligne (`nombreToursPar100m`).
