# Audit de schéma — RP M819 / M772, Table E

**Statut : blocage de qualification — ne pas utiliser pour une géométrie de dépotage, un écran fumigène, une RED, ni un calcul terminal.**

## Références contrôlées

- FT 81-AR-2, définition de la **Table E — Supplementary Data** fournie le 5 octobre 2026.
- Pages source locales identifiées par l’OCR :
  - CH1 : `Tables_CH1_RPM819_FuM772-7/8` ;
  - CH2 : `Tables_CH2_RPM819_FuM772-09/10/11` ;
  - CH3 : `Tables_CH3_RPM819_FuM772-10/11/12/13` ;
  - CH4 : `Tables_CH4_RPM819_FuM772-12/13/14`.

Le FT définit les colonnes suivantes :

| Colonne FT | Donnée attendue | État du JSON actuel |
|---:|---|---|
| 1 | Range | `distance` — nom compatible uniquement |
| 2 | Elevation | `hausse` — nom compatible uniquement |
| 3 | Probable Error in Range to Impact | **absent** |
| 4 | Probable Error in Deflection at Impact | **absent** |
| 5 | Angle of Fall | **absent** |
| 6 | Cotangent of Angle of Fall | **absent** |
| 7 | Terminal Velocity | **absent** |
| 8 | Maximum Ordinate | **absent** |

## Constat

Les JSON actifs utilisent à la place un schéma de **table d’effet à deux dépotages** :

```text
hausse
élevation/variation de fusée pour +50 m d’éclatement
élevation/variation de fusée pour +100 m de portée d’éclatement
flèche
distanceImpact
```

Ce schéma ne correspond pas à la Table E du FT 81-AR-2. Il ne permet donc pas d’interpréter avec sûreté `fleche` comme *Maximum Ordinate*, ni `distanceImpact` comme une donnée publiée de déploiement, ni les corrections de fusée comme les colonnes 3 à 7 de la Table E.

Exemple révélateur : CH4 / 3 250 m contient `hausse=1232`, `fleche=2510`, `distanceImpact=3257` et des corrections de fusée, mais **aucune** erreur probable, angle de chute, cotangente ou vitesse terminale.

## Couverture du schéma erroné actuellement chargé

| Profil | Lignes | Plage | Champs non-portée complètement renseignés |
|---|---:|---:|---|
| CH1 | 52 | 300–1 575 m | 48 à 52 selon le champ |
| CH2 | 77 | 950–2 850 m | 73 à 77 selon le champ |
| CH3 | 107 | 1 325–3 975 m | 32 seulement ; lacune à partir de 2 125 m |
| CH4 | 134 | 1 625–4 950 m | 60 à 64 selon le champ |

## Décision de sûreté mise en œuvre

Le pipeline RP M819/M772 ne propage plus les deux champs issus de ce schéma (`trajectoryHeightM` vers `flecheM`, et `elevationForBurstHeight50mMil` vers `corrEclPour50mMil`). Les réglages de portée, dérive, météo et fusée M772 restent exclusivement issus des Tables **A, B, C, D et F** qualifiées.

La carte de message représente donc :

- **éclairant** : une empreinte nominale publiée centrée sur le début effectif de l’éclairement / second dépotage, avec durée et enveloppe verticale explicites ;
- **RP M819** : l’événement M772 au point calculé, **sans cercle ou rideau fumigène inventé**.

## Reconstruction requise avant exploitation de la Table E

1. Transcrire les pages Table E du FT pour CH1 à CH4 dans une source brute versionnée sous `maintenance` ; chaque cellule doit être reliée à une page et une plage de distances.
2. Utiliser un JSON canonique distinct, par exemple :

```json
{
  "distance": 3250,
  "elevation": 1232,
  "probableRangeErrorM": null,
  "probableDeflectionErrorM": null,
  "angleOfFall": null,
  "cotangentAngleOfFall": null,
  "terminalVelocityMps": null,
  "maximumOrdinateM": null
}
```

3. Ne renseigner que les valeurs imprimées et visuellement vérifiées. Les unités exactes de l’angle doivent être portées dans la note de source ; aucune conversion mil/degré ne doit être supposée.
4. Créer un codec binaire Table E **nouveau et versionné** : l’actuel `M8E1` a neuf champs facultatifs correspondant au mauvais schéma. Ne pas réemployer ses positions sémantiques.
5. Ajouter des tests de décodage, de bornes, d’interpolation et de correspondance PDF avant de reconstruire/chiffrer les assets et le manifeste.
6. Les données de la Table E sont terminales au **point de niveau / impact**. Elles ne déterminent pas à elles seules la position du premier dépotage M772 ou la dispersion des palets de phosphore rouge ; cette représentation exige une donnée propre de déploiement/trajectoire, publiée pour la munition concernée.
