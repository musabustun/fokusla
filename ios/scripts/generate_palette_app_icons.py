#!/usr/bin/env python3
"""Her renk paleti için alternatif uygulama ikonu üretir.

Kaynak: `Fokus/Resources/Assets.xcassets/AppIcon.appiconset` (varsayılan Kahve paleti; kehribar
halka + açık nokta, gece zemini). Tasarım aynen korunur; yalnızca halkanın rengi paletin KOYU
görünümdeki `Accent` rengiyle değişir (ikon zemini koyu olduğundan). Renk, FokusDesign
`Colors.xcassets/<Palet>/Accent.colorset` içinden okunur; böylece palet değişirse ikon da betik
yeniden çalıştırılarak güncellenir.

Yöntem: kaynak PNG'ler yeniden çizilmez, piksel piksel yeniden boyanır. Halka pikselleri zemin ile
kehribar arasındaki karışım oranı (kenar yumuşatma dahil) korunarak yeni renge taşınır; merkez nokta
ve zemin olduğu gibi kalır. Tinted varyant renksizdir (sistem boyar), kaynaktan kopyalanır.

Kullanım (ios/ içinde):  python3 scripts/generate_palette_app_icons.py
Gereksinim: Pillow.
"""

from __future__ import annotations

import json
import math
import shutil
from pathlib import Path

from PIL import Image

IOS_DIR = Path(__file__).resolve().parent.parent
ASSETS = IOS_DIR / "Fokus/Resources/Assets.xcassets"
SOURCE_SET = ASSETS / "AppIcon.appiconset"
COLORS = IOS_DIR / "FokusKit/Sources/FokusDesign/Resources/Colors.xcassets"

# `FokusPalette` raw value'ları; varsayılan (`coffee`) mevcut `AppIcon` olarak kalır.
# İkon adı `AppIconName.name(for:)` (FokusDesign) ile birebir aynı olmalı.
ALTERNATE_PALETTES = ["mono", "strawberry", "matcha", "blueberry", "lemonade"]

SOURCE_ACCENT = (255, 181, 71)  # #FFB547 (Kahve, koyu)
GROUND = (14, 15, 12)  # #0E0F0C

# Merkez nokta (icon-any.svg: translate(512 504) scale(2.85), r=25) — yeniden boyanmaz.
DOT_CENTER = (512, 504)
DOT_RADIUS = 25 * 2.85 + 4  # kenar yumuşatma payı; halka iç kenarı ~ (84-15)*2.85 = 197 px


def icon_name(palette: str) -> str:
    return "AppIcon-" + palette[:1].upper() + palette[1:]


def dark_accent(palette: str) -> tuple[int, int, int]:
    folder = palette[:1].upper() + palette[1:]
    data = json.loads((COLORS / folder / "Accent.colorset/Contents.json").read_text())
    for entry in data["colors"]:
        appearances = entry.get("appearances", [])
        if any(a.get("value") == "dark" for a in appearances):
            comps = entry["color"]["components"]
            return tuple(int(comps[c], 16) for c in ("red", "green", "blue"))  # type: ignore[return-value]
    raise ValueError(f"{palette}: koyu Accent rengi yok")


def in_dot(x: int, y: int) -> bool:
    return math.hypot(x - DOT_CENTER[0], y - DOT_CENTER[1]) <= DOT_RADIUS


def mix(a: tuple[int, ...], b: tuple[int, ...], t: float) -> tuple[int, ...]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def arc_amount(pixel: tuple[int, ...]) -> float:
    """Pikselin zemin→kehribar karışım oranı (0…1), kehribar ekseni üzerine izdüşüm."""
    axis = [SOURCE_ACCENT[i] - GROUND[i] for i in range(3)]
    delta = [pixel[i] - GROUND[i] for i in range(3)]
    t = sum(a * d for a, d in zip(axis, delta)) / sum(a * a for a in axis)
    return min(max(t, 0.0), 1.0)


def recolor_opaque(src: Image.Image, accent: tuple[int, int, int]) -> Image.Image:
    out = src.convert("RGB").copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if in_dot(x, y):
                continue
            t = arc_amount(px[x, y])
            if t > 0:
                px[x, y] = mix(GROUND, accent, t)
    return out


def recolor_transparent(src: Image.Image, accent: tuple[int, int, int]) -> Image.Image:
    out = src.convert("RGBA").copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a == 0 or in_dot(x, y):
                continue
            px[x, y] = (*accent, a)
    return out


def main() -> None:
    contents = json.loads((SOURCE_SET / "Contents.json").read_text())
    any_src = Image.open(SOURCE_SET / "AppIcon.png")
    dark_src = Image.open(SOURCE_SET / "AppIcon-Dark.png")

    for palette in ALTERNATE_PALETTES:
        name = icon_name(palette)
        accent = dark_accent(palette)
        target = ASSETS / f"{name}.appiconset"
        if target.exists():
            shutil.rmtree(target)
        target.mkdir()

        renames = {
            "AppIcon.png": f"{name}.png",
            "AppIcon-Dark.png": f"{name}-Dark.png",
            "AppIcon-Tinted.png": f"{name}-Tinted.png",
        }
        recolor_opaque(any_src, accent).save(target / renames["AppIcon.png"], optimize=True)
        recolor_transparent(dark_src, accent).save(target / renames["AppIcon-Dark.png"], optimize=True)
        shutil.copyfile(SOURCE_SET / "AppIcon-Tinted.png", target / renames["AppIcon-Tinted.png"])

        images = [{**img, "filename": renames[img["filename"]]} for img in contents["images"]]
        (target / "Contents.json").write_text(
            json.dumps({**contents, "images": images}, indent=2) + "\n"
        )
        print(f"{name}: #{accent[0]:02X}{accent[1]:02X}{accent[2]:02X}")


if __name__ == "__main__":
    main()
