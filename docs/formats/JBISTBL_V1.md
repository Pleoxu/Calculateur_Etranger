# JBISTBL_V1

Format binaire des tables **Jbis**.

## Objet

Table Jbis : correction de tempage liée à la température de munition.

Elle est utilisée par `TempageService` pour calculer la correction RTC/Jbis en fonction :

- du tempage de référence ;
- de la température munition.

## Pipeline

```text
JSON source
    ↓
JBISTBL_V1
    ↓
gzip
    ↓
AES-256-GCM
```

## Fichiers

### CAESAR historique

```text
assets/secure/tableaux/Jbis/JBIS_APPUI_CH7.jbistbl.gz
assets/secure_enc/tableaux/Jbis/JBIS_APPUI_CH7.jbistbl.gz.enc
```

### MO

```text
assets/secure/tableaux/MO/Jbis/MO_JBIS_APPUI_CH7.jbistbl.gz
assets/secure_enc/tableaux/MO/Jbis/MO_JBIS_APPUI_CH7.jbistbl.gz.enc
```

### MEPAC

```text
assets/secure/tableaux/MEPAC/Jbis/MEPAC_JBIS_APPUI_CH7.jbistbl.gz
assets/secure_enc/tableaux/MEPAC/Jbis/MEPAC_JBIS_APPUI_CH7.jbistbl.gz.enc
```

## Header

```text
magic       4 bytes   ASCII "JBIS"
version     uint8     1
tempCount   uint8     nombre de colonnes température
rowCount    uint32    little endian
temps       int16[]   tempCount valeurs, little endian
```

Taille header :

```text
10 + tempCount × 2 bytes
```

## Row

Chaque ligne correspond à un tempage de référence.

```text
tempageS    float32   little endian
values      float32[] tempCount valeurs, little endian
```

Taille ligne :

```text
4 + tempCount × 4 bytes
```

## Ordre des données

Les valeurs sont encodées dans cet ordre :

```text
for row in rows:
    write tempageS
    for temp in temps:
        write correctionByTemp[temp]
```

## Types

| Champ | Type | Description |
|---|---|---|
| magic | ASCII[4] | `JBIS` |
| version | uint8 | `1` |
| tempCount | uint8 | nombre de températures |
| rowCount | uint32 LE | nombre de lignes |
| temps | int16 LE[] | températures munition |
| tempageS | float32 LE | tempage de référence |
| correction | float32 LE | correction associée |

## Validation

Le lecteur doit vérifier :

```text
magic == "JBIS"
version == 1
bytes.length == 10 + tempCount×2 + rowCount×(4 + tempCount×4)
```

## Exemple logique

```json
[
  {
    "tempageS": 30.0,
    "corrByTemp": {
      "-20": -0.3,
      "0": -0.1,
      "20": 0.0,
      "40": 0.2
    }
  }
]
```

## Décodage utilisé par TempageService

Le lecteur actuel attend exactement :

```dart
magic = "JBIS"
version = 1
tempCount = uint8
rowCount = uint32
temps = int16[tempCount]

for each row:
  tempageS = float32
  values[temp] = float32
```
