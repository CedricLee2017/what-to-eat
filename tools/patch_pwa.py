"""Post-process Godot's PWA output: fix UTF-8 name, portrait, 192/maskable icons."""

from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"
ICONS = ROOT / "assets" / "pwa"


def main() -> None:
    manifest_path = WEB / "index.manifest.json"
    if not manifest_path.exists():
        raise SystemExit("Missing PWA manifest; enable PWA in the Web preset first.")

    shutil.copyfile(ICONS / "icon-192.png", WEB / "pwa-192.png")
    shutil.copyfile(ICONS / "icon-maskable-512.png", WEB / "pwa-maskable-512.png")

    manifest = {
        "id": "./",
        "name": "今日食咩好？",
        "short_name": "食咩好？",
        "description": "無職，但食得好。七日三餐預算與健康人生。",
        "lang": "zh-Hant",
        "dir": "ltr",
        "start_url": "./index.html",
        "scope": "./",
        "display": "standalone",
        "orientation": "portrait",
        "background_color": "#fbf4e6",
        "theme_color": "#fbf4e6",
        "categories": ["games", "food"],
        "icons": [
            {"src": "index.144x144.png", "sizes": "144x144", "type": "image/png", "purpose": "any"},
            {"src": "index.180x180.png", "sizes": "180x180", "type": "image/png", "purpose": "any"},
            {"src": "pwa-192.png", "sizes": "192x192", "type": "image/png", "purpose": "any"},
            {"src": "index.512x512.png", "sizes": "512x512", "type": "image/png", "purpose": "any"},
            {"src": "pwa-maskable-512.png", "sizes": "512x512", "type": "image/png", "purpose": "maskable"},
        ],
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"Patched {manifest_path.name}: {manifest['name']} / portrait / 5 icons")

    # Godot's generated cache prefix can contain mojibake for non-ASCII project names.
    sw_path = WEB / "index.service.worker.js"
    if sw_path.exists():
        text = sw_path.read_text(encoding="utf-8", errors="replace")
        lines = text.splitlines()
        for i, line in enumerate(lines):
            if line.startswith("const CACHE_PREFIX ="):
                lines[i] = "const CACHE_PREFIX = 'what-to-eat-sw-cache-';"
            elif line.startswith("const CACHED_FILES =") and "index.wasm" not in line:
                extra = (
                    ',"index.wasm","index.pck","index.png","index.manifest.json",'
                    '"index.144x144.png","index.180x180.png","index.512x512.png",'
                    '"pwa-192.png","pwa-maskable-512.png"];'
                )
                lines[i] = line.replace("];", extra)
        sw_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print("Patched service worker cache prefix + offline game files")


if __name__ == "__main__":
    main()
