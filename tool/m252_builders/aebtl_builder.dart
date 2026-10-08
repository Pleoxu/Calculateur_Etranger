import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

/// Builder des tables A étrangères de composantes de vent.
///
/// AEBTL_V1 signifie : table A + E (étrangère) + BTL. Son magic est AEBT,
/// limité à quatre octets afin de conserver l'en-tête binaire actuel :
/// magic[4], version[1], nombre de lignes[uint32]. AEBTL_V1 reste distinct
/// du vrai format ATBL_V1, réservé à la table A native.
class AebtlBuilder implements TableBuilder {
  AebtlBuilder.m252()
      : platform = 'M252',
        sourceFileNames = const [
          'm252_m821_part6_ch3_table_a.json',
          'm252_m821_m734_ch3_table_a.json',
          'm252_m821_m734_ch0_table_a.json',
          'm252_table_a_wind_components.json',
          'tableau_a_m252.json',
        ];

  /// Préconfiguré mais à activer seulement après validation d'un JSON ATOLL.
  AebtlBuilder.atoll()
      : platform = 'ATOLL',
        sourceFileNames = const [
          'atoll_table_a_wind_components.json',
          'tableau_a_atoll.json',
        ];

  static const _headerSize = 9;
  static const _rowSize = 6;
  static const _magic = [0x41, 0x45, 0x42, 0x54]; // AEBT

  final String platform;
  final List<String> sourceFileNames;

  String get _platformKey => platform.toLowerCase();
  String get _registryId => 'foreign.$_platformKey.A';
  String get _directory => 'foreign/$_platformKey/A';
  String get _outputName => 'A.aebtl.gz';

  @override
  bool supports(File file) {
    final name = file.uri.pathSegments.last.toLowerCase();
    return sourceFileNames.contains(name) ||
        RegExp(r'^m252_m821_m734_ch[0-4]_table_a\.json$').hasMatch(name);
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Le fichier $filename doit contenir un objet JSON pour AEBTL_V1.',
      );
    }

    final entries = decoded.entries.toList()
      ..sort((a, b) => int.parse(a.key).compareTo(int.parse(b.key)));

    final binary = _encode(entries);
    final gzipped = gzip.encode(binary);

    final outputFile = File('${outputDir.path}/$_directory/$_outputName');
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID de registre : $_registryId');
    print('Table source : A');
    print('Plateforme : $platform');
    print('Format : AEBTL_V1');
    print('Rows : ${entries.length}');
    print('AEBT : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': _registryId,
      'tableId': 'A',
      'family': 'foreign',
      'platform': platform,
      'format': 'AEBTL_V1',
      'rows': entries.length,
      'file': 'tableaux/$_directory/$_outputName',
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<MapEntry<String, dynamic>> entries) {
    final bytes = Uint8List(_headerSize + entries.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;
    writeMagic(bytes, _magic);
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, entries.length, Endian.little);
    offset += 4;

    var previousAngle = -1;

    for (final entry in entries) {
      final angle = int.parse(entry.key);

      if (entry.value is! Map<String, dynamic>) {
        throw FormatException(
          'Entrée AEBTL invalide pour angle $angle : ${entry.value}',
        );
      }
      final values = entry.value as Map<String, dynamic>;

      final wz = readScaled100(values, 'Wz');
      final wx = readScaled100(values, 'Wx');

      checkRange('angle', angle, 0, 6400);
      checkRange('Wz', wz, 0, 100);
      checkRange('Wx', wx, 0, 100);

      if (angle % 100 != 0) {
        throw FormatException('Angle AEBTL non multiple de 100 : $angle');
      }

      if (angle <= previousAngle) {
        throw FormatException(
          'Angles AEBTL non triés : $previousAngle -> $angle',
        );
      }
      previousAngle = angle;

      data.setUint16(offset, angle, Endian.little);
      offset += 2;

      data.setUint16(offset, wz, Endian.little);
      offset += 2;

      data.setUint16(offset, wx, Endian.little);
      offset += 2;
    }

    return bytes;
  }
}

/// Enregistrement recommandé :
///
/// final builders = <TableBuilder>[
///   // Builder A natif existant : ATBL_V1 (inchangé).
///   AebtlBuilder.m252(),
///   // Ajouter seulement après validation de la structure ATOLL :
///   AebtlBuilder.atoll(),
/// ];
///
/// Sorties :
///   tableaux/foreign/m252/A/A.aebtl.gz
///   tableaux/foreign/atoll/A/A.aebtl.gz
