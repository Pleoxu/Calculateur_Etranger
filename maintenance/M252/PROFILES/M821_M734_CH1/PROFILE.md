# M252 — profil M821 / fusée M734 / charge 1

## Statut

**PDF CH1 audité, sources A–E mises en maintenance, assets construits et profil runtime qualifié.**

Le profil est identifié exclusivement par **`M821_M734_CH1`**. Il couvre les couples de cartouche/fusée que le FT 81-AR-2 rassemble dans le même tableau de charge : **M821A1/M734** et **M821A2/M734A1**.

## Sources brutes

Les cinq tables sont conservées sous [`raw/`](raw/) et scellées par [`raw/SOURCES.sha256`](raw/SOURCES.sha256).

| Table | Rôle | Provenance / contrôle |
|---|---|---|
| A | composantes du vent | Table M252 commune, reprise à l’identique depuis CH0/CH3 (même SHA-256). |
| B | transfert station météo → pièce | Table M252 commune, reprise à l’identique depuis CH0/CH3 (même SHA-256). |
| C | température poudre / ΔV0 | 35 lignes, −40 à +130 °F, référence 70 °F = 0,0 m/s. |
| D | trajectoire et corrections | 71 lignes, 347 à 2060 m ; `niveauMeteo` est la colonne doctrinale `LINE NO.`. |
| E | dispersion / données terminales | 71 lignes, 347 à 2060 m ; correction auditée : à 500 m, erreur probable de direction = **+4 m**. |

## Domaine runtime qualifié

**450 à 1875 m**, bornes incluses.

Il s’agit du seul intervalle continu où :

- Table D publie les deux sens des corrections V0, vent, température et densité ;
- Table E publie l’écart probable de portée ;
- les cinq tables restent dans leur domaine source.

Les lignes 347–425 m et 1900–2060 m sont conservées dans les assets pour fidélité source mais ne sont **pas** activées au runtime, car au moins une donnée de correction nécessaire ou l’écart probable de portée n’y est pas publié.

## Ligne météo — Table D

`niveauMeteo` est encodé sans inférence : **ligne 03** de 347 à 1900 m, puis ligne 02 au-delà. Le domaine runtime 450–1875 m utilise donc exclusivement **LINE NO. 03**.

## Construction

```bash
dart run tool/build_m252_m821_m734_ch1_assets.dart --project . --clean

dart run tool/merge_encrypt_m252_assets.dart \
  --project . \
  --fragment manifest_foreign_m252_M821_M734_CH1.json
```
