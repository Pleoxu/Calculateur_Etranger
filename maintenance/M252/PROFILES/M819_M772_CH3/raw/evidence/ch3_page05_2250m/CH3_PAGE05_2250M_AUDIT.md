# Audit source — M819 / M772 CH3, Table D, portée 2 250 m

## Objet

Ce correctif renseigne **uniquement** les huit coefficients de portée Table D publiés pour la ligne `2 250 m`. Les autres lignes qui ne sont pas encore qualifiées restent inchangées (`null`) : aucune extrapolation, interpolation ou reprise d’une autre charge n’est autorisée.

## Source primaire et contrôle visuel

- Document : `Tables CH3_RPM819_FuM772.pdf`, page 05, colonnes Table D de correction.
- Extraits de contrôle visuel inclus :
  - `CH3_page05_velocity_wind.png` : ΔV0 et vent ;
  - `CH3_page05_temp_density.png` : température air et densité air.
- Transcriptions source incluses : les deux fichiers JSON correspondants.

La ligne 2 250 m est lisible directement dans les deux extraits et a été contrôlée visuellement avant intégration.

| Colonne Table D | Valeur publiée à 2 250 m | Champ runtime |
|---|---:|---|
| ΔV0 décroissant | 15,3 | `correctionV0Dec` |
| ΔV0 croissant | -13,4 | `correctionV0Inc` |
| Vent de face | 7,3 | `correctionVentFace` |
| Vent arrière | -6,2 | `correctionVentArriere` |
| Température air décroissante | -0,1 | `correctionTempAirDec` |
| Température air croissante | 0,2 | `correctionTempAirInc` |
| Densité air décroissante | -6,7 | `correctionDensiteAirDec` |
| Densité air croissante | 6,7 | `correctionDensiteAirInc` |

## Limites de qualification

Cette preuve ne qualifie pas les lignes CH3 non couvertes par ce correctif. En particulier, les chevauchements OCR conflictuels et les plages terminales non transcrites restent volontairement hors du présent patch. La Table F demeure distincte : elle ajuste seulement le réglage M772, sans remplacer les corrections de portée de la Table D.
