"""Copy build/web into workers/game/public and gzip index.wasm.

Cloudflare static assets limit each file to 25 MiB, and Godot's index.wasm is
about 39.5 MB. We store a gzipped copy and let the game Worker decompress it
on the fly for /index.wasm.
"""

from __future__ import annotations

import gzip
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "build" / "web"
DEST = ROOT / "workers" / "game" / "public"
WASM = SOURCE / "index.wasm"

if not SOURCE.is_dir():
    raise SystemExit(f"missing web build: {SOURCE}")
if not WASM.is_file():
    raise SystemExit(f"missing wasm: {WASM}")

if DEST.exists():
    shutil.rmtree(DEST)
DEST.mkdir(parents=True)

for item in SOURCE.iterdir():
    if item.name == "index.wasm":
        continue
    target = DEST / item.name
    if item.is_dir():
        shutil.copytree(item, target)
    else:
        shutil.copy2(item, target)

wasm_dir = DEST / "_wasm"
wasm_dir.mkdir()
raw = WASM.read_bytes()
gz_path = wasm_dir / "index.wasm.gz"
with gzip.open(gz_path, "wb", compresslevel=9) as handle:
    handle.write(raw)

# Keep Godot from importing/exporting the generated static site.
(DEST / ".gdignore").write_text("", encoding="utf-8")
(ROOT / "workers" / "game" / ".gdignore").write_text("", encoding="utf-8")

print(f"wasm raw={len(raw)} bytes, gzip={gz_path.stat().st_size} bytes")
print(f"prepared {sum(1 for p in DEST.rglob('*') if p.is_file())} files in {DEST}")
