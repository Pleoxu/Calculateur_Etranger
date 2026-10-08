# DTBL_V1

Format binaire de la table D.

## Objectif

Stockage compact des corrections liées à l’écart d’altitude.

La table D est commune à toutes les charges et tous les types de tir.

---

# Pipeline

```text
JSON source
    ↓
DTBL_V1
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
DTBL
```

Hex :

```text
44 54 42 4C
```

Version :

```text
1
```

---

# Row

Taille : 6 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 2 | int16 LE | delta_alt_m |
| 2 | 2 | int16 LE | dc_tb_pct |
| 4 | 2 | int16 LE | dc_pb_pct |

---

# Encodage

## delta_alt_m

Stocké en mètres entiers.

Exemple :

```text
400.0 → 400
```

## dc_tb_pct / dc_pb_pct

Stockés en dixièmes de pourcent :

```text
valeur JSON × 10
```

Exemples :

```text
-0.9 → -9
-3.8 → -38
0.0  → 0
```

---

# Taille totale

```text
headerSize + rowCount × rowSize
```

Avec :

```text
headerSize = 9
rowSize = 6
```

---

# Compression

Le fichier DTBL_V1 est toujours compressé :

```text
gzip
```

Extension :

```text
.dtbl.gz
```

---

# Manifest

```json
{
  "id": "D",
  "family": "D",
  "format": "DTBL_V1",
  "rows": 41,
  "file": "tableaux/D/D.dtbl.gz",
  "keyVersion": 0
}
```

---

# Validation

## Header

- magic == `DTBL`
- version == `1`
- taille cohérente avec `rowCount`

## Rows

- `delta_alt_m` croissant
- `delta_alt_m` multiple de 10
- `dc_tb_pct` encodable en dixièmes
- `dc_pb_pct` encodable en dixièmes

---

# Endianness

Toutes les valeurs numériques multi-octets sont :

```text
Little Endian
```