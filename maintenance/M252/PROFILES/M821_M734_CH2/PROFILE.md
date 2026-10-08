# M252 — profil M821 / fusée M734 / charge 2

## Statut

**PDF CH2 audité, sources A–E mises en maintenance, assets construits puis profil runtime qualifié.**

Le profil est identifié exclusivement par **`M821_M734_CH2`**. Dans le catalogue M252 déjà exposé par l’application, il alimente les mêmes couples que CH1 et CH3 : **M821A1/M734** et **M821A2/M734A1**. Le PDF fourni porte l’en-tête source **CTG, HE, M821 / FUZE, MO, M734**.

## Sources brutes

Les cinq sources sont conservées sous [`raw/`](raw/) et scellées par [`raw/SOURCES.sha256`](raw/SOURCES.sha256).

| Table | Rôle | Contrôle PDF |
|---|---|---|
| A | composantes du vent | Table M252 commune, reprise bit à bit depuis CH1/CH3. |
| B | transfert station météo → pièce | Table M252 commune, reprise bit à bit depuis CH1/CH3. |
| C | température poudre / ΔV0 | 35 lignes, −40 à +130 °F ; 70 °F = 0,0 m/s. |
| D | trajectoire et corrections | 92 lignes, 1125 à 3400 m ; `niveauMeteo` est la colonne `LINE NO.`. |
| E | dispersion et données terminales | 92 lignes, 1125 à 3400 m ; l’erreur probable de portée cesse d’être publiée après 3275 m. |

L’audit source est conservé dans [`evidence/CH2_JSON_PDF_AUDIT.md`](evidence/CH2_JSON_PDF_AUDIT.md).

## Domaine runtime qualifié

**1125 à 3125 m**, bornes incluses.

Cet intervalle est le plus large intervalle continu où :

- Table D publie les deux sens des corrections V0, vent, température et densité, ainsi que le pas et les tours ;
- Table E publie l’écart probable de portée ;
- les cinq tables restent dans leur domaine source.

Les lignes 3150–3400 m restent archivées et construites pour fidélité au PDF mais ne sont pas exposées : la correction V0 « DEC » n’est plus publiée à partir de 3150 m, puis d’autres colonnes deviennent indisponibles.

## Lignes météo — Table D

`niveauMeteo` est transcrit sans calcul ni valeur par défaut :

| Domaine source | `LINE NO.` |
|---|---:|
| 1125–1250 m | 05 |
| 1275–3175 m | 04 |
| 3200–3400 m | 03 |

Le domaine runtime utilise donc les lignes **05** puis **04**.

## Construction

```bash
dart run tool/build_m252_m821_m734_ch2_assets.dart --project . --clean

dart run tool/merge_encrypt_m252_assets.dart \
  --project . \
  --fragment manifest_foreign_m252_M821_M734_CH2.json
```
