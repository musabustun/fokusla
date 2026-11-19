#!/usr/bin/env python3
"""Palet renklerini Asset Catalog'a (Colors.xcassets/<Palet>/<Token>.colorset) üretir.

Kaynak: web/src/ui/tokens.ts (COLORS.light / COLORS.dark). Yeni palet eklerken aşağıdaki
PALETTES sözlüğüne web'deki hex değerlerini aynen kopyala ve scripti çalıştır:

    python3 ios/scripts/generate_palette_assets.py            # tüm paletleri yeniden üretir
    python3 ios/scripts/generate_palette_assets.py kahve      # yalnızca belirtilenleri

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

# web COLOR_TOKENS sırası; asset adı = PascalCase (swiftUIColorName).
TOKENS = [
    "background", "surface", "surface-elevated", "fill", "control-thumb", "switch-thumb-off",
    "label", "secondary-label", "tertiary-label", "separator", "separator-strong",
    "accent", "accent-contrast", "accent-ink", "accent-subtle",
    "success", "success-contrast", "warning", "danger", "danger-subtle", "scrim",
]  # fmt: skip

# Anahtar = FokusPalette.assetFolder. Değerler: web COLORS[light|dark] (#RRGGBB veya #RRGGBBAA).
PALETTES = {
    "Kahve": {
        "light": {
            "background": "#F5F2EA", "surface": "#FBF9F4", "surface-elevated": "#FFFDF8",
            "fill": "#E8E3D7", "control-thumb": "#1B1A16", "switch-thumb-off": "#77736A",
            "label": "#1B1A16", "secondary-label": "#5C5950", "tertiary-label": "#7A766C",
            "separator": "#DCD6C9", "separator-strong": "#8C877B",
            "accent": "#FFB547", "accent-contrast": "#1A1205", "accent-ink": "#955500",
            "accent-subtle": "#F8E5C0", "success": "#2D6A43", "success-contrast": "#FFFFFF",
            "warning": "#955500", "danger": "#B3261E", "danger-subtle": "#F7E1DC",
            "scrim": "#1B1A1666",
        },
        "dark": {
            "background": "#0E0F0C", "surface": "#141511", "surface-elevated": "#1A1B17",
            "fill": "#22231E", "control-thumb": "#EDEAE2", "switch-thumb-off": "#8A877F",
            "label": "#EDEAE2", "secondary-label": "#9A978E", "tertiary-label": "#6F6C64",
            "separator": "#2A2A25", "separator-strong": "#6A675F",
            "accent": "#FFB547", "accent-contrast": "#1A1205", "accent-ink": "#FFB547",
            "accent-subtle": "#2A2214", "success": "#8FD3A6", "success-contrast": "#0B1A10",
            "warning": "#FFB547", "danger": "#FF7A6B", "danger-subtle": "#2C1613",
            "scrim": "#000000B3",
        },
    },
}  # fmt: skip

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


def generate(folder: str, spec: dict) -> None:
    root = CATALOG / folder
    if root.exists():
        shutil.rmtree(root)
    write_json(root / "Contents.json", {"info": INFO, "properties": {"provides-namespace": True}})
    for token in TOKENS:
        colors = [
            color_entry(spec["light"][token], dark=False),
            color_entry(spec["dark"][token], dark=True),
        ]
        write_json(
            root / f"{asset_name(token)}.colorset" / "Contents.json",
            {"colors": colors, "info": INFO},
        )


def main(argv: list[str]) -> int:
    wanted = {a.lower() for a in argv}
    for folder, spec in PALETTES.items():
        if wanted and folder.lower() not in wanted:
            continue
        generate(folder, spec)
        print(f"{folder}: {len(TOKENS)} renk üretildi")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
