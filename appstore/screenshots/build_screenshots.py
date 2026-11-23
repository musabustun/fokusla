#!/usr/bin/env python3
"""Mağaza karuselini üretir: ham ekran görüntüleri -> cihaz çerçevesi + başlık -> tam boy PNG.

Kullanım:
  python3 appstore/screenshots/build_screenshots.py --raw <ham klasör> --out appstore/screenshots [--only iphone|ipad]

Girdi: <ham klasör>/<aygıt>/<ad>.png  (aygıt: iphone | ipad; ham görüntüler 1320x2868 / 2064x2752)
Çıktı: appstore/screenshots/iphone-6.9/NN-*.png (1320x2868) ve ipad-13/NN-*.png (2064x2752); alfa kanalı YOK.
Yöntem: HTML/CSS şablonu + headless Chrome (dış ağ/indirme yok; fontlar repo içinden).
"""
import argparse
import html
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Her aygıt: tuval boyutu, ham ekran boyutu, düzen ölçüleri ve panel listesi (sıra = karusel sırası).
DEVICES = {
    "iphone": {
        "dir": "iphone-6.9", "size": (1320, 2868),
        "css": {"pad": 110, "copyTop": 150, "eyebrow": 38, "h1": 118, "sub": 50, "gap": 34,
                "devTop": 700, "devW": 930, "bezel": 24, "outerR": 130, "innerR": 106},
        "panels": json.loads((HERE / "src" / "iphone.json").read_text(encoding="utf-8")),
    },
    "ipad": {
        "dir": "ipad-13", "size": (2064, 2752),
        "css": {"pad": 150, "copyTop": 150, "eyebrow": 44, "h1": 136, "sub": 58, "gap": 36,
                "devTop": 740, "devW": 1340, "bezel": 30, "outerR": 120, "innerR": 90},
        "panels": json.loads((HERE / "src" / "ipad.json").read_text(encoding="utf-8")),
    },
}


def flow_svg(w: int, h: int, n: int, device: str) -> str:
    """Tüm şerit boyunca akan: yumuşak kehribar ışık, ince zaman çizelgesi ve ilerleme yayı."""
    total = w * n
    y0 = int(h * 0.62)
    # Ardışık panellerde sürekli bir dalga (kronometre/odak akışı): tek path, N paneli kapsar.
    pts = []
    steps = n * 8
    for k in range(steps + 1):
        x = total * k / steps
        phase = k / steps * n * 1.15
        import math
        y = y0 + math.sin(phase * math.pi * 1.0) * h * 0.11 + math.sin(phase * math.pi * 2.3) * h * 0.02
        pts.append((x, y))
    d = "M " + " L ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
    ticks = []
    tick_gap = w // 12
    for k in range(0, total // tick_gap + 1):
        x = k * tick_gap
        major = k % 6 == 0
        ticks.append(f'<line x1="{x}" y1="{h - 150}" x2="{x}" y2="{h - (95 if major else 120)}" stroke="rgba(237,234,226,{0.28 if major else 0.12})" stroke-width="{3 if major else 2}"/>')
        if major:
            ticks.append(f'<text x="{x + 12}" y="{h - 62}" font-family="JBMono" font-size="{w // 55}" fill="rgba(237,234,226,0.28)" letter-spacing="2">{(k // 6) * 25:02d}:00</text>')
    glow = []
    for k in range(n):
        cx = w * (k + 0.5) + (w * 0.42 if k % 2 == 0 else -w * 0.42)
        cy = h * (0.30 if k % 2 == 0 else 0.78)
        glow.append(f'<circle cx="{cx:.0f}" cy="{cy:.0f}" r="{w * 0.62:.0f}" fill="url(#g)" opacity="{0.55 if k % 2 == 0 else 0.4}"/>')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {total} {h}" preserveAspectRatio="none">
  <defs><radialGradient id="g"><stop offset="0" stop-color="#FFB547" stop-opacity="0.20"/><stop offset="1" stop-color="#FFB547" stop-opacity="0"/></radialGradient>
  <linearGradient id="s" x1="0" x2="1"><stop offset="0" stop-color="#FFB547" stop-opacity="0.05"/><stop offset="0.5" stop-color="#FFB547" stop-opacity="0.55"/><stop offset="1" stop-color="#FFB547" stop-opacity="0.05"/></linearGradient></defs>
  {''.join(glow)}
  <path d="{d}" fill="none" stroke="url(#s)" stroke-width="{max(3, w // 300)}" stroke-linecap="round"/>
  <line x1="0" y1="{h - 150}" x2="{total}" y2="{h - 150}" stroke="rgba(237,234,226,0.10)" stroke-width="2"/>
  {''.join(ticks)}
</svg>'''


def cover_html(panel: dict, raw_path: Path) -> str:
    """Tab bar'ın altındaki, ekranın en alt şeridinde görünen kısmi satırı (taşma gibi görünür) uygulamanın
    kendi zemin rengiyle örter. Renk, ham görüntünün sol kenarından (tab bar ve satırın dışından) örneklenir."""
    if not panel.get("tabbar"):
        return ""
    with Image.open(raw_path) as im:
        r, g, b = im.convert("RGB").getpixel((14, im.height - 90))
    return f'<div class="cover" style="background: rgb({r},{g},{b})"></div>'


def page_html(device: str, cfg: dict, index: int, panel: dict, raw_path: Path) -> str:
    w, h = cfg["size"]
    css_vars = "".join(f"--{k}: {v}px;" for k, v in cfg["css"].items())
    n = len(cfg["panels"])
    return f'''<!doctype html><html lang="tr"><head><meta charset="utf-8">
<link rel="stylesheet" href="{(HERE / 'src' / 'panel.css').as_uri()}">
<style>:root {{ --W: {w}px; --H: {h}px; --N: {n}; --i: {index}; {css_vars} }}</style></head>
<body><div class="panel">
  <div class="flow">{flow_svg(w, h, n, device)}</div>
  <div class="copy"><div class="eyebrow">{html.escape(panel["eyebrow"])}</div>
    <h1>{html.escape(panel["title"])}</h1><p class="sub">{html.escape(panel["sub"])}</p></div>
  <div class="device {'phone' if device == 'iphone' else 'pad'}"><div class="screen"><img src="{raw_path.as_uri()}">{cover_html(panel, raw_path)}</div></div>
</div></body></html>'''


def render(html_path: Path, out: Path, size: tuple[int, int]) -> None:
    w, h = size
    tmp = out.with_suffix(".tmp.png")
    tmp.unlink(missing_ok=True)
    profile = tempfile.mkdtemp(prefix="fokus-shots-chrome-")
    result = subprocess.run(
        [CHROME, "--headless=new", "--disable-gpu", f"--user-data-dir={profile}", "--no-first-run", "--hide-scrollbars", "--force-device-scale-factor=1",
         "--default-background-color=0E0F0CFF", f"--window-size={w},{h}", "--virtual-time-budget=4000",
         f"--screenshot={tmp}", html_path.as_uri()],
        capture_output=True, timeout=180)
    if not tmp.exists():  # çıkış kodu teardown'da 0 olmayabilir; asıl ölçüt dosyanın oluşması
        raise RuntimeError(f"Chrome görüntü üretmedi: {result.stderr.decode(errors='replace')[-400:]}")
    img = Image.open(tmp).convert("RGB")  # alfa kanalını at
    if img.size != (w, h):  # headless bazen pencere çerçevesi kadar fark verir: tuvale kırp/doldur
        canvas = Image.new("RGB", (w, h), (14, 15, 12))
        canvas.paste(img.crop((0, 0, min(w, img.width), min(h, img.height))), (0, 0))
        img = canvas
    img.save(out, "PNG", optimize=True)
    tmp.unlink()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--raw", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--only", choices=list(DEVICES))
    args = ap.parse_args()
    for device, cfg in DEVICES.items():
        if args.only and args.only != device:
            continue
        out_dir = args.out / cfg["dir"]
        out_dir.mkdir(parents=True, exist_ok=True)
        for old in out_dir.glob("*.png"):
            old.unlink()
        with tempfile.TemporaryDirectory() as tmpdir:
            for index, panel in enumerate(cfg["panels"]):
                raw = args.raw / device / f"{panel['raw']}.png"
                if not raw.exists():
                    print(f"EKSİK ham görüntü: {raw}", file=sys.stderr)
                    return 1
                page = Path(tmpdir) / f"{index}.html"
                page.write_text(page_html(device, cfg, index, panel, raw.resolve()), encoding="utf-8")
                out = out_dir / f"{index + 1:02d}-{panel['slug']}.png"
                render(page, out, cfg["size"])
                print("yazıldı", out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
