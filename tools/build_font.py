"""Build small Traditional Chinese font subsets for the game.

Scans all text-bearing project files, then instances + subsets Noto Sans TC
at two weights so the web build stays light and never shows tofu boxes.
"""

from pathlib import Path
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = Path(r"C:\Windows\Fonts\NotoSansTC-VF.ttf")
OUT_DIR = ROOT / "assets" / "fonts"

EXTRA = (
    "0123456789"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    " !\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
    "，。、；：？！「」『』（）【】《》〈〉…—～·×÷＋－＝／＄％"
    "←→↑↓★☆♥♡☀☁☂✓"
    "０１２３４５６７８９"
)


def collect_text() -> str:
    chars = set(EXTRA)
    for pattern in ("**/*.gd", "**/*.tscn", "**/*.md", "**/*.cfg", "**/*.svg"):
        for path in ROOT.glob(pattern):
            if ".godot" in path.parts or "build" in path.parts:
                continue
            try:
                chars.update(path.read_text(encoding="utf-8"))
            except UnicodeDecodeError:
                continue
    chars.update("　")
    chars.discard("\ufeff")
    return "".join(sorted(chars))


def build(weight: int, name: str, text: str) -> None:
    font = TTFont(SOURCE)
    instantiateVariableFont(font, {"wght": weight}, inplace=True, updateFontNames=True)
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.name_languages = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    sub = subset.Subsetter(options=options)
    sub.populate(text=text)
    sub.subset(font)
    out = OUT_DIR / f"NotoSansTC-{name}.ttf"
    font.save(out)
    print(f"{out.name}: {out.stat().st_size / 1024:.1f} KB, {len(font.getBestCmap())} glyphs")


def main() -> int:
    if not SOURCE.exists():
        print(f"Missing source font: {SOURCE}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    text = collect_text()
    print(f"Unique characters: {len(text)}")
    build(400, "Regular", text)
    build(700, "Bold", text)

    cmap = TTFont(OUT_DIR / "NotoSansTC-Regular.ttf").getBestCmap()
    missing = [ch for ch in text if ord(ch) not in cmap and not ch.isspace()]
    if missing:
        print("WARNING missing glyphs: " + "".join(missing), file=sys.stderr)
        return 2
    print("All characters covered.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
