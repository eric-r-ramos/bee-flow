"""Paleta de blocos do Bee Flow.

Uma chave de um caractere por cor. O arquivo .txt do nivel usa essas chaves,
e o JSON gerado carrega o hex pra Godot nao precisar conhecer a paleta.
"""

PALETTE = {
    "b": {"name": "ceu", "color": "#5BAEE8"},
    "p": {"name": "petala", "color": "#E8698C"},
    "y": {"name": "polen", "color": "#F5C242"},
    "g": {"name": "caule", "color": "#6FBF54"},
    "d": {"name": "folha", "color": "#357F3C"},
    "o": {"name": "sol", "color": "#E9803C"},
    "r": {"name": "papoula", "color": "#DE4B3F"},
    "u": {"name": "lavanda", "color": "#9B6BC7"},
    "n": {"name": "terra", "color": "#8B5E3C"},
    "w": {"name": "nevoa", "color": "#F2EFE4"},
    "k": {"name": "carvao", "color": "#3A2E1F"},
}


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def nearest_key(rgb: tuple[int, int, int]) -> str:
    """Chave da paleta mais proxima de um pixel, pra importar PNG."""
    best, best_d = None, None
    for key, spec in PALETTE.items():
        pr, pg, pb = hex_to_rgb(spec["color"])
        d = (pr - rgb[0]) ** 2 + (pg - rgb[1]) ** 2 + (pb - rgb[2]) ** 2
        if best_d is None or d < best_d:
            best, best_d = key, d
    return best
