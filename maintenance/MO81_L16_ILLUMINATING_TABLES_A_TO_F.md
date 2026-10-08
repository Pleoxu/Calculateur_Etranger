# MO81 L16 — tables éclairantes A à F en maintenance

## Périmètre

Cette maintenance s'applique **uniquement** lorsque les deux conditions sont réunies :

| Système | Type de tir | Tables isolées |
|---|---|---|
| MO81 L16 (`Systeme.mo81M252`) | Éclairant (`TypeTir.eclairant`) | A, B, C, D, E, F |

Les autres systèmes, ainsi que le tir d'appui MO81 L16, ne sont pas concernés par cette règle.

## Comportement de l'application

- Le système **MO81 L16** reste sélectionnable dans l'interface.
- Les familles et les cartouches éclairantes restent consultables et modifiables.
- Un bandeau indique que les tables sont en maintenance.
- Toute demande de calcul éclairant MO81 L16 s'arrête avant le chargement d'un asset et affiche un message explicite.
- Aucun repli vers les tables génériques CAESAR ou MO-120 n'est autorisé.

## Point de contrôle technique

La règle est centralisée dans :

```text
lib/services/ballistic_table_maintenance.dart
```

Elle est appliquée par `BalistiqueService` avant le routage vers un calculateur balistique.

## Réactivation

La réactivation ne doit être faite qu'après la validation des six référentiels A à F et l'ajout de tests de calcul MO81 L16 éclairant. À ce moment-là, retirer la règle correspondante dans `BallisticTableMaintenance`, raccorder le pipeline MO81 L16 dédié, puis ajouter des tests de non-régression.
