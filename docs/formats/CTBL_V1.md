# CTBL_V1

Format binaire des tables C.

## Objectif

Stockage compact et versionné des coefficients :

- Wz
- Wx

Utilisé pour :
- calculs directionnels
- projections
- composantes trigonométriques
- calculs balistiques auxiliaires

Le format est :
- offline
- compact
- endian stable
- compatible FFI
- compatible runtime natif futur

---

# Pipeline

```text
JSON source
    ↓
CTBL_V1
    ↓
gzip
    ↓
asset sécurisé
```

---

# Header

## Taille

9 bytes

## Structure

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | ASCII | magic |
| 4 | 1 | uint8 | version |
| 5 | 4 | uint32 LE | rowCount |

---

# Magic

ASCII :

```text
CTBL
```

Hex :

```text
43 54 42 4C
```

---

# Version

Version actuelle :

```text
1
```

---

# Row

## Taille

6 bytes

## Structure

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 2 | uint16 LE | angle |
| 2 | 2 | uint16 LE | wz |
| 4 | 2 | uint16 LE | wx |

---

# Angle

## Type

```text
uint16 LE
```

## Domaine

```text
0 → 6400
```

## Contrainte

Multiple de :

```text
100
```

---

# Wz / Wx

## Encodage

Valeurs stockées :

```text
float × 100
```

Exemples :

| JSON | Binaire |
|---|---:|
| 0.00 | 0 |
| 0.29 | 29 |
| 0.71 | 71 |
| 1.00 | 100 |

---

# Taille totale

## Formule

```text
headerSize + rowCount × rowSize
```

## Valeurs

| Élément | Taille |
|---|---:|
| Header | 9 |
| Row | 6 |

---

# Exemple

## JSON

```json
{
  "300": {
    "Wz": 0.29,
    "Wx": 0.96
  }
}
```

## Binaire

| Champ | Valeur |
|---|---|
| angle | 300 |
| wz | 29 |
| wx | 96 |

---

# Compression

Le fichier CTBL_V1 est toujours compressé :

```text
gzip
```

Extension :

```text
.ctbl.gz
```

---

# Manifest

Exemple :

```json
{
  "id": "C",
  "family": "C",
  "format": "CTBL_V1",
  "rows": 65,
  "file": "tableaux/C/C.ctbl.gz",
  "keyVersion": 0
}
```

---

# Validation

## Header

- magic == CTBL
- version == 1
- taille cohérente

## Rows

- angles triés croissants
- angle multiple de 100
- angle dans [0,6400]
- wz dans [0,100]
- wx dans [0,100]

## Validation mathématique

Tolérance :

```text
(Wz² + Wx²) ≈ 1
```

avec :

```text
tolérance ±0.08
```

---

# Endianness

Toutes les valeurs numériques sont :

```text
Little Endian
```

---

# Compatibilité future

Les versions futures pourront ajouter :

- CRC32
- checksum bloc
- chiffrement AES
- packing multi-tables
- index mémoire natif

sans modifier la logique métier Flutter.