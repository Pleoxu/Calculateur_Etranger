# M252 — extension contrôlée des profils Part 6

## Référence doctrinale

Le **FT 81-AR-2**, page imprimée **367** (page PDF **419**) définit une seule Part 6 pour les deux couples suivants :

- **Cartridge, HE, M821A1 — Fuze, MO, M734** ;
- **Cartridge, HE, M821A2 — Fuze, MO, M734A1**.

> Les tables de la Part 6 doivent donc être chargées **par charge M220**, puis associées aux deux couples. Il ne faut ni créer deux jeux de données prétendument distincts, ni utiliser les tables d’un couple différent.

## Organisation des profils

| Profil | Page PDF d’ouverture | Page imprimée | Vitesse initiale | Couples autorisés | État |
|---|---:|---:|---:|---|---|
| CH0 | 421 | 369 | 66 m/s | M821A1/M734, M821A2/M734A1 | À extraire |
| CH1 | 429 | 377 | 149 m/s | M821A1/M734, M821A2/M734A1 | À extraire |
| CH2 | 441 | 389 | 208 m/s | M821A1/M734, M821A2/M734A1 | À extraire |
| CH3 | 455 | 403 | 259 m/s | M821A1/M734, M821A2/M734A1 | **Raccordé** |
| CH4 | 473 | 421 | 305 m/s | M821A1/M734, M821A2/M734A1 | À extraire |

## Règle d’import

Chaque profil de charge comprend ses propres Tables **A, B, C, D et E**. Même si une valeur paraît identique entre deux charges, elle reste attachée au profil source tant qu’une vérification documentaire n’a pas démontré une table commune.

Pour chaque charge à importer :

1. transcrire les Tables A à E du PDF dans `maintenance/M252/` ;
2. faire contrôler les en-têtes, les unités, les bornes et les lignes de référence ;
3. générer les formats AEBTL, BEBTL, CEBTL, DEBTL et EEBTL ;
4. exécuter les tests de valeurs de référence et de domaine ;
5. chiffrer les assets dans `assets/secure_enc/` et fusionner le manifest ;
6. ouvrir la charge uniquement après validation du profil complet.

## État de CH3

CH3 conserve son domaine actuellement vérifié de **1525 m à 2300 m**, intersection des données D et E importées. Le pipeline journalise désormais la cartouche et la fusée sélectionnées :

```text
part6Cartridge = M821A1 ou M821A2
part6Fuze      = M734 ou M734A1
```

Les deux couples utilisent les mêmes assets CH3 de Part 6, conformément à la page d’ouverture. La disponibilité de CH0, CH1, CH2 et CH4 reste explicitement bloquée tant que les tables correspondantes n’ont pas été transcrites, chiffrées et testées.
