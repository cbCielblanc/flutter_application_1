"""Script global d'exemple pour Optima."""


def on_workbook_open(context):
    """Log l'ouverture du classeur."""
    workbook = context.get("workbook", {})
    page_count = workbook.get("pageCount", 0)
    _log(f"Classeur chargé ({page_count} page(s)).")


def on_page_enter(context):
    """Annoncer la page active."""
    page = context.get("page", {})
    _log(f"Ouverture de {page.get('name')}")


def _log(message: str) -> None:
    """Petite fonction utilitaire pour le logging."""
    print(f"[OptimaScript] {message}")
