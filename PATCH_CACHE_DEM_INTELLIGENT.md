# Patch cache DEM intelligent

Ce patch transforme `ElevationService` en service mobile réaliste : les tuiles DEM ne sont plus obligatoirement embarquées dans l'application.

## Principe

1. L'application calcule la tuile 1° × 1° à partir de la latitude/longitude : `N43E001.f32`, `N48W002.f32`, etc.
2. Elle cherche d'abord la tuile dans le cache local de l'application.
3. Si elle n'est pas présente, elle tente `assets/dem/<tuile>.f32`.
4. Si elle n'est pas présente dans les assets et si `downloadBaseUrl` est configuré dans `assets/dem/manifest.json`, elle télécharge la tuile.
5. Elle garde les tuiles téléchargées dans un cache local limité par `maxCacheBytes`.

## Fichier modifié

- `lib/services/position/elevation_service.dart`
- `assets/dem/manifest.json`
- `pubspec.yaml` : ajout de `path_provider`

## Configuration serveur

Dans `assets/dem/manifest.json`, renseigner par exemple :

```json
{
  "version": 2,
  "downloadBaseUrl": "https://ton-serveur.example/dem/f32",
  "maxCacheBytes": 536870912,
  "tileWidth": 3601,
  "tileHeight": 3601,
  "nodata": -32768,
  "tiles": []
}
```

Le serveur doit exposer :

```txt
https://ton-serveur.example/dem/f32/N43E001.f32
https://ton-serveur.example/dem/f32/N48W002.f32
...
```

## API ajoutée

```dart
Future<double?> elevationAt({
  required double latitude,
  required double longitude,
})
```

existe toujours.

Nouvelles méthodes utiles :

```dart
Future<void> prefetchAround({
  required double latitude,
  required double longitude,
  required double radiusKm,
})

Future<int> cacheSizeBytes()

Future<void> clearCache()
```

## Remarque

Le patch ne fournit pas les tuiles Copernicus elles-mêmes. Il prépare l'application à consommer des tuiles `.f32` préconverties et hébergées sur un serveur ou embarquées ponctuellement dans `assets/dem/`.
