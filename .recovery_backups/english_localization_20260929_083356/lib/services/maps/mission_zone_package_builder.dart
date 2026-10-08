import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Construit un paquet autonome `.ctzone` à partir :
/// - d'un fichier MBTiles ;
/// - d'une emprise géographique ;
/// - des tuiles DEM `.f32` disponibles dans un dossier local.
///
/// Ce service ne télécharge rien : il est utilisable sur un poste de
/// préparation totalement séparé du terminal de mission.
class MissionZonePackageBuilder {
  const MissionZonePackageBuilder();

  static const String packageFormat = 'calculateur_tir_zone';
  static const int packageVersion = 1;

  /// Retourne les noms des tuiles DEM 1°×1° nécessaires pour couvrir
  /// l'emprise fournie.
  List<String> requiredDemFiles({
    required double west,
    required double south,
    required double east,
    required double north,
  }) {
    _validateBounds(
      west: west,
      south: south,
      east: east,
      north: north,
    );

    const epsilon = 1e-9;

    final minLon = west.floor();
    final maxLon = (east - epsilon).floor();
    final minLat = south.floor();
    final maxLat = (north - epsilon).floor();

    final result = <String>[];

    for (var lat = minLat; lat <= maxLat; lat++) {
      for (var lon = minLon; lon <= maxLon; lon++) {
        result.add('${_demLatitude(lat)}${_demLongitude(lon)}.f32');
      }
    }

    return result;
  }

  Future<MissionZoneBuildResult> build({
    required String name,
    required String mbtilesPath,
    required String demDirectoryPath,
    required String outputPath,
    required double west,
    required double south,
    required double east,
    required double north,
    String? description,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Le nom de zone est obligatoire.');
    }

    _validateBounds(
      west: west,
      south: south,
      east: east,
      north: north,
    );

    final mapFile = File(mbtilesPath);
    if (!await mapFile.exists()) {
      throw FileSystemException(
        'Fichier MBTiles introuvable',
        mbtilesPath,
      );
    }

    if (!mbtilesPath.toLowerCase().endsWith('.mbtiles')) {
      throw const FormatException(
        'Le fichier cartographique doit être un .mbtiles.',
      );
    }

    final demDirectory = Directory(demDirectoryPath);
    if (!await demDirectory.exists()) {
      throw FileSystemException(
        'Dossier DEM introuvable',
        demDirectoryPath,
      );
    }

    final requiredDem = requiredDemFiles(
      west: west,
      south: south,
      east: east,
      north: north,
    );

    final demFiles = <File>[];
    final missing = <String>[];

    for (final basename in requiredDem) {
      final file = File(p.join(demDirectory.path, basename));
      if (await file.exists()) {
        demFiles.add(file);
      } else {
        missing.add(basename);
      }
    }

    if (missing.isNotEmpty) {
      throw MissionZoneMissingDemException(missing);
    }

    final archive = Archive();

    final mapArchiveName =
        'map/${_safeArchiveBasename(p.basename(mapFile.path))}';

    final demArchiveNames = <String>[];

    final manifest = <String, dynamic>{
      'format': packageFormat,
      'version': packageVersion,
      'name': cleanName,
      'description':
          description?.trim().isNotEmpty == true ? description!.trim() : null,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'map': <String, dynamic>{
        'file': mapArchiveName,
      },
      'dem': <String, dynamic>{
        'files': <String>[],
      },
      'bounds': <String, dynamic>{
        'west': west,
        'south': south,
        'east': east,
        'north': north,
      },
    };

    final mapBytes = await mapFile.readAsBytes();
    archive.addFile(
      ArchiveFile(
        mapArchiveName,
        mapBytes.length,
        mapBytes,
      ),
    );

    var demBytesTotal = 0;

    for (final file in demFiles) {
      final basename = _safeArchiveBasename(p.basename(file.path));
      final archiveName = 'dem/$basename';
      final bytes = await file.readAsBytes();

      demArchiveNames.add(archiveName);
      demBytesTotal += bytes.length;

      archive.addFile(
        ArchiveFile(
          archiveName,
          bytes.length,
          bytes,
        ),
      );
    }

    (manifest['dem'] as Map<String, dynamic>)['files'] = demArchiveNames;

    manifest.removeWhere((_, value) => value == null);

    final manifestText = const JsonEncoder.withIndent('  ').convert(manifest);
    final manifestBytes = utf8.encode(manifestText);

    archive.addFile(
      ArchiveFile(
        'manifest.json',
        manifestBytes.length,
        manifestBytes,
      ),
    );

    final encoded = ZipEncoder().encode(archive);

    var finalOutputPath = outputPath.trim();
    if (finalOutputPath.isEmpty) {
      throw const FormatException('Chemin de sortie manquant.');
    }
    if (!finalOutputPath.toLowerCase().endsWith('.ctzone')) {
      finalOutputPath = '$finalOutputPath.ctzone';
    }

    final output = File(finalOutputPath);
    final parent = output.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    await output.writeAsBytes(encoded, flush: true);

    return MissionZoneBuildResult(
      outputPath: output.path,
      mapBytes: mapBytes.length,
      demBytes: demBytesTotal,
      packageBytes: await output.length(),
      demFiles: List.unmodifiable(requiredDem),
    );
  }

  void _validateBounds({
    required double west,
    required double south,
    required double east,
    required double north,
  }) {
    if (!west.isFinite ||
        !south.isFinite ||
        !east.isFinite ||
        !north.isFinite) {
      throw const FormatException('Emprise non numérique.');
    }

    if (west < -180 ||
        east > 180 ||
        south < -90 ||
        north > 90 ||
        west >= east ||
        south >= north) {
      throw const FormatException('Emprise géographique invalide.');
    }
  }

  String _demLatitude(int latitude) {
    final prefix = latitude >= 0 ? 'N' : 'S';
    return '$prefix${latitude.abs().toString().padLeft(2, '0')}';
  }

  String _demLongitude(int longitude) {
    final prefix = longitude >= 0 ? 'E' : 'W';
    return '$prefix${longitude.abs().toString().padLeft(3, '0')}';
  }

  String _safeArchiveBasename(String value) {
    final basename = p.basename(value).trim();
    if (basename.isEmpty ||
        basename == '.' ||
        basename == '..' ||
        basename.contains('/') ||
        basename.contains(r'\\')) {
      throw FormatException('Nom de fichier invalide : $value');
    }
    return basename;
  }
}

class MissionZoneBuildResult {
  const MissionZoneBuildResult({
    required this.outputPath,
    required this.mapBytes,
    required this.demBytes,
    required this.packageBytes,
    required this.demFiles,
  });

  final String outputPath;
  final int mapBytes;
  final int demBytes;
  final int packageBytes;
  final List<String> demFiles;

  double get packageMegabytes => packageBytes / (1024 * 1024);
}

class MissionZoneMissingDemException implements Exception {
  const MissionZoneMissingDemException(this.files);

  final List<String> files;

  @override
  String toString() {
    return 'Tuiles DEM manquantes : ${files.join(', ')}';
  }
}
