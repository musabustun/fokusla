#!/bin/sh
# Fokus destek sitesi derleme adımı (Docker'da ve yerelde aynı betik).
#
#   SUPPORT_EMAIL=ornek@alanadi.com sh build.sh [çıktı-klasörü]   (varsayılan: ./dist)
#
# Kaynak HTML'deki __SUPPORT_EMAIL__ yer tutucusunu SUPPORT_EMAIL ile değiştirir. SUPPORT_EMAIL boşsa
# ya da geçerli bir e-posta biçiminde değilse, ya da derlemeden sonra yer tutucu kalırsa HATA verir.
# Depoda kişisel e-posta adresi tutulmaz; adres yalnızca derleme anında verilir.
set -eu

fail() {
  echo "HATA: $1" >&2
  exit 1
}

PLACEHOLDER='__SUPPORT_EMAIL__'
HERE=$(cd "$(dirname "$0")" && pwd)
OUT="${1:-$HERE/dist}"
EMAIL="${SUPPORT_EMAIL:-}"

[ -n "$EMAIL" ] || fail "SUPPORT_EMAIL boş. Coolify'da build argümanı olarak ver (README'ye bak)."

# sed yer değiştirmesini ve HTML/mailto bağlamını güvenli tutan sıkı biçim: yerel@alan.uzantı
printf '%s' "$EMAIL" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$' \
  || fail "SUPPORT_EMAIL geçerli bir e-posta adresi değil."

rm -rf "$OUT"
mkdir -p "$OUT"

# Yalnızca yayınlanacak dosyalar (Dockerfile, README vb. dışarıda kalır).
for item in index.html 404.html favicon.ico robots.txt sitemap.xml assets destek gizlilik; do
  [ -e "$HERE/$item" ] || fail "$item bulunamadı."
  cp -R "$HERE/$item" "$OUT/$item"
done

find "$OUT" -type f -name '*.html' | while IFS= read -r file; do
  sed "s|$PLACEHOLDER|$EMAIL|g" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
done

if grep -R -q "$PLACEHOLDER" "$OUT"; then
  fail "Derlemeden sonra $PLACEHOLDER yer tutucusu kaldı."
fi
grep -R -q "$EMAIL" "$OUT/destek/index.html" || fail "E-posta adresi destek sayfasına işlenmedi."

echo "Tamam: $OUT"
