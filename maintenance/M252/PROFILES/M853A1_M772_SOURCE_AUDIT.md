# Audit source — ILL M853A1 / fusée M772

## Provenance et périmètre

Les Tables A–F CH1 à CH4 ont été transcrites depuis les pages M853A1/M772 du manuel `81MM-TFT` fourni. Les sources brutes, leurs empreintes SHA-256 et les tables de travail sont conservées par profil sous `M853A1_M772_CHx/raw/`.

## Contrôles réalisés

| Contrôle | Résultat |
|---|---|
| Tables présentes | A–F pour CH1, CH2, CH3 et CH4 |
| Domaines Table D / Table E | Identiques, strictement croissants et sans doublon dans chaque charge |
| Transcriptions source | Aucune cellule signalée non lisible dans les 50 fichiers de transcription |
| Table F | Les cellules source vides restent `null` ; aucune valeur zéro n’est inventée |
| Sélection en recouvrement | Plus faible RB publié de la Table D |
| Isolation | Aucun mélange avec les profils HE M821/M734 ou RP M819/M772 |

## Qualification runtime livrée

Le pipeline calcule **la solution nominale** : AE, réglage M772, temps de vol jusqu’au dépotage, ligne météo et écarts probables de Table D. Les facteurs Table F sont chargés et exposés dans le détail, mais ils ne sont pas appliqués avant validation séparée des unités, signes et arrondis par exercice.

## Paramètres d’effet d’éclairage consignés

- Hauteur nominale de dépotage : **475 m au-dessus du sol objectif**.
- Diamètre éclairé effectif : **1 200 m** (rayon 600 m).
- Intensité : 525 000–600 000 cd ; durée de combustion 50–60 s.

La hauteur de dépotage est une caractéristique d’effet distincte de la hauteur maximale de trajectoire en Table E.
