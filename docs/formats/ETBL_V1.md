# ETBL_V1

Format binaire des tables E.

## Objectif

Stockage compact des corrections de vitesse initiale selon la température poudre.

La table E est spécifique à :

- un type de tir
- une charge

---

# Pipeline

```text
JSON source
    ↓
ETBL_V1
    ↓
gzip
    ↓
asset sécurisé
```

---

# Header

Taille : 11 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 4 | ASCII | magic |
| 4 | 1 | uint8 | version |
| 5 | 4 | uint32 LE | rowCount |
| 9 | 2 | int16 LE | deltaV_per_carreau_ms |

Magic :

```text
ETBL
```

Version :

```text
1
```

---

# Row

Taille : 4 bytes

| Offset | Taille | Type | Champ |
|---|---:|---|---|
| 0 | 2 | int16 LE | tempPoudre |
| 2 | 2 | int16 LE | deltaVo_temp |

---

# Encodage

## deltaV_per_carreau_ms

Stocké en dixièmes de m/s :

```text
valeur JSON × 10
```

Exemple :

```text
-2.6 → -26
```

## tempPoudre

Stocké en degrés Celsius entiers :

```text
60.0 → 60
-40.0 → -40
```

## deltaVo_temp

Stocké en dixièmes de m/s :

```text
3.9  → 39
-6.1 → -61
```

---

# Manifest

```json
{
  "id": "E_APPUI_CH2",
  "family": "E",
  "variant": "APPUI",
  "charge": 2,
  "format": "ETBL_V1",
  "rows": 22,
  "file": "tableaux/E/E_APPUI_CH2.etbl.gz",
  "keyVersion": 0
}
```