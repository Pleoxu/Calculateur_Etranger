# Audit CH4 — conformité JSON / PDF FT 81-AR-2

## Périmètre

| Source | Contrôle |
|---|---|
| `Tables_CH4_HEM821_FuM734.pdf` | 17 pages scannées du FT 81-AR-2, charge 4, CTG HE M821 / FUZE MO M734 |
| Table C JSON | 35 lignes, −40 à +130 °F |
| Table D JSON | 153 lignes, 1825 à 5608 m |
| Table E JSON | 153 lignes, 1825 à 5608 m |

## Résultat

**Conforme : aucune donnée des JSON C, D ou E n’a été corrigée.**

Les contrôles visuels ont couvert la Table C complète, le début et la fin des Tables D/E, ainsi que les blancs de colonnes à haute portée. Les valeurs de référence relevées dans le PDF concordent avec les JSON :

| Table | Ligne | PDF / JSON |
|---|---:|---|
| C | −40 °F | ΔV0 = −7,9 m/s |
| C | 70 °F | ΔV0 = 0,0 m/s |
| C | 130 °F | ΔV0 = +4,7 m/s |
| D | 1825 m | AE 1423 mil ; TV 51,3 s ; LN 06 ; Wz 4,5 mil |
| D | 5000 m | AE 1027 mil ; TV 44,2 s ; LN 05 ; Wz 1,3 mil |
| D | 5608 m | AE 800 mil ; TV 37,3 s ; LN 04 ; Wz 1,0 mil |
| E | 1825 m | EPP 22 m ; EPD 12 m ; angle 1471 mil |
| E | 5125 m | EPP 23 m ; EPD 10 m ; angle 1155 mil |
| E | 5608 m | EPP non publié ; EPD 9 m ; angle 985 mil |

La borne terminale **5608 m** est bien une valeur imprimée dans le PDF, et non une erreur de saisie malgré l’intervalle final de 8 m.

## Blanks documentaires et borne runtime

Les `null` du JSON reproduisent les cases blanches du PDF et ne sont pas des données manquantes à compléter :

| Première portée affectée | Table / donnée absente | Conséquence |
|---:|---|---|
| 5150 m | D — vent longitudinal « HEAD » | fin du domaine runtime complet |
| 5375 m | D — ΔV0 DEC | hors runtime |
| 5425 m | D — densité air INC | hors runtime |
| 5525 m | D — dérivée AE/tours ; E — EPP | hors runtime |

Le domaine qualifié est donc **1825–5125 m**. Cette décision conserve toutes les corrections exigées par le pipeline et évite toute extrapolation doctrinalement non sourcée.
