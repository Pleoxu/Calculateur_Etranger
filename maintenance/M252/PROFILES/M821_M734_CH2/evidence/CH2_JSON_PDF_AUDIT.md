# Audit CH2 — conformité des JSON au PDF FT 81-AR-2

## Documents contrôlés

- `Tables_CH2_HEM821_FuM734.pdf` — FT 81-AR-2, CHARGE 2, CTG HE M821, FUZE MO M734 ;
- `OEM821_FuM734_CH2_Table_C.json` ;
- `OEM821_FuM734_CH2_Table_D.json` ;
- `OEM821_FuM734_CH2_Table_E.json`.

Le PDF est une numérisation image : le texte embarqué ne contient pas les tables. Chaque page a donc été rendue à 400 dpi, lue visuellement et contrôlée avec OCR ; les bornes, grilles, en-têtes, valeurs de référence et omissions imprimées ont été confrontés aux JSON.

## Résultat

**Conforme : aucune correction de donnée n’a été requise.**

| Table | PDF | JSON | Contrôles effectués |
|---|---:|---:|---|
| C | page 29 | 35 lignes | −40 à +130 °F par pas de 5 ; ΔV0 et conversion °C conformes ; 70 °F = 0,0 m/s. |
| D — données de base | pages 30, 32, 34 | 92 lignes | 1125–3400 m, pas de 25 m, hausse, ΔAE/100 m, tours, temps de vol, `LINE NO.`, Wz conformes. |
| D — facteurs de correction | pages 31, 33, 35 | 92 lignes | V0, vent, température et densité conformes, y compris cases blanches de fin de table. |
| E | pages 36, 37, 38 | 92 lignes | hausse, EPP/EPR, EPD, angle/cotangente de chute, vitesse terminale et flèche conformes. |

## Valeurs de contrôle

| Portée | Champ | PDF / JSON |
|---:|---|---:|
| 1125 m | D : hausse / temps / LINE NO. / Wz | 1422 mil / 39,6 s / 05 / 4,0 mil |
| 1125 m | E : EPP / EPD / chute | 10 m / 7 m / 1454 mil |
| 1900 m | D : hausse / temps / Wz | 1290 mil / 37,9 s / 2,1 mil |
| 2700 m | E : EPP / EPD / chute | 15 m / 7 m / 1207 mil |
| 3125 m | D : hausse / ΔV0 DEC / ΔV0 INC | 994 mil / +24,9 m / −21,6 m |
| 3150 m | D : ΔV0 DEC | non publié (`null`) |
| 3275 m | E : EPP | 17 m |
| 3300 m | E : EPP | non publié (`null`) |
| 3400 m | D/E : hausse / EPD / chute | 800 mil / 5 m / 917 mil |

## Qualification runtime

La source complète est conservée. Le runtime est intentionnellement limité à **1125–3125 m**, qui est l’intersection des données D et E où toutes les corrections dans les deux sens et l’EPP sont effectivement publiées. Aucune donnée absente n’est interpolée ou reconstruite.
