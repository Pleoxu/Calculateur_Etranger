import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

/// Builder du tableau C étranger M252 : température de poudre / effet sur Vo.
///
/// CEBTL_V1 signifie : table C + E (étrangère) + BTL. Son magic est CEBT,
/// limité à quatre octets afin de conserver l'en-tête :
/// magic[4], version[1], nombre de lignes[uint32].
///
/// Les températures stockées sont les degrés Fahrenheit de la table source,
/// car le M252 les indexe à 5 °F. tempPoudreC est validé à l'import mais non
/// encodé : il peut être recalculé depuis tempPoudreF.
class CebtlBuilder implements TableBuilder {
  CebtlBuilder.m252()
      : platform = 'M252',
        sourceFileNames = const [
          'm252_m821a1_table_c_ch3.json',
          'm252_m821_m734_ch0_table_c.json',
          'm252_table_c.json',
          'tableau_c_m252.json',
        ];

  static const _headerSize = 9;
  static const _rowSize = 4;
  static const _magic = [0x43, 0x45, 0x42, 0x54]; // CEBT

  final String platform;
  final List<String> sourceFileNames;

  String get _platformKey => platform.toLowerCase();

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    return sourceFileNames.contains(name);
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour CEBTL_V1.',
      );
    }

    final meta = decoded['meta'];
    if (meta is! Map<String, dynamic>) {
      throw FormatException('Meta CEBTL invalide dans $filename');
    }
    _validateUnits(meta['unites']);

    final data = decoded['data'];
    if (data is! List) {
      throw FormatException('Data CEBTL invalide dans $filename');
    }

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < data.length; index++) {
      final row = data[index];
      if (row is! Map<String, dynamic>) {
        throw FormatException(
          'Ligne CEBTL ${index + 1} invalide dans $filename : objet attendu.',
        );
      }
      rows.add(row);
    }

    final charge = _extractCharge(meta['charge'] ?? filename);
    final variant = _extractVariant(meta['typeTir']);
    final registryId = 'foreign.$_platformKey.C.CH$charge';
    final outputName = 'C_CH$charge.cebtl.gz';

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File(
      '${outputDir.path}/foreign/$_platformKey/C/$outputName',
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID de registre : $registryId');
    print('Table source : C');
    print('Plateforme : $platform');
    print('Format : CEBTL_V1');
    print('Charge : CH$charge');
    print('Rows : ${rows.length}');
    print('CEBT : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': registryId,
      'tableId': 'C',
      'family': 'foreign',
      'platform': platform,
      'variant': variant,
      'charge': charge,
      'format': 'CEBTL_V1',
      'rows': rows.length,
      'temperatureUnit': 'F',
      'file': 'tableaux/foreign/$_platformKey/C/$outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final sortedRows = [...rows]..sort(
        (a, b) => readScaled1(
          a,
          'tempPoudreF',
        ).compareTo(readScaled1(b, 'tempPoudreF')),
      );

    final bytes = Uint8List(_headerSize + sortedRows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;
    writeMagic(bytes, _magic);
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, sortedRows.length, Endian.little);
    offset += 4;

    var previousTempF = -32769;

    for (final row in sortedRows) {
      final tempPoudreF = readScaled1(row, 'tempPoudreF');
      final tempPoudreC = readScaled10(row, 'tempPoudreC');
      final deltaVoTemp = readScaled10(row, 'deltaVo_temp');

      checkRange('tempPoudreF', tempPoudreF, -32768, 32767);
      checkRange('tempPoudreC', tempPoudreC, -32768, 32767);
      checkRange('deltaVo_temp', deltaVoTemp, -32768, 32767);

      if (tempPoudreF % 5 != 0) {
        throw FormatException('tempPoudreF non multiple de 5 : $tempPoudreF');
      }

      // Les degrés C de la source sont arrondis au dixième ; tolérance ±0,1 °C.
      final expectedTempC = ((tempPoudreF - 32) * 50 / 9).round();
      if ((tempPoudreC - expectedTempC).abs() > 1) {
        throw FormatException(
          'tempPoudreC incohérente pour $tempPoudreF °F : '
          '${tempPoudreC / 10} °C',
        );
      }

      if (tempPoudreF <= previousTempF) {
        throw FormatException(
          'tempPoudreF non triée : $previousTempF -> $tempPoudreF',
        );
      }
      previousTempF = tempPoudreF;

      data.setInt16(offset, tempPoudreF, Endian.little);
      offset += 2;

      data.setInt16(offset, deltaVoTemp, Endian.little);
      offset += 2;
    }

    return bytes;
  }

  void _validateUnits(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['tempPoudreF'] != '°F' ||
        value['tempPoudreC'] != '°C' ||
        value['deltaVo_temp'] != 'm/s') {
      throw FormatException(
        'Unités CEBTL invalides : °F, °C et m/s sont requis.',
      );
    }
  }

  String _extractVariant(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('typeTir CEBTL invalide : $value');
    }
    return value.trim().toUpperCase();
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
    throw FormatException('charge CEBTL invalide : $value');
  }
}

/// Enregistrement recommandé :
///
/// final builders = <TableBuilder>[
///   // Builder C natif existant : inchangé.
///   CebtlBuilder.m252(), // C M252, CEBTL_V1
/// ];
///
/// Sortie : tableaux/foreign/m252/C/C_CH3.cebtl.gz
