# Patch carte / observateur v5

## Ajouts

- Observateur : ajout de deux boutons discrets dans le cartouche développé :
  - GPS : remplit X/Y/Z observateur depuis la localisation.
  - Carte : permet de choisir la position observateur sur la carte.
- Désignation objectif depuis observateur : ajout d'un bouton carte à côté du switch DAZ/UTM.
- La carte affiche désormais :
  - PD si disponible,
  - Observateur si disponible,
  - Objectif sélectionné,
  - ligne de visée vers la référence utile.
- Pour l'objectif observateur, le panneau carte affiche :
  - distance OBS → OBJ,
  - azimut OBS → OBJ,
  - X/Y/Z UTM dans la zone de la PD.
- Les coordonnées observateur et objectif sont forcées dans la zone UTM de la PD pour éviter les sauts 30T/31T.

## Remarque altitude

Le Z est conservé et transporté dans les champs, mais la lecture MNT Copernicus GLO-30 n'est pas encore branchée dans ce patch. Le point d'intégration prévu est dans `CartePositionPickerPage` au moment du tap carte.
