# Domaine tableur

Ce module expose trois entités immuables :

- **Workbook** : regroupe plusieurs feuilles. Les noms de feuille doivent être
  uniques (`Sheet.name`) et au moins une feuille doit être présente.
- **Sheet** : représente une grille rectangulaire. Chaque feuille doit avoir au
  moins une ligne et une colonne. Toutes les lignes partagent la même largeur et
  les cellules absentes sont modélisées via des `Cell` de type `empty`.
- **Cell** : décrit la valeur d'une case avec son type (`empty`, `text`,
  `number`, `boolean`). Le type est toujours cohérent avec la valeur runtime.

La sérialisation CSV expose deux stratégies :

- `Sheet.toCsv` / `Sheet.fromCsv` pour manipuler une feuille à la fois.
- `Workbook.toCsvMap` / `Workbook.fromCsvMap` pour gérer un ensemble de feuilles
  (le format map facilite l'export multi-fichiers).

Les conversions depuis le CSV respectent les règles suivantes :

- Les champs vides deviennent des cellules `empty`.
- `TRUE` / `FALSE` sont convertis en booléens (insensibles à la casse).
- Les nombres sont déduits via `num.tryParse`.
- Tout autre contenu reste textuel.
