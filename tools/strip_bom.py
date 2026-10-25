"""Remove UTF-8 BOMs from project text files (Godot tolerates them; ConfigFile/font scan don't)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUFFIXES = {".gd", ".tscn", ".cfg", ".md", ".sql", ".js", ".json", ".toml"}

for path in ROOT.rglob("*"):
    if path.is_file() and path.suffix.lower() in SUFFIXES:
        data = path.read_bytes()
        if data.startswith(b"\xef\xbb\xbf"):
            path.write_bytes(data[3:])
            print("stripped", path.relative_to(ROOT))
