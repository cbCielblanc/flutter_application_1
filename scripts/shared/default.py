"""Utilitaires Python partagés pour Optima."""


def helper(ctx, message: str = "Bonjour"):
    """Exemple de fonction réutilisable dans d'autres modules."""
    page = ctx.get("page", {})
    prefix = f"[{page.get('name')}] " if page else ""
    print(f"[OptimaScript] {prefix}{message}")
