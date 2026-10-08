# RP M819 / M772 — corrections C, D et F

## Portée

Le pipeline `RP_M819` emploie les valeurs publiées des Tables A à F :

| Table | Emploi runtime |
|---|---|
| A | Décomposition du vent relatif en composantes Wz / Wx |
| B | Ajustement MET station → pièce de la température et de la densité/pression |
| C | Écart de vitesse initiale `ΔV0` selon la température de poudre |
| D | Hausse, temps de vol vers l’événement M772, ligne MET, dérive Wz et corrections longitudinales Wx / température / densité / `ΔV0` |
| E | Hauteur de trajectoire et erreurs probables publiées |
| F | Corrections du réglage M772 dues à Wx / température / densité / `ΔV0` |

## Réglage de Table F

La Table D publie le réglage M772 au dixième ; la Table F publie une grille discrète de réglages. Le runtime sélectionne la **ligne de Table F publiée la plus proche**. Il n’extrapole aucune valeur au-delà des lignes de la Table F.

Le réglage final M772 est affiché séparément du **temps de vol**, qui demeure celui de la Table D jusqu’à l’événement réglé de la fusée.

## Exemple de régression : 1 500 m

À 1 500 m, la sélection par plus faible écart probable retient `M819_M772_CH2`, ligne MET `04`. Avec une ligne MET correspondante et une température poudre différente de 70 °F / 21,1 °C, les corrections C, D et F modifient la portée corrigée et le réglage M772. Les valeurs restent traçables dans les détails du résultat (`tableD_*`, `tableF_*`).

## Limites

Un facteur absent de la table source n’est jamais reconstitué : si l’opérateur sollicite une correction dont le facteur n’est pas publié, le calcul l’indique au lieu d’inventer une correction.
