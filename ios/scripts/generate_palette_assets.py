#!/usr/bin/env python3
"""Palet renklerini Asset Catalog'a (Colors.xcassets/<Palet>/<Token>.colorset) üretir.

Kaynak: web/src/ui/tokens.ts → `cd web && npm run export:ios-palettes` →
FokusKit/Tests/FokusDesignTests/Fixtures/palettes.web.json. Palet eklemek/değiştirmek için web'i
güncelle, dışa aktar, sonra:

    python3 ios/scripts/generate_palette_assets.py            # tüm paletleri yeniden üretir
    python3 ios/scripts/generate_palette_assets.py coffee     # yalnızca belirtilenleri

Çıktı deterministiktir; üretilen Contents.json dosyaları git'e girer. Yalnızca standart kütüphane.
"""

import json
import shutil
import sys
from pathlib import Path

CATALOG = (
    Path(__file__).resolve().parent.parent
    / "FokusKit/Sources/FokusDesign/Resources/Colors.xcassets"
)

# Tek kaynak: web `tokens.ts` → `npm run export:ios-palettes` ile üretilen JSON.
SOURCE = (
    Path(__file__).resolve().parent.parent
    / "FokusKit/Tests/FokusDesignTests/Fixtures/palettes.web.json"
)


def load_source() -> dict:
    return json.loads(SOURCE.read_text(encoding="utf-8"))


INFO = {"author": "xcode", "version": 1}


def asset_name(token: str) -> str:
    return "".join(part[:1].upper() + part[1:] for part in token.split("-"))


def color_entry(hex_value: str, dark: bool) -> dict:
    h = hex_value.lstrip("#")
    if len(h) not in (6, 8):
        raise ValueError(f"Geçersiz hex: {hex_value}")
    r, g, b = (f"0x{h[i:i + 2].upper()}" for i in (0, 2, 4))
    alpha = int(h[6:8], 16) / 255 if len(h) == 8 else 1.0
    entry = {
        "idiom": "universal",
        "color": {
            "color-space": "srgb",
            "components": {"red": r, "green": g, "blue": b, "alpha": f"{alpha:.3f}"},
        },
    }
    if dark:
        entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
    return entry


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def folder_name(palette: str) -> str:
    """Web `swiftUIPaletteColorName` öneki: `coffee` → `Coffee` (= FokusPalette.assetFolder)."""
    return asset_name(palette)


def generate(folder: str, spec: dict, tokens: list[str]) -> None:
    root = CATALOG / folder
    if root.exists():
        shutil.rmtree(root)
    write_json(root / "Contents.json", {"info": INFO, "properties": {"provides-namespace": True}})
    for token in tokens:
        colors = [
            color_entry(spec["light"][token], dark=False),
            color_entry(spec["dark"][token], dark=True),
        ]
        write_json(
            root / f"{asset_name(token)}.colorset" / "Contents.json",
            {"colors": colors, "info": INFO},
        )


def main(argv: list[str]) -> int:
    source = load_source()
    wanted = {a.lower() for a in argv}
    if not wanted:
        # Kaynakta olmayan eski klasörleri temizle (yalnızca namespace klasörleri).
        known = {folder_name(name) for name in source["order"]}
        for child in CATALOG.iterdir():
            if child.is_dir() and child.suffix == "" and child.name not in known:
                shutil.rmtree(child)
    for name in source["order"]:
        if wanted and name.lower() not in wanted:
            continue
        generate(folder_name(name), source["palettes"][name], source["tokens"])
        print(f"{folder_name(name)}: {len(source['tokens'])} renk üretildi")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
