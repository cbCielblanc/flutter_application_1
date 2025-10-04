"""Script associé à une page de notes."""


def on_page_enter(ctx):
    page = ctx.get("page", {})
    _log(f"Bienvenue sur {page.get('name')}")


def _log(message: str) -> None:
    print(f"[OptimaScript] {message}")
