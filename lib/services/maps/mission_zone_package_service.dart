import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:calculateur_etranger/services/maps/local_map_service.dart';

/// Format d'échange d'une zone de mission autonome.
///
/// Extension recommandée : `.ctzone`
/// Contenu ZIP :
///
/// manifest.json
/// map/carte.mbtiles
/// dem/N43E006.f32
/// dem/N43E007.f32
///
/// Le paquet peut être préparé sur un autre ordinateur puis transféré
/// localement (USB, AirDrop, stockage amovible, etc.). Aucun accès réseau
/// n'est nécessaire pour l'import.
class MissionZonePackageService {
  MissionZonePackageService._();

  static final MissionZonePackageService instance =
      MissionZonePackageService._();

  static const String packageFormat = 'calculateur_tir_zone';
  static const int packageVersion = 1;

  Future<MissionZoneImportResult> importPackage({
    required String sourcePath,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw FileSystemException('Zone package not found', sourcePath);
    }

    final lowerPath = sourcePath.toLowerCase();
    if (!lowerPath.endsWith('.ctzone') && !lowerPath.endsWith('.zip')) {
      throw const FormatException(
        'Unrecognized package format. Expected extension: .ctzone',
      );
    }

    final bytes = await source.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);

    final manifestEntry = _entryByNormalizedName(archive, 'manifest.json');
    if (manifestEntry == null || !manifestEntry.isFile) {
      throw const FormatException('manifest.json missing from package.');
    }

    final manifestRaw = utf8.decode(manifestEntry.content);
    final decoded = jsonDecode(manifestRaw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid manifest.json.');
    }

    final manifest = MissionZoneManifest.fromJson(decoded);
    _validateManifest(manifest);

    final mapEntry = _entryByNormalizedName(archive, manifest.mapFile);
    if (mapEntry == null || !mapEntry.isFile) {
      throw FormatException(
        'MBTiles map missing from package: ${manifest.mapFile}',
      );
    }

    final demEntries = <String, ArchiveFile>{};
    for (final demPath in manifest.demFiles) {
      final entry = _entryByNormalizedName(archive, demPath);
      if (entry == null || !entry.isFile) {
        throw FormatException('DEM tile missing from package: $demPath');
      }
      demEntries[demPath] = entry;
    }

    final tempBase = await getTemporaryDirectory();
    final staging = Directory(
      p.join(tempBase.path, 'ctzone_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await staging.create(recursive: true);

    LocalMapZone? installedZone;

    try {
      final stagedMap = File(p.join(staging.path, 'zone.mbtiles'));
      await stagedMap.writeAsBytes(mapEntry.content, flush: true);

      // On prépare toutes les tuiles DEM dans le staging avant de modifier
      // le stockage persistant de l'application.
      final stagedDem = <String, File>{};
      for (final item in demEntries.entries) {
        final basename = p.basename(item.key);

        if (!_validDemBasename(basename)) {
          throw FormatException('Invalid DEM tile name: $basename');
        }

        final file = File(p.join(staging.path, basename));
        await file.writeAsBytes(item.value.content, flush: true);
        stagedDem[basename] = file;
      }

      installedZone = await LocalMapService.instance.importMbTiles(
        sourcePath: stagedMap.path,
        displayName: manifest.name,
      );

      final appSupport = await getApplicationSupportDirectory();
      final demDirectory = Directory(p.join(appSupport.path, 'dem_cache'));
      if (!await demDirectory.exists()) {
        await demDirectory.create(recursive: true);
      }

      var demInstalled = 0;
      for (final item in stagedDem.entries) {
        final destination = File(p.join(demDirectory.path, item.key));
        await item.value.copy(destination.path);
        demInstalled++;
      }

      debugPrint(
        '[ZONE PACKAGE] import=${manifest.name} '
        'map=${installedZone.id} dem=$demInstalled '
        'source=$sourcePath',
      );

      return MissionZoneImportResult(
        zone: installedZone,
        manifest: manifest,
        demInstalled: demInstalled,
      );
    } catch (_) {
      // Si la carte a déjà été installée mais que le reste du paquet échoue,
      // on revient à un état cohérent.
      if (installedZone != null) {
        try {
          await LocalMapService.instance.removeZone(installedZone.id);
        } catch (_) {
          // Ne pas masquer l'erreur d'import initiale.
        }
      }
      rethrow;
    } finally {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  }

  ArchiveFile? _entryByNormalizedName(Archive archive, String wanted) {
    final normalizedWanted = _normalizeArchivePath(wanted);

    for (final entry in archive) {
      if (_normalizeArchivePath(entry.name) == normalizedWanted) {
        return entry;
      }
    }
    return null;
  }

  String _normalizeArchivePath(String raw) {
    var value = raw.replaceAll('\\', '/').trim();

    while (value.startsWith('./')) {
      value = value.substring(2);
    }
    while (value.startsWith('/')) {
      value = value.substring(1);
    }

    if (value.split('/').any((segment) => segment == '..')) {
      throw const FormatException('Forbidden path in package.');
    }

    return value;
  }

  bool _validDemBasename(String value) {
    return RegExp(
      r'^[NS]\d{2}[EW]\d{3}\.f32$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  void _validateManifest(MissionZoneManifest manifest) {
    if (manifest.format != packageFormat) {
      throw FormatException('Incompatible package format: ${manifest.format}');
    }

    if (manifest.version != packageVersion) {
      throw FormatException('Unsupported package version: ${manifest.version}');
    }

    if (manifest.name.trim().isEmpty) {
      throw const FormatException('Missing zone name.');
    }

    final mapFile = _normalizeArchivePath(manifest.mapFile);
    if (!mapFile.toLowerCase().endsWith('.mbtiles')) {
      throw const FormatException('Map file must be a .mbtiles.');
    }

    for (final demFile in manifest.demFiles) {
      final normalized = _normalizeArchivePath(demFile);
      final basename = p.basename(normalized);

      if (!normalized.toLowerCase().endsWith('.f32') ||
          !_validDemBasename(basename)) {
        throw FormatException('Invalid DEM reference: $demFile');
      }
    }

    final bounds = manifest.bounds;
    if (bounds != null) {
      if (bounds.west < -180 ||
          bounds.east > 180 ||
          bounds.south < -90 ||
          bounds.north > 90 ||
          bounds.west >= bounds.east ||
          bounds.south >= bounds.north) {
        throw const FormatException('Invalid geographic extent.');
      }
    }
  }
}

class MissionZoneImportResult {
  const MissionZoneImportResult({
    required this.zone,
    required this.manifest,
    required this.demInstalled,
  });

  final LocalMapZone zone;
  final MissionZoneManifest manifest;
  final int demInstalled;
}

class MissionZoneManifest {
  const MissionZoneManifest({
    required this.format,
    required this.version,
    required this.name,
    required this.mapFile,
    required this.demFiles,
    this.bounds,
    this.createdAtIso,
    this.description,
  });

  final String format;
  final int version;
  final String name;
  final String mapFile;
  final List<String> demFiles;
  final MissionZoneBounds? bounds;
  final String? createdAtIso;
  final String? description;

  factory MissionZoneManifest.fromJson(Map<String, dynamic> json) {
    final map = json['map'];
    if (map is! Map) {
      throw const FormatException('Section "map" manquante.');
    }

    final dem = json['dem'];
    final rawFiles = dem is Map ? dem['files'] : null;

    final boundsRaw = json['bounds'];

    return MissionZoneManifest(
      format: (json['format'] ?? '').toString(),
      version: (json['version'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      mapFile: (map['file'] ?? '').toString(),
      demFiles: rawFiles is List
          ? rawFiles.map((value) => value.toString()).toList(growable: false)
          : const <String>[],
      bounds: boundsRaw is Map
          ? MissionZoneBounds.fromJson(Map<String, dynamic>.from(boundsRaw))
          : null,
      createdAtIso: json['createdAt']?.toString(),
      description: json['description']?.toString(),
    );
  }
}

class MissionZoneBounds {
  const MissionZoneBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  factory MissionZoneBounds.fromJson(Map<String, dynamic> json) {
    double read(String key) {
      final value = json[key];
      if (value is! num) {
        throw FormatException('Invalid coordinate "$key".');
      }
      return value.toDouble();
    }

    return MissionZoneBounds(
      west: read('west'),
      south: read('south'),
      east: read('east'),
      north: read('north'),
    );
  }
}
