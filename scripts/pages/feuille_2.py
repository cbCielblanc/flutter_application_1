"""Script de page simplifié pour Optima."""


def on_page_enter(context):
    """Annonce la page courante dans les logs."""
    page = context.get("page", {})
    _log(f"Bienvenue sur {page.get('name')}")


def _log(message: str) -> None:
    print(f"[OptimaScript] {message}")
