# M853A1_M772_CH4

| Champ | Valeur |
|---|---|
| Cartouche | ILL M853A1 |
| Fusée | M772 |
| Charge | CH4 |
| Domaine publié D/E | 1675–5050 m |
| Lignes Table D | 136 |
| Lignes Table E | 136 |
| Réglages Table F | 12 |
| Tables indissociables | A–F |
| Statut runtime | Nominal qualifié ; corrections non standard en attente d’exercice |

## Règle de sélection

Lorsque plusieurs charges couvrent la portée, le runtime lit l’**écart probable de portée d’éclatement (RB)** de la Table D de chaque candidate et sélectionne la valeur publiée la plus faible. Aucun fallback vers une autre munition n’est permis.

## Résultat nominal

La Table D fournit l’AE, le réglage M772, le temps de vol jusqu’à l’événement d’éclatement/dépotage, la ligne météo et les écarts probables. Le réglage M772 est conservé séparément du temps de vol. La Table E est conservée sans transformation doctrinale ; la Table F est chiffrée avec ses cellules non publiées maintenues à `null`.
