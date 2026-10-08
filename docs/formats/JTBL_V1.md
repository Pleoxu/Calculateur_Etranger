# JTBL_V1

Format binaire des tables **J**.

## Objet

Table J : coefficients de correction du tempage en fonction du tempage de référence.

Elle est utilisée par `TempageService` pour calculer les corrections :

- vitesse initiale (`V0-`, `V0+`) ;
- vent longitudinal (`Vent-`, `Vent+`) ;
- température balistique (`Temp-`, `Temp+`) ;
- pression / densité balistique (`Pression-`, `Pression+`) ;
- masse projectile (`Masse-`, `Masse+`).

Le tempage de référence est généralement obtenu depuis le tableau F puis arrondi à la seconde.

---

## Pipeline

```text
JSON source
    ↓
JTBL_V1
    ↓
gzip
    ↓
AES-256-GCM
```

---

## Fichiers

### CAESAR historique

```text
assets/secure/tableaux/J/J_APPUI_CH7.jtbl.gz
assets/secure_enc/tableaux/J/J_APPUI_CH7.jtbl.gz.enc
```

### MO

```text
assets/secure/tableaux/MO/J/MO_J_APPUI_CH7.jtbl.gz
assets/secure_enc/tableaux/MO/J/MO_J_APPUI_CH7.jtbl.gz.enc
```

### MEPAC

```text
assets/secure/tableaux/MEPAC/J/MEPAC_J_APPUI_CH7.jtbl.gz
assets/secure_enc/tableaux/MEPAC/J/MEPAC_J_APPUI_CH7.jtbl.gz.enc
```

---

## Header

Taille : 10 bytes.

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | ASCII | magic |
| 4 | 1 | uint8 | version |
| 5 | 1 | uint8 | subtype |
| 6 | 4 | uint32 LE | rowCount |

Magic :

```text
JTBL
```

Version :

```text
1
```

Subtype actuel :

```text
0
```

Le champ `subtype` est réservé pour compatibilité future.

---

## Row

Taille : 44 bytes.

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | float32 LE | tempageS |
| 4 | 4 | float32 LE | correctionV0Moins |
| 8 | 4 | float32 LE | correctionV0Plus |
| 12 | 4 | float32 LE | correctionVentMoins |
| 16 | 4 | float32 LE | correctionVentPlus |
| 20 | 4 | float32 LE | correctionTempMoins |
| 24 | 4 | float32 LE | correctionTempPlus |
| 28 | 4 | float32 LE | correctionPressionMoins |
| 32 | 4 | float32 LE | correctionPressionPlus |
| 36 | 4 | float32 LE | correctionMasseMoins |
| 40 | 4 | float32 LE | correctionMassePlus |

---

## Ordre des champs

L'ordre binaire doit rester exactement celui-ci :

```text
tempageS
correctionV0Moins
correctionV0Plus
correctionVentMoins
correctionVentPlus
correctionTempMoins
correctionTempPlus
correctionPressionMoins
correctionPressionPlus
correctionMasseMoins
correctionMassePlus
```

Cet ordre correspond au lecteur actuel dans `TempageService`.

---

## JSON source recommandé

```json
{
  "meta": {
    "typeTir": "Appui",
    "charge": "CH7",
    "tableau": "J"
  },
  "rows": [
    {
      "tempageS": 30.0,
      "correctionV0Moins": 0.0,
      "correctionV0Plus": 0.0,
      "correctionVentMoins": 0.0,
      "correctionVentPlus": 0.0,
      "correctionTempMoins": 0.0,
      "correctionTempPlus": 0.0,
      "correctionPressionMoins": 0.0,
      "correctionPressionPlus": 0.0,
      "correctionMasseMoins": 0.0,
      "correctionMassePlus": 0.0
    }
  ]
}
```

Un format JSON en tableau direct est aussi acceptable si le générateur sait lire :

```json
[
  {
    "tempageS": 30.0,
    "correctionV0Moins": 0.0,
    "correctionV0Plus": 0.0
  }
]
```

---

## Validation

Le lecteur doit vérifier :

```text
magic == "JTBL"
version == 1
bytes.length == 10 + rowCount × 44
```

Les lignes doivent être triées par `tempageS` croissant.

---

## Décodage utilisé par TempageService

Le lecteur actuel attend exactement :

```dart
magic = "JTBL"
version = 1
subtype = uint8
rowCount = uint32

for each row:
  tempageS = float32
  correctionV0Moins = float32
  correctionV0Plus = float32
  correctionVentMoins = float32
  correctionVentPlus = float32
  correctionTempMoins = float32
  correctionTempPlus = float32
  correctionPressionMoins = float32
  correctionPressionPlus = float32
  correctionMasseMoins = float32
  correctionMassePlus = float32
```

---

## Endianness

Toutes les valeurs numériques multi-octets sont en :

```text
Little Endian
```
