"""Gera os PNGs da marca Louve! a partir da mesma grade usada no Flutter.

Execute da raiz de app/:

    python tools/generate_brand_assets.py
    dart run flutter_launcher_icons

O segundo comando gera os recursos Android a partir das fontes em
assets/branding. Os arquivos web são escritos aqui porque o pacote usa a mesma
imagem para ícones normais e maskable, embora eles precisem de bordas distintas.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BLUE = "#1D4ED8"
WHITE = "#FFFFFF"
GRID = 108
SOURCE_SIZE = 1024
SUPERSAMPLE = 4


def _scaled(value: float, scale: float) -> int:
    return round(value * scale)


def draw_glyph(image: Image.Image, *, canvas_size: int, color: str = WHITE) -> None:
    """Desenha o ! com pingo de cabeça de nota na grade de 108 unidades."""

    scale = canvas_size / GRID
    draw = ImageDraw.Draw(image)

    cx = 54.0
    top = 22.0
    base = 58.0
    top_width = 16.0
    base_width = 9.5

    draw.polygon(
        [
            (_scaled(cx - top_width / 2, scale), _scaled(top, scale)),
            (_scaled(cx + top_width / 2, scale), _scaled(top, scale)),
            (_scaled(cx + base_width / 2, scale), _scaled(base, scale)),
            (_scaled(cx - base_width / 2, scale), _scaled(base, scale)),
        ],
        fill=color,
    )
    draw.ellipse(
        (
            _scaled(cx - top_width / 2, scale),
            _scaled(top - top_width / 2, scale),
            _scaled(cx + top_width / 2, scale),
            _scaled(top + top_width / 2, scale),
        ),
        fill=color,
    )
    draw.ellipse(
        (
            _scaled(cx - base_width / 2, scale),
            _scaled(base - base_width / 2, scale),
            _scaled(cx + base_width / 2, scale),
            _scaled(base + base_width / 2, scale),
        ),
        fill=color,
    )

    note_size = _scaled(40, scale)
    note = Image.new("RGBA", (note_size, note_size), (0, 0, 0, 0))
    note_draw = ImageDraw.Draw(note)
    note_draw.ellipse(
        (
            _scaled(4, scale),
            _scaled(9.5, scale),
            _scaled(36, scale),
            _scaled(30.5, scale),
        ),
        fill=color,
    )
    note = note.rotate(25, resample=Image.Resampling.BICUBIC, expand=False)
    image.alpha_composite(
        note,
        (
            _scaled(cx - 20, scale),
            _scaled(76 - 20, scale),
        ),
    )


def render_foreground(size: int) -> Image.Image:
    work_size = size * SUPERSAMPLE
    image = Image.new("RGBA", (work_size, work_size), (0, 0, 0, 0))
    draw_glyph(image, canvas_size=work_size)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def render_icon(size: int, *, maskable: bool) -> Image.Image:
    work_size = size * SUPERSAMPLE
    image = Image.new("RGBA", (work_size, work_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if maskable:
        draw.rectangle((0, 0, work_size, work_size), fill=BLUE)
    else:
        radius = round(work_size * 0.30)
        draw.rounded_rectangle(
            (0, 0, work_size - 1, work_size - 1),
            radius=radius,
            fill=BLUE,
        )
    draw_glyph(image, canvas_size=work_size)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(path.relative_to(ROOT))


def main() -> None:
    save(render_icon(SOURCE_SIZE, maskable=False), ROOT / "assets/branding/louve_icon.png")
    foreground = render_foreground(SOURCE_SIZE)
    save(foreground, ROOT / "assets/branding/louve_foreground.png")
    save(foreground, ROOT / "assets/branding/louve_monochrome.png")

    for size in (192, 512):
        save(render_icon(size, maskable=False), ROOT / f"web/icons/Icon-{size}.png")
        save(render_icon(size, maskable=True), ROOT / f"web/icons/Icon-maskable-{size}.png")
    save(render_icon(32, maskable=False), ROOT / "web/favicon.png")


if __name__ == "__main__":
    main()
