# Audit de qualification — RP M819 / M772 CH3, Table D, page 05

> Cette note couvre exclusivement **2 100–2 875 m**. La qualification
> **2 900–3 575 m** est documentée dans
> `M819_M772_CH3_TABLE_D_PAGE05_PAGE07_AUDIT.md`.

## Objet

Cette note trace l’ajout des huit facteurs de correction de portée de la Table D pour les lignes **2 100 à 2 875 m** de la charge CH3. Ces facteurs sont nécessaires au calcul météo des coups linéaires lorsque leur distance réelle est comprise entre deux lignes de hausse, par exemple **2 271 m**.

Les colonnes concernées sont :

1. `correctionV0Dec` / `correctionV0Inc` ;
2. `correctionVentFace` / `correctionVentArriere` ;
3. `correctionTempAirDec` / `correctionTempAirInc` ;
4. `correctionDensiteAirDec` / `correctionDensiteAirInc`.

## Sources et méthode

| Plage | Source contrôlée | Décision |
| --- | --- | --- |
| 2 100–2 875 m, pas 25 m | `CH3_page05_velocity_wind.json` + `CH3_page05_temp_density.json`, comparés visuellement aux crops page 05 | Import exact, aucune interpolation de donnée brute |
| Hors 2 100–2 875 m | Hors périmètre de cette note | Voir l’audit pages 05/07 ou conserver les cellules non qualifiées |

Les images contrôlées sont :

- `/home/ubuntu/rp_m819_json_reconstruction/vision_transcriptions/CH3_page05_velocity_wind.png`
- `/home/ubuntu/rp_m819_json_reconstruction/vision_transcriptions/CH3_page05_temp_density.png`

## Contrôle ciblé du cas ayant échoué

| Distance | V0− | V0+ | Vent face | Vent arrière | T− | T+ | Densité− | Densité+ |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 250 m | 15.3 | -13.4 | 7.3 | -6.2 | -0.1 | 0.2 | -6.7 | 6.7 |
| 2 275 m | 15.4 | -13.6 | 7.3 | -6.3 | -0.1 | 0.2 | -6.8 | 6.8 |

Ainsi, à **2 271 m**, le codec peut interpoler uniquement entre deux lignes Table D désormais qualifiées — 2 250 et 2 275 m — sans fabriquer une donnée hors source. Les facteurs de la ligne météo demeurent ceux de la Table D : **LINE NO. 05**.

## Résolution du conflit historique à 2 100 m

La valeur `correctionVentArriere` est retenue à **-6.2**. Le contrôle visuel direct de la colonne de vent arrière de la page 05 confirme cette valeur. Le conflit OCR mentionnant `-6.3` n’est pas importé.

## Rectification de périmètre

Le dernier rang visible de la page 05 est **2 800 m**. Il ne doit pas être
étiqueté 2 900 m. Les coefficients 2 900 m proviennent uniquement de la page 07
et sont tracés dans l’audit pages 05/07.

## Protection contre les données inventées

L’importeur `tool/import_m819_ch3_table_d_page05_page07_factors.py` :

- ne crée aucune ligne de distance ;
- refuse toute divergence avec une valeur déjà active, hors rectification
  explicitement auditée de 2 900 m ;
- exige les huit valeurs source pour chaque ligne importée ;
- laisse les lignes hors plage sans coefficient ;
- met à jour uniquement les champs optionnels de correction de la Table D et
  l’empreinte correspondante dans `SOURCES.sha256`.
