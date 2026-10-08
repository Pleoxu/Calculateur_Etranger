# M252 — famille `M821_M734_CHx`

## Convention de nommage

Le **FT 81-AR-2, Part 6** couvre les cartouches HE **M821A1/M734** et
**M821A2/M734A1** pour les cinq charges M220. « Part 6 » est un repère de
manuel, pas un profil de données.

Chaque profil porte donc la convention stable :

```text
M821_M734_CH0
M821_M734_CH1
M821_M734_CH2
M821_M734_CH3
M821_M734_CH4
```

Les deux couples de cartouche/fusée utilisent les mêmes tables d’une charge
lorsque le manuel les réunit dans le même chapitre. Aucun jeu de données ne
doit être partagé entre deux **charges** sans preuve documentaire.

## Feuille de route par charge

| Profil | Vitesse initiale | État de source | État runtime |
|---|---:|---|---|
| `M821_M734_CH0` | 66 m/s | A–E importées et chiffrées | En attente de qualification |
| `M821_M734_CH1` | 149 m/s | À importer | Non exposé |
| `M821_M734_CH2` | 208 m/s | A–E importées, PDF C–E audité | **Actif de 1125 à 3125 m** |
| `M821_M734_CH3` | 259 m/s | A–E importées et validées | **Raccordé** |
| `M821_M734_CH4` | 305 m/s | À importer | Non exposé |

## Règle d’import

Pour une charge, les Tables **A, B, C, D et E** forment un seul profil :

1. placer les cinq JSON dans `maintenance/M252/PROFILES/<profil>/raw/` ;
2. créer ou actualiser `raw/SOURCES.sha256` ;
3. contrôler en-têtes, unités, bornes et valeurs de référence ;
4. construire AEBTL, BEBTL, CEBTL, DEBTL et EEBTL ;
5. chiffrer les cinq assets sous `assets/secure_enc/.../profiles/<profil>/` ;
6. ajouter le profil au runtime seulement après tests de référence et domaine.

## État de CH3

Le domaine vérifié de `M821_M734_CH3` est **1525 m à 2300 m**, intersection
des données D et E importées. La trace runtime journalise les clés neutres :

```text
m252Cartridge = M821A1 ou M821A2
m252Fuze      = M734 ou M734A1
```
