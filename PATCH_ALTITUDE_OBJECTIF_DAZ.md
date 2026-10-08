# Patch altitude objectif observateur DAZ

Correction : en mode Observateur + DAZ, l'altitude de l'objectif n'était jamais recalculée automatiquement.

Nouveau flux :

- X/Y observateur + distance + azimut observateur -> objectif
- calcul X/Y objectif en UTM dans la zone de la pièce
- conversion UTM -> lat/lon
- interrogation `ElevationService.elevationAt()`
- si une tuile DEM est disponible : remplissage automatique de :
  - altitude objectif DAZ
  - X/Y/Z objectif cachés pour cohérence interne
- si aucune tuile DEM n'est disponible : aucun blocage, aucun écrasement par 0.

Important : pour obtenir une altitude autour de Paris/Issy, il faut la tuile DEM `N48E002.f32` en cache, en asset, ou via `downloadBaseUrl`.
