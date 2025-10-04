"""Script de démonstration pour la feuille 1."""


def on_page_enter(context):
    """Souhaite la bienvenue lorsque la page devient active."""
    page = context.get("page", {})
    print(f"[OptimaScript] Bienvenue sur {page.get('name')}")


def on_cell_changed(context):
    """Illustre la réception d'un événement de cellule."""
    change = context.get("change", {})
    label = context.get("cell", {}).get("label")
    new_value = change.get("newRaw")
    print(f"[OptimaScript] La cellule {label} vaut désormais {new_value!r}")
