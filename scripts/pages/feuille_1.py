"""Exemple de script de page pour Optima."""


def on_page_enter(ctx):
    """Souhaite la bienvenue lorsque la page devient active."""
    page = ctx.get("page", {})
    _log(f"Bienvenue sur {page.get('name')}, test")


def on_cell_changed(ctx):
    """Illustration d'un traitement de modification de cellule."""
    change = ctx.get("change", {})
    cell = ctx.get("cell", {})
    label = cell.get("label")
    new_value = change.get("newRaw")
    _log(f"La cellule {label} vaut désormais {new_value!r}")


def _log(message: str) -> None:
    print(f"[OptimaScript] {message}")
