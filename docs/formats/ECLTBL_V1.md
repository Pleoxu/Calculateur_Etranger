# ECLTBL_V1

Format binaire des tables ECL.

## Objectif

Stockage compact des tables ECL contenant :

- portée
- hausse
- correction hausse +50 m
- correction évent +50 m
- indicateur tir montagne

La table ECL est spécifique à :

- un type de tir
- une charge

---

# Pipeline

```text
JSON source
    ↓
ECLTBL_V1
    ↓
gzip
    ↓
asset sécurisé
```

---

# Header

Taille : 9 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | ASCII | magic |
| 4 | 1 | uint8 | version |
| 5 | 4 | uint32 LE | rowCount |

Magic :

```text
ECLT
```

Version :

```text
1
```

---

# Row

Taille : 11 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 2 | uint16 LE | portee_m |
| 2 | 2 | int16 LE | hausse_mil |
| 4 | 2 | int16 LE | corr_hausse_+50m_mil |
| 6 | 2 | int16 LE | corr_event_+50m_mil |
| 8 | 1 | uint8 | flags |
| 9 | 2 | uint16 LE | reserved |

---

# Encodage

## portee_m

Stocké en mètres entiers.

Exemple :

```text
8500.0 → 8500
```

## hausse_mil

Stocké en centièmes de mil :

```text
valeur JSON × 100
```

Exemple :

```text
412.657 → 41266
```

## corr_hausse_+50m_mil

Stocké en centièmes de mil :

```text
valeur JSON × 100
```

Exemple :

```text
12.692 → 1269
-16.014 → -1601
```

## corr_event_+50m_mil

Stocké en centièmes de mil :

```text
valeur JSON × 100
```

Exemple :

```text
0.07 → 7
-0.97 → -97
```

---

# Flags

Type : `uint8`

| Bit | Signification |
|---:|---|
| 0 | tirMontagne |
| 1–7 | réservés |

Pour `ECLTBL_V1` :

```text
flags & ~0x01 == 0
```

---

# Tri recommandé

Les rows sont triées au build par :

```text
tirMontagne ASC
portee_m ASC
```

Donc :

```text
tirMontagne=false : portées croissantes
tirMontagne=true  : portées croissantes
```

Même si le JSON source contient la partie montagne en ordre décroissant.

---

# Manifest

```json
{
  "id": "ECL_OECL_CH1",
  "family": "ECL",
  "variant": "OECL",
  "charge": 1,
  "format": "ECLTBL_V1",
  "rows": 75,
  "file": "tableaux/ECL/ECL_OECL_CH1.ecltbl.gz",
  "keyVersion": 0
}
```

---

# Taille totale

```text
9 + rowCount × 11
```

---

# Validation

## Header

- magic == `ECLT`
- version == `1`
- taille cohérente avec `rowCount`

## Rows

- `portee_m` dans `[0,65535]`
- `hausse_mil ×100` dans `[-32768,32767]`
- `corr_hausse_+50m_mil ×100` dans `[-32768,32767]`
- `corr_event_+50m_mil ×100` dans `[-32768,32767]`
- flags inconnus à zéro
- tri par `tirMontagne`, puis `portee_m`

---

# Endianness

Toutes les valeurs numériques multi-octets sont :

```text
Little Endian
```