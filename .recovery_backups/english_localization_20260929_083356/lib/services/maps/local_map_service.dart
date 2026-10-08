import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalMapZone {
  const LocalMapZone({
    required this.id,
    required this.name,
    required this.filePath,
    required this.installedAtIso,
  });

  final String id;
  final String name;
  final String filePath;
  final String installedAtIso;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'filePath': filePath,
        'installedAtIso': installedAtIso,
      };

  static LocalMapZone? fromJson(dynamic raw) {
    if (raw is! Map) return null;

    final id = raw['id']?.toString().trim() ?? '';
    final name = raw['name']?.toString().trim() ?? '';
    final filePath = raw['filePath']?.toString().trim() ?? '';
    final installedAtIso = raw['installedAtIso']?.toString().trim() ?? '';

    if (id.isEmpty || name.isEmpty || filePath.isEmpty) return null;

    return LocalMapZone(
      id: id,
      name: name,
      filePath: filePath,
      installedAtIso: installedAtIso,
    );
  }
}

/// Gestionnaire cartographique local.
///
/// Règle de fonctionnement :
/// - hors ligne par défaut ;
/// - aucune source réseau n'est créée ici ;
/// - les cartes utilisées sont des fichiers MBTiles installés localement ;
/// - le mode en ligne est un choix explicite de l'opérateur et servira ensuite
///   uniquement au téléchargement / à la mise à jour d'une zone.
class LocalMapService {
  LocalMapService._();

  static final LocalMapService instance = LocalMapService._();

  static const String _zonesKey = 'offline_map_zones_v1';
  static const String _activeZoneKey = 'offline_map_active_zone_v1';
  static const String _onlineEnabledKey = 'offline_map_online_enabled_v1';

  Future<Directory> _mapsDirectory() async {
    final appSupport = await getApplicationSupportDirectory();
    final mapsDirectory = Directory(p.join(appSupport.path, 'maps'));

    if (!await mapsDirectory.exists()) {
      await mapsDirectory.create(recursive: true);
    }

    return mapsDirectory;
  }

  /// Le réseau cartographique est interdit par défaut.
  Future<bool> isOnlineEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onlineEnabledKey) ?? false;
  }

  Future<void> setOnlineEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineEnabledKey, value);
    debugPrint('[MAP] mode=${value ? 'EN LIGNE' : 'HORS LIGNE'}');
  }

  Future<List<LocalMapZone>> installedZones() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_zonesKey);

    if (raw == null || raw.trim().isEmpty) {
      return <LocalMapZone>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <LocalMapZone>[];

      final zones = <LocalMapZone>[];
      for (final item in decoded) {
        final zone = LocalMapZone.fromJson(item);
        if (zone == null) continue;

        if (await File(zone.filePath).exists()) {
          zones.add(zone);
        }
      }

      zones
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return zones;
    } catch (e) {
      debugPrint('[MAP] Index des zones illisible : $e');
      return <LocalMapZone>[];
    }
  }

  Future<void> _saveZones(List<LocalMapZone> zones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _zonesKey,
      jsonEncode(zones.map((e) => e.toJson()).toList(growable: false)),
    );
  }

  Future<String?> activeZoneId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_activeZoneKey)?.trim();
    return id == null || id.isEmpty ? null : id;
  }

  Future<LocalMapZone?> activeZone() async {
    final id = await activeZoneId();
    if (id == null) return null;

    final zones = await installedZones();
    for (final zone in zones) {
      if (zone.id == id) return zone;
    }

    return null;
  }

  Future<void> setActiveZone(String? zoneId) async {
    final prefs = await SharedPreferences.getInstance();

    if (zoneId == null || zoneId.trim().isEmpty) {
      await prefs.remove(_activeZoneKey);
      return;
    }

    final zones = await installedZones();
    final exists = zones.any((z) => z.id == zoneId.trim());
    if (!exists) {
      throw StateError('Zone MBTiles inconnue : $zoneId');
    }

    await prefs.setString(_activeZoneKey, zoneId.trim());
    debugPrint('[MAP] zone active=$zoneId');
  }

  Future<MbTilesTileProvider?> activeProvider() async {
    final id = await activeZoneId();
    if (id == null) return null;
    return providerFor(id);
  }

  /// Ouvre un provider MBTiles neuf pour l'écran qui le demande.
  ///
  /// Important : aucune instance n'est conservée en cache. `flutter_map`
  /// dispose son TileProvider lorsque le TileLayer est détruit ; réutiliser
  /// ensuite la même instance conduirait à lire une base SQLite déjà fermée.
  Future<MbTilesTileProvider?> providerFor(String zoneId) async {
    final normalized = zoneId.trim();
    if (normalized.isEmpty) return null;

    final zones = await installedZones();
    LocalMapZone? zone;
    for (final candidate in zones) {
      if (candidate.id == normalized) {
        zone = candidate;
        break;
      }
    }

    if (zone == null) return null;

    final file = File(zone.filePath);
    if (!await file.exists()) return null;

    final provider = MbTilesTileProvider.fromPath(
      path: file.path,
      silenceTileNotFound: true,
    );

    debugPrint(
      '[MAP] MBTiles ouvert : ${zone.name} '
      '(${await file.length()} octets)',
    );

    return provider;
  }

  /// Installe un fichier MBTiles préparé/téléchargé en amont.
  ///
  /// Le fichier est copié dans Application Support/maps puis devient la zone
  /// active. Cette méthode ne réalise aucune requête réseau.
  Future<LocalMapZone> importMbTiles({
    required String sourcePath,
    String? displayName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Fichier MBTiles introuvable', sourcePath);
    }

    if (p.extension(source.path).toLowerCase() != '.mbtiles') {
      throw const FormatException('Le fichier doit avoir l’extension .mbtiles');
    }

    final mapsDirectory = await _mapsDirectory();
    final baseName = p.basenameWithoutExtension(source.path).trim();
    final safeBase = baseName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final id =
        '${safeBase.isEmpty ? 'zone' : safeBase}_${DateTime.now().millisecondsSinceEpoch}';
    final destination = File(p.join(mapsDirectory.path, '$id.mbtiles'));

    await source.copy(destination.path);

    final zone = LocalMapZone(
      id: id,
      name: (displayName == null || displayName.trim().isEmpty)
          ? (baseName.isEmpty ? 'Zone hors ligne' : baseName)
          : displayName.trim(),
      filePath: destination.path,
      installedAtIso: DateTime.now().toUtc().toIso8601String(),
    );

    final zones = await installedZones();
    zones.add(zone);
    await _saveZones(zones);
    await setActiveZone(zone.id);

    debugPrint(
      '[MAP] zone installée : ${zone.name} -> ${zone.filePath} '
      '(${await destination.length()} octets)',
    );

    return zone;
  }

  Future<void> removeZone(String zoneId) async {
    final zones = await installedZones();
    LocalMapZone? removed;

    final kept = <LocalMapZone>[];
    for (final zone in zones) {
      if (zone.id == zoneId) {
        removed = zone;
      } else {
        kept.add(zone);
      }
    }

    if (removed != null) {
      final file = File(removed.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _saveZones(kept);

    if (await activeZoneId() == zoneId) {
      await setActiveZone(kept.isEmpty ? null : kept.first.id);
    }
  }

  /// Conservé pour compatibilité avec les appels existants.
  ///
  /// Il n'y a plus de provider partagé à fermer ici : chaque écran possède
  /// désormais sa propre instance et `flutter_map` en gère le cycle de vie.
  void dispose() {}
}
