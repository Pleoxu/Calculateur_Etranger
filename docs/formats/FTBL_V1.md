# FTBL_V1

Format binaire des tables F.

## Pipeline

```text
JSON source
    ↓
FTBL_V1
    ↓
gzip
    ↓
AES-256-GCM
```

## Header

Taille : 9 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | ASCII | magic |
| 4 | 1 | uint8 | version |
| 5 | 4 | uint32 LE | rowCount |

Magic : `FTBL`

Version : `1`

## Row

Taille : 69 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | float32 LE | distance |
| 4 | 4 | float32 LE | hausse |
| 8 | 4 | float32 LE | derive |
| 12 | 4 | float32 LE | correctionWz |
| 16 | 4 | float32 LE | dAE_per_100m |
| 20 | 4 | float32 LE | correctionV0Moins |
| 24 | 4 | float32 LE | correctionV0Plus |
| 28 | 4 | float32 LE | correctionVentMoins |
| 32 | 4 | float32 LE | correctionVentPlus |
| 36 | 4 | float32 LE | correctionTempMoins |
| 40 | 4 | float32 LE | correctionTempPlus |
| 44 | 4 | float32 LE | correctionPressionMoins |
| 48 | 4 | float32 LE | correctionPressionPlus |
| 52 | 4 | float32 LE | correctionMasseMoins |
| 56 | 4 | float32 LE | correctionMassePlus |
| 60 | 4 | float32 LE | tempageS |
| 64 | 4 | float32 LE | varHaussePour100m |
| 68 | 1 | uint8 | flags |

## Valeurs manquantes

Les champs absents du JSON sont encodés en `NaN` float32.

## Flags

| Bit | Signification |
|---:|---|
| 0 | tirMontagne |
| 1-7 | réservés |

`tirMontagne=false → flags & 0x01 == 0`

`tirMontagne=true → flags & 0x01 == 1`

## Validation

- magic == `FTBL`
- version == `1`
- taille == `9 + rowCount × 69`
- flags inconnus à zéro : `flags & ~0x01 == 0`

## Données CH7 générées

- rowCount : 28
- taille FTBL : 1941 bytes
