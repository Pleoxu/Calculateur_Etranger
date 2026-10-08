# M252 — profil `M821_M734_CH4`

## Identité

| Champ | Valeur |
|---|---|
| Profil runtime | `M821_M734_CH4` |
| Munition | HE M821A1 / fusée M734 ; HE M821A2 / fusée M734A1 |
| Charge | CH4 — vitesse initiale documentée : 297 m/s |
| Tables | A, B, C, D et E, indissociables |
| Domaine runtime qualifié | **1825 à 5125 m**, inclus |

## Qualification du domaine

Les tables D et E publiées s’étendent de **1825 à 5608 m**. Le runtime est volontairement borné à **5125 m**, dernière ligne où toutes les données requises par le pipeline sont publiées simultanément : trajectoire, météo, ΔV0, vent longitudinal, température/densité de l’air et EPP Table E.

À partir de **5150 m**, la correction vent longitudinal « HEAD » est absente dans la Table D. D’autres colonnes indispensables deviennent ensuite vides et l’EPP n’est plus publiée à partir de 5525 m. Aucune valeur n’est interpolée ou inventée au-delà de 5125 m.

## Règle de sélection en recouvrement

Le registre expose CH4 avec les autres charges compatibles. Lorsque plusieurs profils couvrent une distance, le service compare l’**EPP** publiée dans chaque Table E et retient la plus faible ; une égalité exacte est rejetée sans priorité artificielle.

Exemple : dans le recouvrement CH3/CH4, CH3 a une EPP de 9 à 11 m contre 22 m pour CH4 ; CH3 reste donc sélectionnée. CH4 devient le seul profil qualifié après 3125 m, lorsque CH2 s’arrête.

## Sources

- Tables C, D et E : JSON fournis et contrôlés visuellement contre `Tables_CH4_HEM821_FuM734.pdf` ;
- Tables A et B : copies propres au profil des tables M252 communes déjà auditées, afin que le profil possède ses cinq assets sans mélange inter-profils ;
- intégrité : `raw/SOURCES.sha256`.
