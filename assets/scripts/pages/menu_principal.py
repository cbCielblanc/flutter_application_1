"""Script de la page de menu principal."""


def on_page_enter(context):
    page = context.get("page", {})
    _log(f"Bienvenue sur {page.get('name')}")


def _log(message: str) -> None:
    print(f"[OptimaScript] {message}")
