# Patch carte objectif V4

Corrections intégrées :

- Boutons carte / objectif sur fond sombre, icône claire, format discret cohérent avec UTM/LAT/DAZ.
- Toggle Observateur remplacé par un contrôle sombre discret avec état vert léger actif.
- Correction du défaut UTM : la saisie de zone seule `30` est interprétée par défaut comme `30T` au lieu de `30U`.
- Sélection objectif : les coordonnées UTM de l'objectif sont forcées dans la zone UTM de la pièce directrice quand elle est connue, afin d'éviter les écarts artificiels de plusieurs centaines de kilomètres en limite de zone.
- Distance et azimut PD → objectif calculés depuis les coordonnées géographiques WGS84, donc robustes même si le point tapé tombe naturellement dans une autre zone UTM.
- Altitude objectif : le tap carte ne reprend plus l'altitude de la pièce par défaut ; il conserve l'altitude objectif existante ou met 0 en attente du MNT.
- Correction du risque d'overflow visuel des marqueurs carte en augmentant la taille des marqueurs.

Remarque MNT :

Le branchement Copernicus DEM GLO-30 n'est pas inclus comme asset dans ce zip. Le code est prêt côté carte pour recevoir une altitude automatique, mais il faut ajouter les tuiles DEM/lecteur MNT avant de remplacer le Z=0 par un Z terrain.
