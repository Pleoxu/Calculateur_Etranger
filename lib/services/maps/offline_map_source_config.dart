import 'package:calculateur_etranger/services/maps/offline_map_download_service.dart';

/// Configuration de la source cartographique utilisée UNIQUEMENT lorsque
/// l'opérateur a explicitement activé le mode "En ligne".
///
/// Aucune source publique n'est codée en dur. Cela évite notamment d'utiliser
/// par erreur tile.openstreetmap.org pour du préchargement hors ligne.
///
/// Exemple de lancement avec une source autorisée :
/// flutter run -d macos \
///   --dart-define=MAP_TILE_NAME="Mon fournisseur" \
///   --dart-define=MAP_TILE_URL_TEMPLATE="https://.../{z}/{x}/{y}.png?key=..." \
///   --dart-define=MAP_TILE_ATTRIBUTION="© ..." \
///   --dart-define=MAP_TILE_FORMAT=png
abstract final class OfflineMapSourceConfig {
  static const String _name = String.fromEnvironment(
    'MAP_TILE_NAME',
    defaultValue: '',
  );

  static const String _urlTemplate = String.fromEnvironment(
    'MAP_TILE_URL_TEMPLATE',
    defaultValue: '',
  );

  static const String _attribution = String.fromEnvironment(
    'MAP_TILE_ATTRIBUTION',
    defaultValue: '',
  );

  static const String _format = String.fromEnvironment(
    'MAP_TILE_FORMAT',
    defaultValue: 'png',
  );

  static bool get isConfigured {
    final url = _urlTemplate.trim();
    return url.isNotEmpty &&
        url.contains('{z}') &&
        url.contains('{x}') &&
        url.contains('{y}');
  }

  static OfflineMapTileSource? get source {
    if (!isConfigured) return null;

    return OfflineMapTileSource(
      id: 'configured_xyz',
      name: _name.trim().isEmpty ? 'Source cartographique' : _name.trim(),
      urlTemplate: _urlTemplate.trim(),
      format: _format.trim().toLowerCase(),
      attribution: _attribution.trim(),
    );
  }
}
