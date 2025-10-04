"""Script global d'exemple pour Optima."""


def on_workbook_open(ctx):
    """Log l'ouverture du classeur."""
    workbook = ctx.get("workbook", {})
    page_count = workbook.get("pageCount", 0)
    _log(f"Classeur chargé ({page_count} page(s)).")


def on_page_enter(ctx):
    """Annoncer la page active."""
    page = ctx.get("page", {})
    _log(f"Ouverture de {page.get('name')}")


def _log(message: str) -> None:
    """Petite fonction utilitaire pour le logging."""
    print(f"[OptimaScript] {message}")
