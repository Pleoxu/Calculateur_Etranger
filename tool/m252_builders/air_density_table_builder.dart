import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../binary_utils.dart';
import '../table_builder.dart';

/// Profil d'une table de correction air/température/densité encodée sur :
///   int16 delta_alt_m, int16 dc_tb_pct × 10, int16 dc_pb_pct × 10.
///
/// Le profil sépare la lettre fonctionnelle d'une table (`B`, `D`, etc.) de
/// son identité de registre, de son format, de son magic binaire et de sa
/// sortie. Cela évite qu'une table étrangère B réemploie le vrai format BTBL.
class AirDensityTableProfile {
  const AirDensityTableProfile({
    required this.platform,
    required this.registryId,
    required this.tableId,
    required this.format,
    required this.binaryExtension,
    required this.magic,
    required this.sourceFileNames,
    this.isForeign = false,
  });

  final String registryId;
  final String platform;
  final String tableId;
  final String format;
  final String binaryExtension;
  final List<int> magic;
  final List<String> sourceFileNames;
  final bool isForeign;

  String get outputName => '$tableId.$binaryExtension.gz';

  String get directory =>
      isForeign ? 'foreign/${platform.toLowerCase()}/$tableId' : tableId;

  String get manifestPath => 'tableaux/$directory/$outputName';

  bool supportsName(String name) {
    final normalizedName = name.toLowerCase();
    final isM252ChargeProfile = platform == 'M252' &&
        tableId == 'B' &&
        RegExp(
          r'^m252_m821_m734_ch[0-4]_table_b\.json$',
        ).hasMatch(normalizedName);
    return isM252ChargeProfile ||
        sourceFileNames
            .map((fileName) => fileName.toLowerCase())
            .contains(normalizedName);
  }
}

/// Règle de nommage : lettre de table + E (étrangère) + BTL.
/// - DTBL_V1 reste réservé à la table D CAESAR historique ;
/// - BTBL_V1 reste réservé au véritable builder B ;
/// - BEBTL_V1 est réservé aux tables B étrangères qui utilisent ce codec.
///
/// Le magic BEBT est sur quatre octets pour préserver l'en-tête :
/// magic[4], version[1], nombre de lignes[uint32].
class AirDensityTableProfiles {
  const AirDensityTableProfiles._();

  static const caesarD = AirDensityTableProfile(
    registryId: 'D',
    platform: 'CAESAR',
    tableId: 'D',
    format: 'DTBL_V1',
    binaryExtension: 'dtbl',
    magic: [0x44, 0x54, 0x42, 0x4C], // DTBL
    sourceFileNames: ['tableau_d.json', 'd.json', 'tableau_d_caesar.json'],
  );

  static const m252B = AirDensityTableProfile(
    registryId: 'foreign.m252.B',
    platform: 'M252',
    tableId: 'B',
    format: 'BEBTL_V1',
    binaryExtension: 'bebtl',
    magic: [0x42, 0x45, 0x42, 0x54], // BEBT
    sourceFileNames: [
      'm252_m821_part6_ch3_table_b.json',
      'm252_m821_m734_ch3_table_b.json',
      'm252_m821_m734_ch0_table_b.json',
      'm252_table_b_air_temp_density_corrections.json',
      'tableau_b_m252.json',
    ],
    isForeign: true,
  );

  /// Profil prêt pour ATOLL. Conserver ce schéma uniquement si son JSON expose
  /// les mêmes trois clés et la même échelle que le profil M252.
  static const atollB = AirDensityTableProfile(
    registryId: 'foreign.atoll.B',
    platform: 'ATOLL',
    tableId: 'B',
    format: 'BEBTL_V1',
    binaryExtension: 'bebtl',
    magic: [0x42, 0x45, 0x42, 0x54], // BEBT
    sourceFileNames: [
      'atoll_table_b_air_temp_density_corrections.json',
      'tableau_b_atoll.json',
    ],
    isForeign: true,
  );
}

/// Codec unique pour le schéma air/température/densité.
///
/// Il produit DTBL pour le profil D CAESAR et BEBT/BEBTL_V1 pour les profils
/// étrangers. Un lecteur BEBTL_V1 vérifie le magic BEBT puis réutilise le même
/// décodage de ligne que le lecteur DTBL_V1.
class AirDensityTableBuilder implements TableBuilder {
  AirDensityTableBuilder(this.profile);

  static const _headerSize = 9;
  static const _rowSize = 6;

  final AirDensityTableProfile profile;

  @override
  bool supports(File file) {
    return profile.supportsName(file.uri.pathSegments.last);
  }

  @override
  Future<Map<String, dynamic>> build(File file, Directory outputDir) async {
    final filename = file.uri.pathSegments.last;
    final decoded = jsonDecode(await file.readAsString());

    if (decoded is! List) {
      throw FormatException(
        'Le fichier $filename doit contenir une liste JSON pour '
        '${profile.format}.',
      );
    }

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < decoded.length; index++) {
      final row = decoded[index];
      if (row is! Map<String, dynamic>) {
        throw FormatException(
          'Ligne ${index + 1} invalide dans $filename : objet JSON attendu.',
        );
      }
      rows.add(row);
    }

    final binary = _encode(rows);
    final gzipped = gzip.encode(binary);

    final outputFile = File(
      '${outputDir.path}/${profile.directory}/'
      '${profile.outputName}',
    );
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(gzipped);

    print('ID de registre : ${profile.registryId}');
    print('Table source : ${profile.tableId}');
    print('Plateforme : ${profile.platform}');
    print('Format : ${profile.format}');
    print('Rows : ${rows.length}');
    print('${ascii.decode(profile.magic)} : ${binary.length} bytes');
    print('GZIP : ${gzipped.length} bytes');

    return {
      'id': profile.registryId,
      'tableId': profile.tableId,
      'family': profile.isForeign ? 'foreign' : profile.tableId,
      'platform': profile.platform,
      'format': profile.format,
      'rows': rows.length,
      'file': profile.manifestPath,
      'keyVersion': 0,
    };
  }

  Uint8List _encode(List<Map<String, dynamic>> rows) {
    final bytes = Uint8List(_headerSize + rows.length * _rowSize);
    final data = ByteData.sublistView(bytes);

    var offset = 0;
    writeMagic(bytes, profile.magic);
    offset += 4;

    data.setUint8(offset, 1);
    offset += 1;

    data.setUint32(offset, rows.length, Endian.little);
    offset += 4;

    var previousDeltaAlt = -32769;

    for (final row in rows) {
      final deltaAlt = readScaled1(row, 'delta_alt_m');
      final dcTb = readScaled10(row, 'dc_tb_pct');
      final dcPb = readScaled10(row, 'dc_pb_pct');

      checkRange('delta_alt_m', deltaAlt, -32768, 32767);
      checkRange('dc_tb_pct', dcTb, -32768, 32767);
      checkRange('dc_pb_pct', dcPb, -32768, 32767);

      if (deltaAlt % 10 != 0) {
        throw FormatException('delta_alt_m non multiple de 10 : $deltaAlt');
      }

      if (deltaAlt <= previousDeltaAlt) {
        throw FormatException(
          'delta_alt_m non trié : $previousDeltaAlt -> $deltaAlt',
        );
      }
      previousDeltaAlt = deltaAlt;

      data.setInt16(offset, deltaAlt, Endian.little);
      offset += 2;

      data.setInt16(offset, dcTb, Endian.little);
      offset += 2;

      data.setInt16(offset, dcPb, Endian.little);
      offset += 2;
    }

    return bytes;
  }
}

/// Exemple d'enregistrement :
///
/// final builders = <TableBuilder>[
///   AirDensityTableBuilder(AirDensityTableProfiles.caesarD),
///   AirDensityTableBuilder(AirDensityTableProfiles.m252B),
///   AirDensityTableBuilder(AirDensityTableProfiles.atollB),
/// ];
///
/// Sorties :
///   tableaux/D/D.dtbl.gz
///   tableaux/foreign/m252/B/B.bebtl.gz
///   tableaux/foreign/atoll/B/B.bebtl.gz
