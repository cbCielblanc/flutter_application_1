"""Deuxième script de notes pour Optima."""


def on_page_enter(ctx):
    page = ctx.get("page", {})
    _log(f"Bienvenue sur {page.get('name')}")


def _log(message: str) -> None:
    print(f"[OptimaScript] {message}")
