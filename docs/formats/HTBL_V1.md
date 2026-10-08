# HTBL_V1

Format binaire des tables H — rotation de la Terre.

> Spécification reconstruite et validée à partir de `MO_H_APPUI_CH0.json`,
> `MO_H_APPUI_CH0.htbl.gz` et `MO_H_APPUI_CH0.htbl.gz.enc`.

## Objectif

Stockage compact et versionné des corrections de portée liées à la rotation de la Terre,
par :

- type de tir ;
- charge ;
- distance ;
- azimut ;
- zone de tir (`tirMontagne`).

Les facteurs de latitude présents dans les métadonnées JSON ne sont pas stockés dans
le fichier HTBL_V1 observé. Ils doivent rester gérés par le service ou par une autre
source de configuration.

---

# Pipeline

```text
JSON source
    ↓
HTBL_V1
    ↓
gzip
    ↓
AES-256-GCM
```

Extensions :

```text
.htbl
.htbl.gz
.htbl.gz.enc
```

---

# Header fixe

## Taille

```text
10 bytes
```

## Structure

| Offset | Taille | Type | Champ |
|---:|---:|---|---|
| 0 | 4 | ASCII | magic |
| 4 | 1 | uint8 | version |
| 5 | 1 | uint8 | reserved |
| 6 | 2 | uint16 LE | rowCount |
| 8 | 2 | uint16 LE | azimuthCount |

## Magic

```text
HTBL
```

Hexadécimal :

```text
48 54 42 4C
```

## Version

```text
1
```

## Reserved

Pour HTBL_V1 :

```text
0
```

---

# Liste des azimuts

Immédiatement après le header fixe :

```text
azimuthCount × uint16 LE
```

Les azimuts sont stockés en millièmes, triés dans l’ordre utilisé par les lignes.

Exemple observé :

```text
0, 200, 400, ..., 6400
```

Soit :

```text
33 azimuts
```

La taille de l’en-tête complet est donc :

```text
10 + azimuthCount × 2
```

Pour 33 azimuts :

```text
10 + 33 × 2 = 76 bytes
```

---

# Row

## Taille dynamique

```text
4 + azimuthCount × 4 + 1
```

Pour 33 azimuts :

```text
4 + 33 × 4 + 1 = 137 bytes
```

## Structure

| Ordre | Taille | Type | Champ |
|---:|---:|---|---|
| 1 | 4 | float32 LE | distance |
| 2 | azimuthCount × 4 | float32 LE | corrections par azimut |
| 3 | 1 | uint8 | flags |

Les corrections sont écrites exactement dans l’ordre de la liste des azimuts du header.

---

# Valeurs manquantes

Une correction absente ou `null` doit être encodée en :

```text
NaN float32
```

Même si le JSON CH0 observé ne contient pas de correction manquante, cette convention
est recommandée pour rester cohérent avec les autres formats binaires de l’application.

---

# Flags

Type :

```text
uint8
```

| Bit | Signification |
|---:|---|
| 0 | tirMontagne |
| 1 à 7 | réservés |

Encodage :

```text
tirMontagne=false → flags & 0x01 == 0
tirMontagne=true  → flags & 0x01 == 1
```

Pour HTBL_V1, les bits inconnus doivent rester à zéro :

```text
flags & ~0x01 == 0
```

---

# Taille totale

## Formule

```text
10
+ azimuthCount × 2
+ rowCount × (4 + azimuthCount × 4 + 1)
```

## Exemple CH0 observé

```text
rowCount = 8
azimuthCount = 33
header complet = 76 bytes
row = 137 bytes

76 + 8 × 137 = 1172 bytes
```

La taille décompressée vérifiée du fichier fourni est bien :

```text
1172 bytes
```

---

# Compression

Le fichier HTBL_V1 est compressé avec :

```text
gzip
```

Extension :

```text
.htbl.gz
```

---

# Chiffrement

Le fichier gzip est chiffré avec :

```text
AES-256-GCM
```

Format du fichier final :

```text
nonce de 12 bytes
+ ciphertext
+ tag GCM de 16 bytes
```

AAD :

```text
None
```

Extension :

```text
.htbl.gz.enc
```

Chaque chiffrement doit utiliser un nonce aléatoire unique.

---

# Validation

## Header

- `magic == HTBL`
- `version == 1`
- `reserved == 0`
- `rowCount > 0`
- `azimuthCount > 0`

## Azimuts

- valeurs encodables en `uint16`
- valeurs triées selon l’ordre attendu par le runtime
- absence de doublon

## Rows

- taille cohérente avec `azimuthCount`
- `distance` encodable en `float32`
- nombre de corrections égal à `azimuthCount`
- seuls les bits autorisés sont utilisés dans `flags`

## Taille

```text
taille ==
10 + azimuthCount × 2
   + rowCount × (4 + azimuthCount × 4 + 1)
```

---

# Structure JSON acceptée

```json
{
  "meta": {
    "typeTir": "Appui",
    "charge": "CH0",
    "latitudeFacteurs": {
      "10": 0.98,
      "20": 0.94,
      "30": 0.87,
      "40": 0.77,
      "50": 0.64,
      "60": 0.50,
      "70": 0.34
    }
  },
  "rows": [
    {
      "distance": 1200.0,
      "0": 0.0,
      "200": 0.0,
      "400": -1.0,
      "6400": 0.0,
      "tirMontagne": false
    }
  ]
}
```

Les clés numériques de chaque ligne correspondent aux azimuts.

---

# Endianness

Toutes les valeurs numériques multi-octets sont :

```text
Little Endian
```
