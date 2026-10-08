# M252 — profil `M821_M734_CH3`

## Identité du profil

**ID de profil : `M821_M734_CH3`**

Ce nom identifie le **couple de munitions/fusées** et la **charge M220**. Il
est volontairement indépendant de la pagination du manuel : les mêmes tables
s’appliquent aux deux couples :

- **M821A1 / M734** ;
- **M821A2 / M734A1**.

## Référence documentaire

Le **FT 81-AR-2, Part 6** est le chapitre de référence de la famille entière :
il regroupe les charges M220 **CH0 à CH4** (66, 149, 208, 259 et 305 m/s).

> `Part 6` est donc une **source documentaire** ; ce n’est pas l’identité de
> ce profil. La convention d’implémentation est `M821_M734_CHx`.

Les cinq JSON bruts de CH3 sont la seule base source active :

```text
maintenance/M252/PROFILES/M821_M734_CH3/raw/
```

`raw/SOURCES.sha256` fixe les empreintes des sources. Toute modification d’une
source doit être documentée, puis doit mettre à jour cette empreinte avant de
pouvoir être construite.

| Table | Format généré | Lignes | Rôle |
|---|---|---:|---|
| A | `AEBTL_V1` | 65 | composantes de vent Wz / Wx |
| B | `BEBTL_V1` | 41 | correction air / densité |
| C | `CEBTL_V1` | 35 | température de poudre / ΔV0 |
| D | `DEBTL_V2` | 125 | trajectoire, coefficients et `LINE NO.` météo |
| E | `EEBTL_V1` | 33 | dispersion, angle de chute et vitesse résiduelle |

### Ligne météo — Table D

La Table D CH3 encode exclusivement les niveaux doctrinaux **4** et **5** :
**12 lignes à 4** et **113 lignes à 5**. Ils sont lus sans défaut ni
substitution dans le champ `ligneMeteo`, puis encodés dans DEBTL.

L’audit de transcription de la Table C est conservé dans
[`evidence/FT81_AR2_CH3_TABLE_C_AUDIT.md`](evidence/FT81_AR2_CH3_TABLE_C_AUDIT.md).

## Domaine de calcul qualifié

```text
1525 m ≤ distance topographique ≤ 2300 m
```

Le routeur de calcul utilise actuellement ce profil et uniquement les couples
M821A1/M734 et M821A2/M734A1 à la charge 3.

## Assets construits

Le builder produit exclusivement :

```text
assets/secure/tableaux/foreign/m252/profiles/M821_M734_CH3/
assets/secure_enc/tableaux/foreign/m252/profiles/M821_M734_CH3/
```

Le fragment associé est :

```text
assets/secure/manifest_foreign_m252_M821_M734_CH3.json
```

## Reconstruction

```bash
dart run tool/build_m252_ch3_assets.dart --project . --clean

dart run tool/merge_encrypt_m252_assets.dart \
  --project . \
  --fragment manifest_foreign_m252_M821_M734_CH3.json \
  --prune-legacy-m252
```

L’option `--prune-legacy-m252` ne doit être utilisée qu’après la construction
de ce profil et des autres profils que l’on souhaite conserver.
