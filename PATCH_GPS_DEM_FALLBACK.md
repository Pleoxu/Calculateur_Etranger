# Correctif GPS + DEM fallback

Problème observé : quand la position GPS tombe sur une tuile DEM absente, par exemple `N48E002`, le service DEM levait une exception :

```txt
Bad state: Tuile DEM absente et aucun serveur DEM configuré
```

Cette exception interrompait le flux `_fillCoordsFromGps()` avant la mise à jour de la position de la pièce directrice.

Correctif : `ElevationService.elevationAt()` renvoie maintenant `null` en cas de tuile absente, serveur DEM non configuré, téléchargement impossible ou erreur de lecture. L'altitude DEM reste donc optionnelle, et l'écran continue avec l'altitude GPS/manuelle de secours via `_altitudeMntOrFallback()`.

Effet attendu :

- la PD apparaît de nouveau quand on se met sur GPS ;
- si la tuile DEM est absente, le Z utilise l'altitude GPS ;
- quand un serveur DEM ou une tuile locale sera disponible, le Z sera automatiquement remplacé par l'altitude MNT.
