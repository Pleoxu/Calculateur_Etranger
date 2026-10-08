# Patch v6 — Altitude des points PD / Observateur / Objectif

Ajouts principaux :

- `lib/services/position/elevation_service.dart`
  - Service MNT local optionnel.
  - Lit `assets/dem/manifest.json`.
  - Interroge des tuiles DEM préconverties en `float32le`.
  - Interpolation bilinéaire.
  - Si aucune tuile ne couvre le point, renvoie `null` et conserve l'altitude existante.

- `assets/dem/manifest.json`
  - Manifest MNT prêt à recevoir les tuiles Copernicus GLO-30 converties.
  - Manifest vide par défaut, donc aucun comportement cassant si les tuiles ne sont pas encore installées.

- `pubspec.yaml`
  - Ajout de `assets/dem/manifest.json`.

- `carte_position_picker_page.dart`
  - Au tap carte, tentative de lecture altitude MNT.
  - Les points PD / OBS / OBJ utilisent l'altitude MNT quand disponible.
  - Affichage du Z dans le panneau carte : `Z` ou `Z MNT`.

- `ecran_tir_complet.dart`
  - GPS PD : altitude MNT utilisée si disponible, sinon altitude GPS.
  - GPS Observateur : altitude MNT utilisée si disponible, sinon altitude GPS.
  - Tap carte PD / Observateur / Objectif : Z vient du MNT si disponible.

Format attendu d'une tuile DEM :

```json
{
  "tiles": [
    {
      "id": "N48E002",
      "path": "assets/dem/N48E002.f32",
      "minLat": 48.0,
      "maxLat": 49.0,
      "minLon": 2.0,
      "maxLon": 3.0,
      "width": 3601,
      "height": 3601,
      "nodata": -32768
    }
  ]
}
```

Les fichiers `.f32` sont des grilles `float32 little-endian`, rangées nord→sud puis ouest→est.
