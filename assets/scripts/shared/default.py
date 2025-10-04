"""Utilitaires partagés pour les scripts Optima."""


def helper(ctx, message: str = "Bonjour"):
    """Exemple de fonction réutilisable dans d'autres scripts."""
    page = ctx.get("page", {})
    prefix = f"[{page.get('name')}] " if page else ""
    print(f"[OptimaScript] {prefix}{message}")
