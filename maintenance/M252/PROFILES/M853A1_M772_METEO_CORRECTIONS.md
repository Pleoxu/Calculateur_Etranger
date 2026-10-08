# M853A1 / M772 — chaîne des corrections météo

## Périmètre

Cette note décrit uniquement l’application informatique des valeurs **publiées** dans les tables M853A1/M772 intégrées au projet. Elle n’invente ni facteur, ni arrondi, ni correction de site absente des sources.

## Source de chaque terme

| Étape | Table | Source / donnée | Sortie utilisée |
|---|---|---|---|
| Niveau météo | D, colonne `LINE NO.` | Ligne MET requise au départ de la portée topographique | Ligne `MeteoRow` correspondante |
| Vent | A | Composantes `Wz` / `Wx` dans le repère du tir | Vent transversal et longitudinal |
| Adaptation station → pièce | B | `dc_tb_pct`, `dc_pb_pct` selon `ΔZ station météo → pièce` | Température et Pb% corrigés à la pièce |
| Portée / AE | D, colonnes 11–19 | Wz, V0, vent face/arrière, température, densité | Portée corrigée, puis interpolation finale D/E |
| Vitesse initiale | C | Écart de V0 à la température de poudre par rapport à 70 °F | Correction D de portée et F du réglage M772 |
| Réglage M772 | F | V0, vent face/arrière, température, densité | Correction algébrique du réglage M772 |
| Temps de vol | D, colonne `TIME OF FLIGHT` | Valeur interpolée à la portée corrigée | Temps bouche → dépotage/éclatement, distinct du réglage M772 |

## Séquence appliquée

1. Choisir la charge dans les domaines qualifiés en retenant l’écart probable d’éclatement en portée (`RB`) Table D le plus faible en cas de recouvrement.
2. Lire la ligne météo prescrite par `LINE NO.` à la portée topographique.
3. Décomposer le vent avec la Table A et ramener les données atmosphériques de la station à la pièce avec la Table B.
4. Appliquer les corrections de portée publiées par la Table D (`Wx`, température, densité, puis `V0` seulement si la correction de température de poudre est activée).
5. Interpoler de nouveau D et E à la **portée corrigée** : cette lecture livre l’AE, le temps de vol jusqu’au dépotage et le réglage M772 nominal.
6. Appliquer les facteurs Table F au **réglage M772 nominal**. La Table F ne modifie ni l’AE ni le temps de vol Table D.

> Une cellule Table D ou F non publiée (`null`) n’est jamais remplacée par une valeur estimée. Si l’utilisateur demande précisément cette correction, le calcul s’arrête avec un message explicite.

## Régression de référence

Le test `m853a1_m772_tables_test.dart` utilise CH2, 1 500 m, ligne MET 04, vent axial de 2 kn, 97,0 % température et 102,0 % Pb, sans différence station/pièce :

| Terme Table D | Valeur |
|---|---:|
| Vent longitudinal | +8,80 m |
| Température | −0,60 m |
| Densité | +8,40 m |
| Total | +16,60 m |
| Portée corrigée | 1 516,60 m |

Le résultat validé est AE `1334,7 mil`, réglage M772 `35,414`, et temps bouche → dépotage `35,4 s`.
