"""Script de démonstration pour la feuille 1."""


def on_page_enter(ctx):
    """Souhaite la bienvenue lorsque la page devient active."""
    page = ctx.get("page", {})
    print(f"[OptimaScript] Bienvenue sur {page.get('name')}")


def on_cell_changed(ctx):
    """Illustre la réception d'un événement de cellule."""
    change = ctx.get("change", {})
    label = ctx.get("cell", {}).get("label")
    new_value = change.get("newRaw")
    print(f"[OptimaScript] La cellule {label} vaut désormais {new_value!r}")
