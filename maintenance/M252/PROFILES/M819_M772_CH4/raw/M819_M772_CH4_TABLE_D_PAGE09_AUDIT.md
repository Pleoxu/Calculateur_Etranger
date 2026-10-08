# Audit de qualification — RP M819 / M772 CH4, Table D, page 09

## Objet

Cette note qualifie les huit facteurs de correction de portée de la Table D
CH4 pour les lignes **4 000–4 475 m**, à pas de 25 m :

1. `correctionV0Dec` / `correctionV0Inc` ;
2. `correctionVentFace` / `correctionVentArriere` ;
3. `correctionTempAirDec` / `correctionTempAirInc` ;
4. `correctionDensiteAirDec` / `correctionDensiteAirInc`.

Les facteurs Table D corrigent portée et hausse. Les facteurs Table F
corrigent exclusivement le réglage M772 correspondant.

## Sources contrôlées

| Élément | Source traçable | Contrôle |
| --- | --- | --- |
| Vitesse initiale et vent | `CH4_page09_velocity_wind.json` | rendu `CH4_page09_velocity_wind.png` |
| Température et densité | `CH4_page09_temp_density.json` | rendu `CH4_page09_temp_density.png` |
| Alignement V0− | `CH4_page09_v0_dec_aligned.json` | rendu aligné dédié |
| Alignement vent de face | `CH4_page09_wind_head_aligned.json` | rendu aligné dédié |

Les sources rendent possible l’import exact jusqu’à **4 475 m**. À partir de
**4 500 m**, la colonne `wind_head` est vide dans la source publiée ; aucune
valeur n’est remplie, interpolée ou déduite au-delà.

## Ligne demandée : 4 100 m

| Portée | V0− | V0+ | Vent face | Vent arrière | T− | T+ | Densité− | Densité+ | LINE NO. |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4 100 m | 21.3 | -18.9 | 10.2 | -8.7 | 1.7 | -0.8 | -14.4 | 14.3 | 05 |

Les signes ci-dessus sont reproduits tels qu’imprimés dans la Table D CH4,
page 09. Ils ne sont pas normalisés selon les tendances de CH3.

## Garde-fous

L’importeur `tool/import_m819_ch4_table_d_page09_factors.py` :

- ne crée aucune ligne Table D ;
- exige les huit cellules publiées de chaque ligne importée ;
- refuse tout conflit avec une valeur locale non nulle ;
- laisse toutes les lignes hors 4 000–4 475 m explicitement non qualifiées ;
- actualise seulement l’empreinte de Table D dans `SOURCES.sha256`.
