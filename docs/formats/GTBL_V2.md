# GTBL_V2

Table G : correction complémentaire de site et données de dispersion balistique.

Cette table existe uniquement pour :

```text
Appui
AppuiRTC
```

Pas de table G pour OECL, car OECL utilise une formule spécifique.

## Fichiers source

```text
Tableau_G_<TYPE>_<CHARGE>.json
```

Exemples :

```text
Tableau_G_Appui_CH1.json
Tableau_G_Appui_CH6.json
Tableau_G_AppuiRTC_CH1.json
Tableau_G_AppuiRTC_CH6.json
```

## Structure JSON source

Le builder accepte actuellement une racine JSON de type liste :

```json
[
  {
    "distance": 4000.0,
    "hausse": 211.66,
    "ecartProbablePortee": 16.30,
    "ecartProbableDirection": 2.23,
    "ecartProbableHauteurEclatement": null,
    "ecartProbableDelaiEclatement": null,
    "ecartProbablePorteeEclatement": null,
    "angleChuteMil": 231.45,
    "cotAngleChute": 4.3249,
    "vitesseRestante": 286.47,
    "fleche": 220.89,
    "correctionComplementSiteAnglePlus": 0.0024,
    "correctionComplementSiteAngleMoins": -0.0412,
    "tirMontagne": false
  }
]
```

## Binaire

### Header

```text
magic       4 bytes   "GTBL"
version     uint8     2
rowCount    uint32    little endian
```

### Row

```text
distance                              float32
hausse                                float32
ecartProbablePortee                   float32
ecartProbableDirection                float32
ecartProbableHauteurEclatement        float32
ecartProbableDelaiEclatement          float32
ecartProbablePorteeEclatement         float32
angleChuteMil                         float32
cotangenteAngleChute                  float32
vitesseRestante                       float32
fleche                                float32
correctionComplementSiteAnglePlus     float32
correctionComplementSiteAngleMoins    float32
flags                                 uint8
reserved                              uint16
```

### Flags

```text
bit0 = tirMontagne
```

## Taille

```text
header = 9 bytes
row    = 55 bytes
```

## Utilisation ellipse réelle

- `angleChuteMil` est stocké en millièmes.
- Conversion degrés : `angleChuteMil * 360 / 6400`.
- Le demi-grand axe de l'ellipse réelle utilise `ecartProbablePortee` projeté avec l'angle de chute.
- Le demi-petit axe utilise `ecartProbableDirection`.
- L'ellipse est dessinée avec le demi-grand axe sur l'axe X local, puis rotée selon l'azimut du tir.
