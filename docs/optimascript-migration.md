# Migration OptimaScript vers Dart

Les scripts embarqués ont été migrés depuis l'ancien format Python (`*.py`) vers
le nouveau format Dart (`*.dart`). Les administrateurs doivent :

1. Renommer les fichiers personnalisés placés dans `scripts/` avec l'extension
   `.dart`.
2. Adapter les fonctions au nouveau runtime en exposant des callbacks
   `onWorkbookOpen`, `onPageEnter`, `onNotesChanged`, etc. Chaque callback reçoit
   un `ScriptContext` et peut utiliser les APIs d'assistance (par exemple
   `ctx.logMessage`).
3. Vérifier que les assets publiés dans `assets/scripts/**` pointent maintenant
   vers les fichiers `.dart` et qu'aucun `.py` ne reste présent.
4. Re-déployer les scripts depuis l'espace administrateur pour régénérer les
   signatures et s'assurer que les nouveaux journaux s'affichent correctement.

> **Important** : les anciens scripts Python ne sont plus pris en charge. Un
> avertissement est affiché au démarrage si des fichiers `.py` sont encore
> présents afin de faciliter leur migration.
