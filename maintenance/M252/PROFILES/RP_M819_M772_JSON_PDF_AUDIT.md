# Audit des tables RP M819 / fusée M772

## Sources et méthode

L’audit compare les JSON fournis aux quatre PDF FT 81-AR-2 correspondants, charge par charge. Il couvre la cohérence structurelle (schéma, ordre, continuité des distances et valeurs manquantes), les bornes et des points de contrôle visuels sur les tables C, D, E et F.

Les tables A et B ne figurent pas dans le lot RP M819 : elles sont les **Supplementary Tables** communes du recueil. Leur version déjà qualifiée pour le M252 a été copiée, avec empreintes SHA-256, dans chacun des profils de maintenance `M819_M772_CH1` à `M819_M772_CH4`.

## Résultat

| Charge | C | D — données de base | D — facteurs de correction | E | F | Décision runtime |
|---|---|---|---|---|---|---|
| CH1 | Conforme | Conforme (300–1575 m) | Cellules publiées conservées | Conforme | Conforme, FS 18–23 | Nominal actif |
| CH2 | Conforme | Conforme (975–2850 m) | Cellules publiées conservées | Conforme | Conforme, FS 25–34 | Nominal actif |
| CH3 | Conforme | Version D complétée et scellée (1325–3975 m) | Conservés, non appliqués | Conforme | Conforme, FS 30–41 | Nominal actif |
| CH4 | Conforme | Version D complétée et scellée (1625–4950 m) | Conservés, non appliqués | Conforme | Conforme, FS 34–46 | Nominal actif |

## Rôle du réglage de fusée M772

Le réglage nominal M772 est la valeur de la colonne **Fuze Setting** de la Table D ; il est fourni avec la hausse pour produire l’éclatement de référence. Il ne doit pas être recalculé depuis la Table F.

La Table F contient seulement des **facteurs de correction du réglage de fusée** pour des conditions non standard (variation de vitesse initiale, vent de portée, température d’air et densité d’air). Ces facteurs sont appliqués uniquement lorsqu’un calcul demande explicitement ces corrections. Ils ne constituent donc pas un prérequis au calcul nominal de la Table D.

## Modèle d’affichage : parallèle avec le MO81 LLR éclairant

Le pipeline MO81 LLR éclairant possède déjà la bonne structure de résultat : une valeur nominale, une décomposition des corrections et une valeur finale de fusée. Pour le RP M819, cette structure sera réemployée avec une sémantique propre :

| Élément affiché | MO81 LLR éclairant | RP M819 / M772 |
|---|---|---|
| Valeur nominale | Tempage de l’ECL (s) | `Fuze Setting` de la Table D |
| Correction liée à la hauteur d’éclatement | Table ECL (s) | Table E, uniquement si l’option hauteur/range d’éclatement est demandée |
| Correction aux conditions non standard | Selon les tables OECL disponibles | Table F : Vo, vent de portée, température et densité |
| Valeur finale | Tempage final (s) | Réglage final M772 (**sans unité seconde**) |

Le résultat RP M819 devra donc afficher `M772 Fuze setting`, pas `Time of flight` ni `Tempage (s)`. Le champ Table D `Time of Flight` reste une information séparée, affichée en secondes, et ne sert pas de réglage de fusée.

## Historique des exports D corrigés

### CH3 — Table D

Le PDF contient des pages de facteurs de correction Table D après 2100 m. Dans le JSON, les huit champs de facteurs (`correctionV0Dec/Inc`, `correctionVentFace/Arriere`, `correctionTempAirDec/Inc`, `correctionDensiteAirDec/Inc`) sont tous nuls pour les 75 lignes de 2125 à 3975 m. Ces valeurs ne peuvent ni être supposées nulles ni interpolées depuis la partie basse de la charge.

### CH4 — Table D

Le PDF publie les pages Table D « Basic Data » et « Correction Factors » sur l’ensemble de la charge. Le JSON comporte bien les 134 distances et les hausses, mais :

- seuls 37 enregistrements ont le réglage de fusée, le temps de vol, le numéro de ligne météo, RB et Wz ;
- les huit colonnes de correction sont nulles sur **toutes** les lignes.

L’export CH4 initial était donc partiel. Il est conservé à titre de preuve sous
`raw/evidence/`; la Table D active est la version complétée, dont l’empreinte
est enregistrée dans `raw/SOURCES.sha256`.

## Traitement sûr retenu

Les six sources A–F ont été rangées sous :

```text
maintenance/M252/PROFILES/M819_M772_CH1/raw/
...
maintenance/M252/PROFILES/M819_M772_CH4/raw/
```

Chaque dossier contient `SOURCES.sha256`. Les assets A–F sont construits,
chiffrés AES-GCM et déclarés sous leur profil. Le pipeline runtime réalise le
**calcul nominal uniquement** : hausse, réglage M772, temps de vol, `LINE NO.`
et erreurs probables. Le chip RP M819 est donc sélectionnable.

Les corrections de conditions non standard de Table F restent volontairement
bloquées : elles devront être qualifiées avec un exercice documentaire avant
d’être appliquées. Le runtime refuse explicitement une demande météo plutôt
que d’afficher une correction incomplète ou inventée.

## Données attendues

Il faut fournir :

1. un JSON `OEM819_FuM772_CH3_Table_D.json` complété avec les facteurs de correction sur 2125–3975 m ;
2. un JSON `OEM819_FuM772_CH4_Table_D.json` complet avec tous les champs de données de base et les huit colonnes de correction publiées dans le PDF.

Les JSON C, E et F sont conservés tels quels. Les profils `M819_M772_CH1…CH4`
sont désormais construits, chiffrés, testés et raccordés. La prochaine étape
est un exercice nominal, suivi si conforme de la qualification explicite des
facteurs météo/Vo/densité de Table F.
