"""Generate PWA icons matching the in-game minimalist art."""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "pwa"

CREAM = "#FBF4E6"
SAND = "#F3E6CE"
PAPER = "#FFFDF8"
INK = "#3F3A34"
CORAL = "#F26D5B"
SUN = "#F7C948"
MINT = "#7BAE6F"


def draw_icon(size: int) -> Image.Image:
    scale = 4
    s = size * scale
    img = Image.new("RGBA", (s, s), CREAM)
    d = ImageDraw.Draw(img)

    def xy(x: float) -> float:
        return x / 512.0 * s

    # plate shadow
    d.ellipse([xy(120), xy(170), xy(392), xy(430)], fill="#EADFC9")
    # plate
    d.ellipse([xy(112), xy(156), xy(400), xy(418)], fill=PAPER)
    d.ellipse([xy(148), xy(188), xy(364), xy(386)], fill=SAND)

    # food blobs
    d.ellipse([xy(174), xy(208), xy(266), xy(300)], fill=CORAL)
    d.ellipse([xy(252), xy(226), xy(342), xy(316)], fill=SUN)
    d.ellipse([xy(214), xy(270), xy(300), xy(356)], fill=MINT)
    d.ellipse([xy(178), xy(212), xy(200), xy(234)], fill="#FFB4A6")

    # hair swoosh + eye (the unemployed cook)
    d.arc([xy(78), xy(96), xy(300), xy(240)], start=200, end=330, fill=INK, width=max(3, int(xy(14))))
    d.ellipse([xy(142), xy(146), xy(170), xy(174)], fill=INK)

    # garnish dots
    d.ellipse([xy(344), xy(344), xy(360), xy(360)], fill=MINT)
    d.ellipse([xy(166), xy(342), xy(178), xy(354)], fill=SUN)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for size in (144, 180, 192, 512):
        icon = draw_icon(size)
        path = OUT / f"icon-{size}.png"
        icon.save(path, optimize=True)
        print(f"{path.name}: {path.stat().st_size / 1024:.1f} KB")
    # Maskable version: same art with extra safe-zone padding.
    base = draw_icon(512)
    canvas = Image.new("RGBA", (512, 512), CREAM)
    inner = base.resize((410, 410), Image.LANCZOS)
    canvas.alpha_composite(inner, (51, 51))
    canvas.save(OUT / "icon-maskable-512.png", optimize=True)
    print("icon-maskable-512.png")


if __name__ == "__main__":
    main()
