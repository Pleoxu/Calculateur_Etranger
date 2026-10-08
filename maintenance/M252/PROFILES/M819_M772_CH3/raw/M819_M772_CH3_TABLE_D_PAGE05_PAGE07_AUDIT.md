# Audit de qualification — RP M819 / M772 CH3, Table D, pages 05 et 07

## Objet

Cette note qualifie les huit colonnes de correction de portée de la **Table D**
CH3 sur la plage exacte **2 100–3 575 m** :

1. `correctionV0Dec` / `correctionV0Inc` ;
2. `correctionVentFace` / `correctionVentArriere` ;
3. `correctionTempAirDec` / `correctionTempAirInc` ;
4. `correctionDensiteAirDec` / `correctionDensiteAirInc`.

Ces facteurs sont employés avant de corriger la trajectoire et le réglage M772
(Table F). La Table F n’est ni remplacée ni utilisée pour corriger la portée.

## Sources contrôlées visuellement

| Plage | Sources de transcription | Rendu PDF interne contrôlé | Décision |
| --- | --- | --- | --- |
| 2 100–2 875 m, pas 25 m | `CH3_page05_velocity_wind.json`, `CH3_page05_temp_density.json` | crops page 05 | Import exact |
| 2 900–3 575 m, pas 25 m | `CH3_page07_velocity_wind.json`, `CH3_page07_temp_density.json` | crops page 07 | Import exact |
| ≥ 3 600 m | page 07 incomplète pour au moins une colonne | page 07 | Aucun import |

Les renders source contrôlés sont :

- `/home/ubuntu/rp_m819_json_reconstruction/vision_transcriptions/CH3_page05_velocity_wind.png`
- `/home/ubuntu/rp_m819_json_reconstruction/vision_transcriptions/CH3_page05_temp_density.png`
- `/home/ubuntu/rp_m819_json_reconstruction/vision_transcriptions/CH3_page07_velocity_wind.png`
- `/home/ubuntu/rp_m819_json_reconstruction/vision_transcriptions/CH3_page07_temp_density.png`

## Correction de traçabilité à 2 900 m

L’ancien audit page 05 mentionnait une ligne **2 900 m** avec les valeurs
`19.0 / -16.8 / 7.7 / -6.5 / -0.1 / 0.2 / -8.3 / 8.3`.

Le contrôle visuel montre que cette ligne au bas du crop page 05 est en réalité
**2 800 m**. La page 07 fournit la ligne 2 900 m publiée, qui est différente.
La valeur active v24 a donc été corrigée uniquement après vérification du rendu
page 07 ; aucune interpolation n’a été employée.

## Ligne demandée : 2 950 m

| Portée | V0− | V0+ | Vent face | Vent arrière | T− | T+ | Densité− | Densité+ | LINE NO. |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 950 m | 20.0 | -17.7 | 7.7 | -6.5 | -0.1 | 0.2 | -8.7 | 8.7 | 5 |

Les valeurs sont celles imprimées dans la Table D CH3, page 07. Elles rendent
qualifiées à 2 950 m les corrections de météo et de température poudre, y
compris la correction de réglage M772 issue de la Table F.

## Garde-fous d’import

`tool/import_m819_ch3_table_d_page05_page07_factors.py` :

- ne crée aucune ligne de distance ;
- exige les huit valeurs source pour chaque ligne importée ;
- refuse toute divergence sauf la correction explicitement auditée de 2 900 m ;
- actualise `SOURCES.sha256` après écriture ;
- laisse toutes les lignes hors 2 100–3 575 m à `null`.
