# MO81 M252 — pipeline Part 6 / CH3 de référence

## Objet

Ce lot ajoute le premier pipeline autonome pour le **MO81 M252**, limité à la **charge 3** de la Part 6. Le FT 81-AR-2 qualifie le même jeu de tables pour les couples **M821A1 / M734** et **M821A2 / M734A1**. Il ne lit aucune table CAESAR et n’utilise ni les codecs français BTBL/CTBL/DTBL, ni `BalistiqueAppuiService`.

## Sources contrôlées

Les cinq sources JSON restent dans `maintenance/M252/`. Elles sont contrôlées par SHA-256 avant chaque construction :

| Table | Format généré | Lignes | Rôle |
|---|---|---:|---|
| A | `AEBTL_V1` | 65 | Composantes de vent Wz / Wx |
| B | `BEBTL_V1` | 41 | Correction air / température / pression selon l’altitude |
| C | `CEBTL_V1` | 35 | Effet de la température de poudre sur V0 |
| D | `DEBTL_V1` | 125 | Trajectoire, coefficients et temps de vol |
| E | `EEBTL_V1` | 33 | Dispersion, angle de chute et vitesse restante |

Le manifest de contrôle est `maintenance/M252/sources_sha256_20260927.txt`.

> La Table C a été retranscrite contre le **FT 81-AR-2**, Part 6, page imprimée 407 / PDF 459. Voir `TABLE_C/FT81_AR2_CH3_TABLE_C_AUDIT.md` pour les points de contrôle et l’impact sur ΔV0.

## Domaine qualifié actuel

Le pipeline exige simultanément les tables D et E. Le domaine commun est donc strictement :

```text
1525 m ≤ distance topographique ≤ 2300 m
```

Il refuse volontairement :

- toute charge différente de `CH3` ;
- toute munition M252 différente de `M821A1 / M734` ou `M821A2 / M734A1` ;
- la branche montagne ;
- les corrections de masse projectile, de rotation et de V0 mesuré ;
- le tir éclairant M252, dont les tables ne sont pas encore chargées.

Ces limites évitent l’emploi implicite de coefficients français ou de données inexistantes.

## Construction et chiffrement

Depuis la racine du projet Flutter :

```bash
flutter pub get
dart run tool/build_m252_ch3_assets.dart --project . --clean
dart run tool/merge_encrypt_m252_assets.dart --project .
flutter test test/services/m252/m252_ch3_tables_test.dart
```

La première commande produit les `.gz` clairs, puis la seconde les chiffre avec **AES-256-GCM** dans `assets/secure_enc/tableaux/foreign/m252/` et fusionne les cinq entrées dans le manifest chiffré existant.

> Le chiffreur lit la clé localement depuis `macos/Runner/SecureKey.swift`. La clé n’est ni incluse dans les outils, ni affichée, ni copiée dans le manifest.

## Routage

```text
Systeme.mo81M252 + TypeTir.appui + (M821A1 / M734 ou M821A2 / M734A1) + CH3
  → BalistiqueMo81M252AppuiService
  → M252TableRepository
  → AEBTL / BEBTL / CEBTL / DEBTL / EEBTL
```

`TypeTir.eclairant` reste explicitement non raccordé pour le M252 tant que son jeu de tables distinct n’a pas été importé.
