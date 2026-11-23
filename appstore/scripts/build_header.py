#!/usr/bin/env python3
"""App Store Connect "Header" ve "Arama sonuçları" görsellerini üretir (HTML/CSS + headless Chrome).

Kullanım: python3 appstore/scripts/build_header.py
Çıktı (alfa YOK, RGB PNG):
  appstore/header/header-5244x2950.png, header-3840x1646.png
  appstore/search-results/search-5244x2950.png, search-3840x2560.png
Düzen: simge + ad + tek kısa satır TAM ORTADA, yükseklikle ölçeklenen güvenli alanda (ASC önizlemesi farklı
yönlerde kırpar); arka plan kenarlara kadar uzanır. Fontlar repo içinden, dış kaynak yok.
"""
import html
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT.parent / "ios/FokusKit/Sources/FokusDesign/Resources/Fonts"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# (çıktı yolu, genişlik, yükseklik, ad, satır)
TARGETS = [
    ("header/header-5244x2950.png", 5244, 2950, "Fokus", "YKS çalışma ve odak takibi"),
    ("header/header-3840x1646.png", 3840, 1646, "Fokus", "YKS çalışma ve odak takibi"),
    ("search-results/search-5244x2950.png", 5244, 2950, "Fokus", "Ücretsiz. Reklamsız. Odak."),
    ("search-results/search-3840x2560.png", 3840, 2560, "Fokus", "Ücretsiz. Reklamsız. Odak."),
]

SYMBOL = '<path d="M128 44 A84 84 0 1 1 44 128" fill="none" stroke="#FFB547" stroke-width="30" stroke-linecap="round"/><circle cx="128" cy="128" r="25" fill="#EDEAE2"/>'


def background(w: int, h: int) -> str:
    """Kenarlara uzanan sıcak koyu zemin: kehribar ışık, alt kenarda akan dalga ve zaman çizelgesi."""
    pts = []
    for k in range(0, 81):
        x = w * k / 80
        y = h * 0.895 + math.sin(k / 80 * math.pi * 3.0) * h * 0.03 + math.sin(k / 80 * math.pi * 7.0) * h * 0.008
        pts.append(f"{x:.0f},{y:.0f}")
    ticks = []
    gap = w / 60
    for k in range(61):
        x = k * gap
        major = k % 6 == 0
        ticks.append(f'<line x1="{x:.0f}" y1="{h * 0.955:.0f}" x2="{x:.0f}" y2="{h * (0.975 if major else 0.968):.0f}" stroke="rgba(237,234,226,{0.30 if major else 0.12})" stroke-width="{max(2, h // 700)}"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}">
<defs><radialGradient id="g"><stop offset="0" stop-color="#FFB547" stop-opacity="0.22"/><stop offset="1" stop-color="#FFB547" stop-opacity="0"/></radialGradient>
<linearGradient id="s" x1="0" x2="1"><stop offset="0" stop-color="#FFB547" stop-opacity="0.04"/><stop offset="0.5" stop-color="#FFB547" stop-opacity="0.5"/><stop offset="1" stop-color="#FFB547" stop-opacity="0.04"/></linearGradient></defs>
<circle cx="{w * 0.5:.0f}" cy="{h * 0.42:.0f}" r="{h * 0.85:.0f}" fill="url(#g)"/>
<circle cx="{w * 0.04:.0f}" cy="{h * 0.1:.0f}" r="{h * 0.7:.0f}" fill="url(#g)" opacity="0.45"/>
<circle cx="{w * 0.97:.0f}" cy="{h * 0.95:.0f}" r="{h * 0.7:.0f}" fill="url(#g)" opacity="0.45"/>
<polyline points="{' '.join(pts)}" fill="none" stroke="url(#s)" stroke-width="{max(4, h // 450)}" stroke-linecap="round"/>
<line x1="0" y1="{h * 0.955:.0f}" x2="{w}" y2="{h * 0.955:.0f}" stroke="rgba(237,234,226,0.10)" stroke-width="{max(2, h // 700)}"/>
{''.join(ticks)}</svg>'''


def page(w: int, h: int, name: str, line: str) -> str:
    icon = h * 0.27  # güvenli alan: içerik yüksekliğin ~%62'si, ortada
    return f'''<!doctype html><html lang="tr"><head><meta charset="utf-8"><style>
@font-face {{ font-family: "Bricolage"; font-weight: 800; src: url("{(FONTS / 'BricolageGrotesque-ExtraBold.ttf').as_uri()}"); }}
@font-face {{ font-family: "JBMono"; font-weight: 500; src: url("{(FONTS / 'JetBrainsMono-Medium.ttf').as_uri()}"); }}
* {{ margin: 0; padding: 0; box-sizing: border-box; }}
html, body {{ width: {w}px; height: {h}px; background: #0E0F0C; overflow: hidden; }}
.bg {{ position: absolute; inset: 0; }}
.center {{ position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; }}
.tile {{ width: {icon:.0f}px; height: {icon:.0f}px; border-radius: {icon * 0.2237:.0f}px; background: #0E0F0C; box-shadow: 0 0 0 {max(3, h // 600)}px #2A2B25, 0 {h * 0.03:.0f}px {h * 0.09:.0f}px rgba(0,0,0,.6), 0 0 {h * 0.22:.0f}px rgba(255,181,71,.18); display: grid; place-items: center; }}
.tile svg {{ width: 100%; height: 100%; }}
h1 {{ font: 800 {h * 0.17:.0f}px/1 "Bricolage", sans-serif; letter-spacing: -0.02em; color: #EDEAE2; margin-top: {h * 0.04:.0f}px; }}
p {{ font: 500 {h * 0.04:.0f}px/1.2 "JBMono", monospace; letter-spacing: 0.12em; text-transform: uppercase; color: #FFB547; margin-top: {h * 0.035:.0f}px; }}
</style></head><body>
<div class="bg">{background(w, h)}</div>
<div class="center">
  <div class="tile"><svg viewBox="0 0 1024 1024"><g transform="translate(512 504) scale(2.85) translate(-128 -128)">{SYMBOL}</g></svg></div>
  <h1>{html.escape(name)}</h1><p>{html.escape(line)}</p>
</div></body></html>'''


def render(src: Path, out: Path, w: int, h: int) -> None:
    tmp = out.with_suffix(".tmp.png")
    tmp.unlink(missing_ok=True)
    profile = tempfile.mkdtemp(prefix="fokus-hdr-chrome-")
    result = subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--no-first-run", "--hide-scrollbars",
         "--force-device-scale-factor=1", "--default-background-color=0E0F0CFF", f"--window-size={w},{h}",
         "--virtual-time-budget=4000", f"--screenshot={tmp}", src.as_uri()],
        capture_output=True, timeout=300)
    if not tmp.exists():
        raise RuntimeError(f"Chrome görüntü üretmedi: {result.stderr.decode(errors='replace')[-400:]}")
    img = Image.open(tmp).convert("RGB")  # alfa yok
    if img.size != (w, h):
        canvas = Image.new("RGB", (w, h), (14, 15, 12))
        canvas.paste(img.crop((0, 0, min(w, img.width), min(h, img.height))), (0, 0))
        img = canvas
    img.save(out, "PNG", optimize=True)
    tmp.unlink()


def main() -> int:
    with tempfile.TemporaryDirectory() as tmpdir:
        for rel, w, h, name, line in TARGETS:
            src = Path(tmpdir) / (Path(rel).stem + ".html")
            src.write_text(page(w, h, name, line), encoding="utf-8")
            out = ROOT / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            render(src, out, w, h)
            print("yazıldı", out.relative_to(ROOT.parent), Image.open(out).size)
    return 0


if __name__ == "__main__":
    sys.exit(main())
