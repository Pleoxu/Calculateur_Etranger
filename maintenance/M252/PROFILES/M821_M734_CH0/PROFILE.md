# M252 — profil M821 / fusée M734 / charge 0

## Statut

**Profil M252 raccordé pour le couple M821 / fusée M734, charge 0, uniquement
dans le domaine qualifié 125–350 m.**

Le résolveur runtime sélectionne ce jeu complet A–E quand la munition **M821**
est choisie. Il ne peut pas mélanger ses tables avec celles de la charge 3.

## Sources brutes

Les cinq JSON d’origine sont conservés sans modification sous [`raw/`](raw/) avec leurs empreintes SHA-256 dans [`raw/SOURCES.sha256`](raw/SOURCES.sha256).

| Table | Rôle | Lignes | Contrôle notable |
|---|---|---:|---|
| A | composantes de vent | 65 | identique bit à bit à la Table A CH3 déjà intégrée |
| B | corrections air / densité | 41 | identique bit à bit à la Table B CH3 déjà intégrée |
| C | température de poudre / ΔV0 | 35 | référence : **70 °F = 21,1 °C**, ΔV0 = 0,0 m/s |
| D | trajectoire et coefficients | 18 | **`niveauMeteo = 1` dans les 18 lignes** |
| E | dispersion / trajectoire | 18 | l’écart probable de portée n’est pas publié à 83, 100, 400, 425, 450, 475 et 482 m |

## Ligne météo — Table D

Le builder reconnaît les deux noms de source suivants :

- `ligneMeteo` (sources CH3) ;
- `niveauMeteo` (sources CH0).

Ils désignent tous deux la colonne doctrinale **LINE NO.**. Pour ce profil, la valeur **1** est encodée dans les quatre bits hauts du flag DEBTL, sur toutes les lignes. Il n’y a ni défaut caché, ni recherche de la ligne la plus proche.

## Assets générés

Le builder `tool/build_m252_m821_m734_ch0_assets.dart` construit des assets clairs isolés sous :

```text
assets/secure/tableaux/foreign/m252/profiles/M821_M734_CH0/
```

et produit le fragment :

```text
assets/secure/manifest_foreign_m252_M821_M734_CH0.json
```

La Table E emploie **EEBTL_V2** : le bit 1 du flag marque une valeur `ecartProbablePortee` absente dans la source. Les zéros binaires associés ne signifient donc jamais « erreur probable nulle ».

## Domaine runtime qualifié

Les tables D/E couvrent 83–482 m, mais **125–350 m** est le seul intervalle
continu où les coefficients D nécessaires aux corrections et l’écart probable
de portée E sont tous publiés. Le calculateur refuse donc tout tir CH0 hors de
**125–350 m**, plutôt que d'interpoler une valeur non publiée.

## Construction et chiffrement

```bash
dart run tool/build_m252_m821_m734_ch0_assets.dart --project . --clean

dart run tool/merge_encrypt_m252_assets.dart \
  --project . \
  --fragment manifest_foreign_m252_M821_M734_CH0.json
```

Le mergeur remplace uniquement les entrées ayant le même identifiant de
registre ; il préserve les autres profils M252 et leurs assets chiffrés.
