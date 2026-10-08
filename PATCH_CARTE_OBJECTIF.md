# Patch carte pièce / objectif

## Changements UX

- Bouton carte rendu discret, au format petit chip icône dans l'esprit des boutons `UTM / LAT / DAZ`.
- État inactif : fond gris/blanc discret.
- État actif : fond vert léger.
- L'objectif affiche un bouton carte actif seulement quand la pièce directrice est exploitable.
- La zone UTM accepte désormais `30` ou `31` sans bande ; la bande par défaut utilisée pour centrer est `U`, puis le picker réécrit la zone complète après sélection.

## Changements fonctionnels

- Tap carte pièce : peut ouvrir la carte même sans coordonnées initiales, ou se centrer sur la pièce si X/Y/zone sont présents.
- Tap carte objectif : se centre sur la pièce directrice, affiche la ligne PD → objectif, la distance et l'azimut.
- Après sélection objectif : remplit X/Y/Z objectif, distance et azimut dans le formulaire.

## Fichiers modifiés

- `lib/presentation/fire/pages/ecran_tir_complet.dart`
- `lib/presentation/fire/widgets/coordonnees_input_card.dart`
- `lib/presentation/fire/widgets/objectif_input_card.dart`
- `lib/presentation/fire/pages/carte_position_picker_page.dart`
