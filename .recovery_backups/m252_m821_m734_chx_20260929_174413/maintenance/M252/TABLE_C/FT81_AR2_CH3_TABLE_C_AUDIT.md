# Audit de source — Table C M252 Part 6, charge 3

## Source retenue

- **FT 81-AR-2**, Part 6, Table C, Charge 3 ;
- page imprimée **407**, page PDF **459** du document `983791261-81MM-TFT.pdf`.

La page porte l’en-tête :

```text
CTG, HE, M821A1     TABLE C     CHARGE 3
FUZE, MO, M734      PROPELLANT TEMPERATURE
```

La page d’ouverture de la Part 6 étend ce jeu de tables au couple **M821A2 / M734A1**.

## Anomalie corrigée

Le JSON CH3 précédemment importé possédait la bonne colonne de température, mais une colonne `ΔV0` erronée. Deux points de contrôle montrent l’écart :

| Température poudre | Ancien JSON | FT 81-AR-2 | Valeur retenue |
|---:|---:|---:|---:|
| −40 °F | −6,6 m/s | −10,0 m/s | −10,0 m/s |
| 75 °F | +0,3 m/s | +0,6 m/s | +0,6 m/s |
| 80 °F | +0,7 m/s | +1,2 m/s | +1,2 m/s |
| 130 °F | +4,1 m/s | +8,3 m/s | +8,3 m/s |

La source `M252_M821A1_TABLE_C_CH3.json`, les assets binaires et les assets chiffrés sont reconstruits à partir de la table officielle.

## Impact sur l’exercice MET ligne 05

À **25 °C**, soit **77 °F**, la Table C officielle donne une interpolation de **+0,84 m/s**. Pour l’exercice à 1811 m, le pipeline donne donc :

```text
ΔV0 = −7,681 m
```

L’ancienne valeur `−4,21 m` résultait de la colonne `ΔV0` erronée. Les corrections Wz, Wx, ΔT et ΔP ne sont pas modifiées par cette correction de Table C.
