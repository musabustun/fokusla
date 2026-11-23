#!/usr/bin/env python3
"""App Store Connect metin sınırlarını doğrular (appstore/metadata/tr/*.txt).

Kullanım: python3 appstore/scripts/check_metadata.py
Çıkış kodu 0 = tüm sınırlar içinde; 1 = ihlal var.
Sınırlar karakter (Unicode kod noktası) ya da bayt (UTF-8) cinsindendir; ASC anahtar kelimeleri bayt sayar.
"""
import sys
import unicodedata
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / "metadata" / "tr"

# dosya -> (sınır, birim, zorunlu)
LIMITS = {
    "name.txt": (30, "chars", True),
    "subtitle.txt": (30, "chars", True),
    "promotional_text.txt": (170, "chars", True),
    "description.txt": (4000, "chars", True),
    "keywords.txt": (100, "bytes", True),
    "whats_new.txt": (4000, "chars", True),
    "review_notes.txt": (4000, "chars", True),
    "copyright.txt": (200, "chars", True),
    "support_url.txt": (2048, "chars", True),
    "marketing_url.txt": (2048, "chars", True),
    "privacy_url.txt": (2048, "chars", True),
}


def read(name: str) -> str:
    return unicodedata.normalize("NFC", (DIR / name).read_text(encoding="utf-8")).rstrip("\n")


def main() -> int:
    errors: list[str] = []
    print(f"{'dosya':26} {'kullanılan':>10} / {'sınır':<6} birim")
    for name, (limit, unit, required) in LIMITS.items():
        path = DIR / name
        if not path.exists():
            if required:
                errors.append(f"{name}: dosya yok")
            continue
        text = read(name)
        used = len(text) if unit == "chars" else len(text.encode("utf-8"))
        flag = "" if used <= limit else "  <-- AŞIYOR"
        print(f"{name:26} {used:>10} / {limit:<6} {unit}{flag}")
        if used > limit:
            errors.append(f"{name}: {used} > {limit} {unit}")
        if not text.strip():
            errors.append(f"{name}: boş")

    # Alternatif adlar: her satır ≤ 30.
    alt = DIR / "name-alternatives.txt"
    if alt.exists():
        for line in read("name-alternatives.txt").splitlines():
            if len(line) > 30:
                errors.append(f"name-alternatives.txt: '{line}' {len(line)} > 30")

    # Anahtar kelimeler: boşluksuz, virgüllü, tekrarsız, ad/alt başlıkla çakışmasız.
    keywords = read("keywords.txt")
    if " " in keywords:
        errors.append("keywords.txt: boşluk içeriyor")
    words = [w for w in keywords.split(",") if w]
    if len(words) != len(set(words)):
        errors.append("keywords.txt: tekrar eden kelime var")
    indexed = set(
        (read("name.txt") + " " + read("subtitle.txt")).lower().replace("İ", "i").replace("I", "ı").split()
    )
    clash = [w for w in words if w.lower() in indexed]
    if clash:
        errors.append(f"keywords.txt: ad/alt başlıkla tekrar: {clash}")

    if errors:
        print("\nHATA:")
        for e in errors:
            print(" -", e)
        return 1
    print("\nTamam: tüm sınırlar içinde.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
