# Effets terminaux

Ce dossier isole la construction de la géométrie d'effet autour d'un impact.

## Règle actuelle

Sans profil terminal validé pour une munition, le calcul utilise
`GenericGeometricEffectModel` :

- demi-petit axe = rayon d'efficacité nominal ;
- demi-grand axe = projection suivant l'angle de chute ;
- orientation = azimut terminal.

Les valeurs EPP/EPD restent des données de dispersion et ne pilotent pas
directement la géométrie d'efficacité.

## Extension future

Un profil validé peut être fourni à `TerminalEffectFactory` afin d'utiliser
`MunitionTerminalEffectModel`.
