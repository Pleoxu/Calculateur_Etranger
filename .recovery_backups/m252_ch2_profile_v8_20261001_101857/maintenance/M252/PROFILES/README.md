# Arborescence normalisée des profils M252

Chaque profil M252 est un **jeu de cinq tables indissociables**. Les tables A à E ne sont jamais chargées depuis des répertoires partagés ou plats.

```text
maintenance/M252/PROFILES/
├── M821_M734_CH3/
│   ├── raw/                 # cinq sources JSON actives + SOURCES.sha256
│   ├── evidence/            # audit et sources historiques associées
│   └── PROFILE.md           # statut, domaine et règles de construction
└── M821_M734_CH0/
    ├── raw/
    └── PROFILE.md

assets/secure/tableaux/foreign/m252/profiles/<profil>/A…E/
assets/secure_enc/tableaux/foreign/m252/profiles/<profil>/A…E/
```

## Règles

1. **`raw/` est la base source active** : aucune modification directe des fichiers binaires ou chiffrés.
2. Chaque changement de JSON exige la mise à jour de `raw/SOURCES.sha256` et la reconstruction du profil.
3. Les builders créent les assets clairs sous `assets/secure/.../profiles/<profil>/`.
4. Le mergeur chiffre ces mêmes assets et fusionne les entrées de manifest par identifiant de profil.
5. Les profils sont nommés `M821_M734_CHx`; « Part 6 » reste une référence documentaire couvrant CH0 à CH4. Seul **`M821_M734_CH3`** est actif ; **`M821_M734_CH0`** est conservé et chiffré, mais non calculable.

> Les anciens répertoires plats `foreign/m252/A` à `E` sont obsolètes et sont supprimés par `--prune-legacy-m252` après une reconstruction réussie.
