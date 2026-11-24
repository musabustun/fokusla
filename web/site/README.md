# Fokus destek sitesi (`web/site/`)

`https://fokus.musabustun.dev` adresinde yayınlanan küçük, statik site. App Store'daki **Destek URL'si** (`/destek/`) ve **Gizlilik politikası** (`/gizlilik/`) buradan sunulur. `web/` altındaki Vite prototipinden bağımsızdır: ayrı klasör, ayrı derleme, JavaScript yok, dış istek yok, analitik yok, çerez yok.

## Sayfalar

| Yol          | İçerik                                                                                  |
| ------------ | --------------------------------------------------------------------------------------- |
| `/`          | Fokus'un kısa tanıtımı; Destek ve Gizlilik bağlantıları                                 |
| `/destek/`   | İletişim (e-posta + GitHub Issues), bildirimde neler yazılır, SSS, "Support in English" |
| `/gizlilik/` | Gizlilik politikası. Kaynak metin [`docs/privacy.md`](../../docs/privacy.md)            |
| `/healthz`   | `200 ok` (sağlık denetimi)                                                              |
| diğerleri    | `404.html`                                                                              |

İçerik güncellenirken: SSS'nin kaynağı [`docs/support.md`](../../docs/support.md), gizlilik metninin kaynağı `docs/privacy.md`'dir. Birini değiştirirsen ilgili HTML sayfasını da elle güncelle (iki yer ayrı tutulur; `gizlilik/index.html` başındaki yoruma bak).

## E-posta adresi (`SUPPORT_EMAIL`)

Depoda e-posta adresi **tutulmaz**. HTML kaynaklarında `__SUPPORT_EMAIL__` yer tutucusu vardır; `build.sh` derleme sırasında bunu `SUPPORT_EMAIL` değeriyle değiştirir. Değer boşsa, geçerli bir e-posta biçiminde değilse ya da derlemeden sonra yer tutucu kalırsa derleme **hata verir**.

Yerel deneme (Docker olmadan):

```bash
cd web/site
SUPPORT_EMAIL=ornek@example.com sh build.sh          # çıktı: web/site/dist (gitignore'da)
```

## Docker

```bash
cd web/site
docker build --build-arg SUPPORT_EMAIL=ornek@example.com -t fokus-site .
docker run --rm -p 8080:80 fokus-site                # http://localhost:8080
```

İmaj `nginx:1.27-alpine` üzerine kuruludur ve 80 numaralı portu dinler. `SUPPORT_EMAIL` verilmezse `docker build` şu hatayla durur: `HATA: SUPPORT_EMAIL boş`.

## Coolify ayarları

| Ayar            | Değer                                                                          |
| --------------- | ------------------------------------------------------------------------------ |
| Kaynak          | GitHub deposu `musabustun/fokusla` (herkese açık)                              |
| Branch          | `main`                                                                         |
| Base Directory  | `/web/site`                                                                    |
| Build Pack      | **Dockerfile** (Dockerfile Location: `/Dockerfile`)                            |
| Ports Exposes   | `80`                                                                           |
| Domains         | `https://fokus.musabustun.dev`                                                 |
| Build Variable  | `SUPPORT_EMAIL` = destek e-posta adresi (**"Build Variable" kutusu işaretli**) |
| Sağlık denetimi | Yol `/healthz`, port `80` (imajda `HEALTHCHECK` de var)                        |

Notlar:

- `SUPPORT_EMAIL` bir **build argümanı** olduğu için Coolify'da ortam değişkeni olarak "Build Variable"/"Build Time" seçeneğiyle eklenmelidir; yalnızca çalışma zamanı değişkeni olarak eklenirse derleme boş değerle başarısız olur.
- E-posta adresini değiştirmek için değişkeni güncelleyip yeniden dağıt (redeploy) yeterlidir.
- TLS'i Coolify'ın vekili (Traefik) sonlandırır; nginx yalnızca HTTP konuşur. Yönlendirmeler göreli olduğu için vekil arkasında doğru çalışır.

## nginx davranışı

- Temiz URL'ler: `/destek` → `301 /destek/`; `/destek/index.html` → `301 /destek/`.
- Yalnızca `GET`/`HEAD`; diğer yöntemler `405`. Gizli dosyalar (`/.git`, `/.env`) `404`.
- Güvenlik başlıkları (`security-headers.conf`): CSP yalnızca kendi kaynağı (`default-src 'none'`, `style/font/img 'self'`, `frame-ancestors 'none'`), `nosniff`, `Referrer-Policy`, `X-Frame-Options`, `Permissions-Policy`, HSTS. Sayfalarda satır içi stil/betik **olmamalıdır**; CSP bunları engeller.
- gzip açık. Önbellek: HTML `no-cache` (ETag ile doğrulanır), yazı tipleri 30 gün, diğer `/assets/` 1 saat, `favicon.ico` 7 gün.
- Nginx'te konumlara `add_header` **eklenmez**: bir konumda `add_header` varsa sunucu düzeyindeki güvenlik başlıkları o konumda kaybolur. Önbellek için `expires` kullanılır.

## Tasarım ve yazı tipleri

Renkler `web/src/ui/tokens.css` (Kahve paleti açık modu ve koyu "Gece mesaisi") ile aynıdır; `prefers-color-scheme` ile otomatik değişir. Yazı tipleri (Bricolage Grotesque, JetBrains Mono) uygulamayla aynı dosyalardır ve SIL OFL 1.1 lisanslıdır; lisans metinleri `assets/fonts/OFL-*.txt` içindedir. Dosyalar değiştirilmeden kopyalanmıştır (`ios/FokusKit/Sources/FokusDesign/Resources/Fonts`). Logo işareti `brand/logo/final` ile aynı geometridir.

`npm run format:check` (`web/` içinde) bu klasördeki HTML/CSS/MD dosyalarını da denetler.
