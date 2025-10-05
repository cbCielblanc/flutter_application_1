# Migration OptimaScript vers Dart

Les scripts embarqués ont été migrés depuis l'ancien format Python (`*.py`) vers
le nouveau format Dart (`*.dart`). Les administrateurs doivent :

1. Renommer les fichiers personnalisés placés dans `scripts/` avec l'extension
   `.dart`.
2. Adapter les fonctions au nouveau runtime en exposant des callbacks
   `onWorkbookOpen`, `onWorksheetActivate`, `onWorksheetBeforeDoubleClick`, etc. Chaque callback reçoit
   un `ScriptContext` et peut utiliser les APIs d'assistance (par exemple
   `ctx.logMessage`).
3. Vérifier que les assets publiés dans `assets/scripts/**` pointent maintenant
   vers les fichiers `.dart` et qu'aucun `.py` ne reste présent.
4. Re-déployer les scripts depuis l'espace administrateur pour régénérer les
   signatures et s'assurer que les nouveaux journaux s'affichent correctement.

> **Important** : les anciens scripts Python ne sont plus pris en charge. Un
> avertissement est affiché au démarrage si des fichiers `.py` sont encore
> présents afin de faciliter leur migration.

## Nouvelle API ScriptContext

Les scripts Dart disposent désormais d'un pont typé accessible via
`context.api`. Cette API évite toute mutation directe du classeur et s'appuie
sur le moteur de commandes existant.

### Endpoints principaux

| Endpoint | Description |
| --- | --- |
| `context.api.workbook.sheetNames` | Liste immuable des feuilles disponibles. |
| `context.api.workbook.activeSheet` | Retourne la feuille active (ou `null`). |
| `workbook.sheetByName(name)` / `sheetAt(index)` | Résolution explicite d'une feuille. |
| `workbook.activateSheetByName(name)` | Active une feuille et déclenche la navigation. |
| `sheet.cellAt(row, column)` / `cellByLabel('A1')` | Accès typé aux cellules. |
| `sheet.range('A1:C5')` | Retourne un `RangeApi` chaînable pour lire/écrire une plage rectangulaire. |
| `sheet.row(index)` / `sheet.column(index)` | Wrappers dédiés pour manipuler rapidement une ligne ou une colonne. |
| `cell.setValue(value)` / `cell.clear()` | Écritures atomiques sur les cellules. |
| `sheet.insertRow([index])` / `sheet.insertColumn([index])` | Insertion structurée dans la grille. |
| `sheet.clear()` | Réinitialise l'ensemble d'une feuille. |

### `RangeApi`, `RowApi`, `ColumnApi` et `ChartApi`

Les nouvelles primitives exposent une ergonomie proche de celle d'Excel/Google Sheets :

* `RangeApi` permet de récupérer les valeurs via `range.values`, d'appliquer des blocs avec
  `range.setValues([...])`, de réaliser un remplissage automatique (`fillDown`/`fillRight`),
  de trier (`sortByColumn`), de normaliser les nombres (`formatAsNumber`) ou encore de
  nettoyer les textes (`autoFit`). Chaque méthode retourne la même instance pour favoriser
  les chaînages (`range.setValues(...).formatAsNumber(2).autoFit()`).
* `RowApi` et `ColumnApi` simplifient les écritures unitaires (`setValues`), le
  formatage numérique et le remplissage horizontal/vertical.
* `ChartApi` encapsule la plage source d'un graphique fictif. Il est possible de consulter
  les métadonnées via `chart.describe()` ou de mettre à jour la plage avec `chart.updateRange(...)`.

Toutes ces opérations s'appuient sur le moteur de commandes existant, garantissant un
historique cohérent et la synchronisation avec l'interface utilisateur.

### Nouveaux événements VBA pris en charge

Les scripts peuvent désormais écouter les principaux événements du modèle objet
Excel. Chaque fonction est optionnelle, retourne `FutureOr<void>` et reçoit un
seul argument `ScriptContext`.

| Callback | Signature recommandée | Déclenchement |
| --- | --- | --- |
| `onWorkbookBeforeSave` | `Future<void> onWorkbookBeforeSave(ScriptContext context)` | Avant toute sauvegarde du classeur (export manuel ou auto). |
| `onWorksheetActivate` | `Future<void> onWorksheetActivate(ScriptContext context)` | Dès qu'une feuille devient active. |
| `onWorksheetDeactivate` | `Future<void> onWorksheetDeactivate(ScriptContext context)` | Juste avant de quitter la feuille active. |
| `onWorksheetBeforeSingleClick` | `Future<void> onWorksheetBeforeSingleClick(ScriptContext context)` | Au clic simple dans la grille (avant édition). |
| `onWorksheetBeforeDoubleClick` | `Future<void> onWorksheetBeforeDoubleClick(ScriptContext context)` | Lors d'un double clic sur une cellule. |

> Les callbacks historiques (`onWorkbookOpen`, `onPageEnter`, `onCellChanged`,
> etc.) restent disponibles et continuent d'être invoqués avec les mêmes
> structures de payload.

### Exemple rapide

```dart
Future<void> onWorkbookOpen(ScriptContext context) async {
  final workbook = context.api.workbook;
  final summary = workbook.sheetByName('Synthèse');
  final cell = summary?.cellByLabel('B2');
  if (cell != null && cell.isEmpty) {
    cell.setValue(DateTime.now().toIso8601String());
  }
}
```
