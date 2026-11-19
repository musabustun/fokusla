# Katkı Rehberi

Fokus'a katkı verdiğin için teşekkürler. Fokus ücretsiz, reklamsız ve açık kaynaktır; bu ilkelere aykırı (ödeme, reklam, izleme SDK'sı, kendi sunucusu) katkılar kabul edilmez.

Başlamadan önce oku:

- [CLAUDE.md](CLAUDE.md) — proje kuralları, modül sahipliği, katman sınırları (insanlar için de geçerli)
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — katmanlar, veri akışı, Swift/CloudKit geçiş planı

## Kurulum

Gereksinimler: Node.js ≥ 22.12 (önerilen: `.nvmrc` → 26), npm.

```bash
nvm use                # .nvmrc'deki sürüm
cd web
npm ci
npm run dev            # http://localhost:5173
```

E2E testleri için bir kez: `npx playwright install chromium`.

## İş akışı

1. `main`'den dal aç: `feat/<modül>-<kısa-ad>`, `fix/…`, `docs/…`, `test/…`, `chore/…`.
2. Önce test yaz (TDD), sonra kodu.
3. Yerelde doğrula:
   ```bash
   npm run lint && npm run format:check && npm run typecheck && npm test && npm run build
   npm run e2e   # ekran/akış değiştiyse
   ```
4. `main` üzerine rebase et, PR aç. Şablonu doldur (özet, test planı, iPhone/iPad ekran görüntüleri).
5. CI yeşil olmadan birleştirme yapılmaz.

### Commit mesajları

[Conventional Commits](https://www.conventionalcommits.org/): `<tip>(<kapsam>): <açıklama>`

| Tip        | Ne zaman                                  |
| ---------- | ----------------------------------------- |
| `feat`     | Yeni özellik                              |
| `fix`      | Hata düzeltme                             |
| `refactor` | Davranışı değiştirmeyen yeniden düzenleme |
| `test`     | Yalnızca test                             |
| `docs`     | Belge                                     |
| `chore`    | Bağımlılık, yapılandırma                  |
| `perf`     | Performans                                |
| `ci`       | CI iş akışı                               |

Örnek: `feat(focus): mola sırasında oturumu duraklat`. Açıklama Türkçe ya da İngilizce olabilir; bir PR içinde tutarlı ol.

## Nasıl yapılır

### Bir modül ekranı

Ekranlar `web/src/app/router.tsx` içinde zaten kayıtlıdır (`features/<modül>/<Modül>Screen.tsx`). Kendi modülünün klasöründe çalış:

- Alt bileşenler: `features/<modül>/components/…`
- Modüle özgü hook'lar: `features/<modül>/use….ts`
- Testler dosyanın yanında: `….test.tsx`
- Başka bir modülden import YAPMA. İki modülün ortak ihtiyacı `ui/`, `domain/` veya `data/` katmanına taşınır.

### Bir rota

1. `web/src/app/routes.ts` → `ROUTES` içine yeni anahtar ekle (mevcut path'leri değiştirme; URL Türkçe, anahtar İngilizce).
2. `web/src/app/router.tsx` → kendi modülünün rota nesnesine `children` olarak ekle.
3. Link verirken `ROUTES.<anahtar>` kullan.
4. Gezinme menüsü (`NAV_ITEMS`) değişikliği ayrı PR'da tartışılır.

### Bir repository metodu

1. `web/src/data/repository.ts` → varlığa özel arayüze metot EKLE (mevcut imzayı değiştirme).
2. `web/src/data/dexie/` → implementasyon; okumalar `deletedAt != null` kayıtları varsayılan olarak hariç tutar.
3. `fake-indexeddb` ile testi yaz.
4. Gerekirse yeni index için `db.ts` içinde yeni `db.version(n + 1)` bloğu (mevcut bloklara dokunma).

### Bir varlık alanı

1. `web/src/domain/types.ts` → alanı `T | null` olarak EKLE. Silme/yeniden adlandırma yok (CloudKit şeması yalnızca eklemeye izin verir).
2. Türetilebilir bir değerse (net, süre, yüzde) alan ekleme; `domain/calc` içine saf fonksiyon yaz.
3. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) → "Varlık eşleme tablosu"na Swift tipini ve varsayılan değerini ekle.
4. PR açıklamasında ortak dosya değişikliğini belirt.

### Bir UI bileşeni

1. Önce `web/src/ui/README.md`'de var olanlara bak.
2. Yeni ortak bileşen `web/src/ui/` altına; yalnızca tasarım tokenları (ham renk yok), ≥ 44px dokunma hedefi, WCAG AA kontrast, açık + koyu tema.
3. Testini yaz, `web/src/ui/index.ts`'ten export et, `web/src/ui/README.md`'ye kısa girdi ekle.
4. `ui/` veri bilmez: `@/data`, feature veya app import edemez; her şeyi prop olarak alır.

### Müfredat kataloğu

YKS ders/konu listesi `web/src/curriculum/` altındadır; düzenleme kuralları `web/src/curriculum/README.md` içindedir. En önemli kural: **`catalogKey`'ler kalıcıdır** — asla değiştirilmez, silinmez veya yeniden kullanılmaz (kullanıcı verileri bu anahtarlara bağlıdır). Yeni konu yeni anahtarla eklenir. Katalog değiştiğinde `sources` ve `verifiedAt` alanlarını güncelle.

## Test

| Tür                   | Araç                                        | Yer                 | Komut                   |
| --------------------- | ------------------------------------------- | ------------------- | ----------------------- |
| Birim (saf fonksiyon) | Vitest                                      | `src/**/*.test.ts`  | `npm test`              |
| Bileşen / hook        | Vitest + Testing Library + `fake-indexeddb` | `src/**/*.test.tsx` | `npm test`              |
| Kapsam                | `@vitest/coverage-v8`                       | —                   | `npm run test:coverage` |
| E2E                   | Playwright (`iphone`, `ipad` projeleri)     | `web/e2e/*.spec.ts` | `npm run e2e`           |

Beklentiler: dokunulan kodda ≥ %80 kapsam; `domain/calc` fonksiyonları tablo tabanlı ve sınır durumlarıyla tam test; her modülün kritik akışı E2E'de. Sorguları rol ve Türkçe etiketle yaz (`getByRole('button', { name: 'Başlat' })`).

## Davranış kuralları

Saygılı, yapıcı ve kapsayıcı ol. Kişisel saldırı, taciz ve ayrımcılık kabul edilmez. [Contributor Covenant 2.1](https://www.contributor-covenant.org/version/2/1/code_of_conduct/) ilkeleri geçerlidir; sorunları depo sahibine GitHub üzerinden bildir.

## Lisans

Katkıların [MIT lisansı](LICENSE) altında yayımlanır.
