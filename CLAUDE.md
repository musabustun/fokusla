# Fokus — Proje Kuralları (önce bunu oku)

Bu dosya, bu repoda çalışan HER Claude Code oturumunun ve katkıcının ilk okuması gereken kurallardır. Modüller paralel oturumlarda geliştirilir; buradaki sınırlar çakışmayı önlemek içindir. Ayrıntılı mimari: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Katkı akışı: [CONTRIBUTING.md](CONTRIBUTING.md).

## Ürün özeti

Fokus, YKS'ye hazırlanan Türk öğrenciler için çalışma takip uygulamasıdır. Önce `web/` altında bir **web prototipi** ile tasarım ve davranış netleştirilir; ardından uygulama **SwiftUI + SwiftData + CloudKit** ile iPhone ve iPad için native olarak yeniden yazılır. Cross-platform yoktur.

Modüller: **Odak** (kronometre, duraklat/devam, oturum süresi, günlük toplam, ortalama kesintisiz odak ve ortalama mola; ders seçimi opsiyonel), **Konu/Test analizi** (ders → konu, kitap + test, D/Y/B, net = D − Y/4), **Kitap takibi** (her kitapta nereye kadar gelindi), **Görevler** (günlük rutinler + son tarihli ödevler), **Sosyal** (arkadaşlar, paralel odak odaları).

### Değişmez kurallar

| Kural                            | Anlamı                                                                                                                             |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Ücretsiz, reklamsız, premium yok | Ödeme, abonelik, reklam SDK'sı, analitik/izleme SDK'sı eklenmez.                                                                   |
| Veri cihazda                     | Kaynak veri cihazdadır (web: IndexedDB/Dexie, native: SwiftData). Kendi sunucumuz yoktur.                                          |
| Senkron yalnızca CloudKit        | iPhone ↔ iPad senkronu yalnızca Apple CloudKit (private database). Web prototipinde gerçek senkron YOKTUR; `SyncService` mock'tur. |
| Giriş opsiyonel                  | Tek yöntem "Apple ile Giriş"; "Şimdilik atla" her zaman mümkün. Uygulama girişsiz tam çalışır. Web'de mock'tur.                    |
| Dil                              | Arayüz metinleri Türkçe; kod tanımlayıcıları (değişken, tip, dosya adları) İngilizce. URL'ler Türkçe (`/odak`).                    |
| Onboarding minimal               | Hoş geldin → YKS alanı seçimi (SAY/EA/SÖZ/DİL) → opsiyonel Apple ile Giriş.                                                        |
| iPhone + iPad                    | Her ekran 390px (iPhone) ve 1024px (iPad) genişlikte iyi görünmeli.                                                                |

## Komutlar

Hepsi `web/` içinde çalışır (Node ≥ 22.12; repo kökündeki `.nvmrc` = 26).

```bash
cd web
npm ci                 # bağımlılıklar (package-lock.json'a göre)
npm run dev            # Vite geliştirme sunucusu, http://localhost:5173
npm run build          # tsc -b && vite build
npm run preview        # build çıktısını sun
npm run typecheck      # tsc -b
npm run lint           # eslint . --max-warnings=0
npm run format         # prettier --write .
npm run format:check   # prettier --check . (CI)
npm test               # vitest run (birim + bileşen testleri)
npm run test:watch     # vitest izleme modu
npm run test:coverage  # vitest run --coverage (v8)
npm run e2e            # playwright test (iPhone + iPad projeleri, Chromium)
```

PR öncesi yeşil olmalı: `npm run lint && npm run format:check && npm run typecheck && npm test && npm run build` (CI ayrıca `npm run e2e` çalıştırır).

## Klasör yapısı (`web/src`)

| Klasör              | Ne içerir                                                                                                                                                                                                                                                                                         | Ne İÇERMEZ                                                    |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| `app/`              | `router.tsx` (rota tablosu), `routes.ts` (`ROUTES`, `NAV_ITEMS`), `App.tsx`, `layout/` (iPhone tab bar / iPad kenar çubuğu), `NotFoundScreen.tsx`                                                                                                                                                 | İş mantığı, veri erişimi                                      |
| `ui/`               | Tasarım sistemi: tokenlar, `ThemeProvider`/`useTheme`, ortak bileşenler (Button, Card, ListSection/ListRow, Sheet, SegmentedControl, ProgressRing, EmptyState, ScreenHeader). Public API: `@/ui` (`ui/index.ts`). Rehber: `web/src/ui/README.md`                                                  | Veri erişimi, feature'a özgü bileşenler                       |
| `domain/`           | `types.ts` (tüm varlıklar — TEK DOĞRULUK KAYNAĞI), `ids.ts` (`newId`, `toISODateTime`, `toISODate`, `catalogEntityId`)                                                                                                                                                                            | React, Dexie, tarayıcı API'si (crypto hariç)                  |
| `domain/calc/`      | Saf hesap fonksiyonları: `focus.ts`, `tests.ts`, `books.ts`, `tasks.ts` (+ `notImplemented.ts`)                                                                                                                                                                                                   | Yan etki, `Date.now()` çağrısı (`now` parametre olarak gelir) |
| `data/`             | Repository sözleşmeleri (`repository.ts`), Dexie implementasyonu (`data/dexie/`), `AuthService`, `SyncService`, mock servisler, `ServicesProvider`/`useServices`, hook'lar (`useLiveData`, `useCurrentProfile`, `useSyncState`), `ensureCurriculumSeeded`. Public API: `@/data` (`data/index.ts`) | UI, feature kodu                                              |
| `curriculum/`       | YKS müfredat kataloğu (`yksCurriculum`), `types.ts`. Saf veri. Rehber: `web/src/curriculum/README.md`                                                                                                                                                                                             | Dexie, React                                                  |
| `features/<modül>/` | Modül ekranları, modüle özgü bileşenler, hook'lar ve testleri                                                                                                                                                                                                                                     | Başka modülün kodu                                            |
| `test/`             | Vitest kurulumu (`setup.ts`: jest-dom, `fake-indexeddb/auto`) ve ortak test yardımcıları (`services.ts` → `createTestServices()`)                                                                                                                                                                 | Üretim kodu                                                   |

E2E testleri `web/e2e/` altındadır (`*.spec.ts`).

## Modül sahipliği

Her paralel oturum YALNIZCA kendi satırındaki dosyaları yazar. Diğer satırlardaki varlıkları **okuyabilir** (repository üzerinden), ama yazmaz.

| Modül (`features/…`) | Rota (`ROUTES.*`)            | Yazdığı varlıklar (`domain/types.ts`)                                  | Calc dosyası                                                                                           | Repository'ler (`useServices().repositories.*`)                                               |
| -------------------- | ---------------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| `today`              | `today` → `/`                | — (yalnızca okur)                                                      | Diğer calc dosyalarını yalnızca KULLANIR; kendine ait hesap gerekirse `domain/calc/today.ts` oluşturur | Okur: `focusSessions`, `focusSegments`, `tasks`, `taskCompletions`, `testResults`, `profiles` |
| `focus`              | `focus` → `/odak`            | `FocusSession`, `FocusSegment`                                         | `domain/calc/focus.ts`                                                                                 | `focusSessions`, `focusSegments` (okur: `subjects`, `topics`)                                 |
| `analysis`           | `analysis` → `/analiz`       | `TestResult`; kullanıcı tanımlı `Subject`/`Topic` (`catalogKey: null`) | `domain/calc/tests.ts`                                                                                 | `testResults`, `subjects`, `topics` (okur: `books`)                                           |
| `books`              | `books` → `/kitaplar`        | `Book`, `BookProgress`                                                 | `domain/calc/books.ts`                                                                                 | `books`, `bookProgress` (okur: `subjects`, `topics`)                                          |
| `tasks`              | `tasks` → `/gorevler`        | `Task`, `TaskCompletion`                                               | `domain/calc/tasks.ts`                                                                                 | `tasks`, `taskCompletions` (okur: `subjects`)                                                 |
| `social`             | `social` → `/sosyal`         | `Friend`, `Room` (TASLAK, web'de mock)                                 | Gerekirse `domain/calc/social.ts`                                                                      | `friends`, `rooms`                                                                            |
| `settings`           | `settings` → `/ayarlar`      | `UserProfile` (düzenleme), tema, giriş/çıkış, senkron aç/kapa          | —                                                                                                      | `profiles`; `auth`, `sync` servisleri                                                         |
| `onboarding`         | `onboarding` → `/hos-geldin` | `UserProfile` (oluşturma, `onboardingCompletedAt`)                     | —                                                                                                      | `profiles`; `auth` servisi                                                                    |

Katalog dersleri/konuları (`catalogKey != null`) `data/` içindeki `ensureCurriculumSeeded` tarafından `curriculum/` kataloğundan tohumlanır; feature'lar bunları düzenlemez.

## Modül sınırları (ESLint ile zorlanır)

`web/eslint.config.js` içindeki `no-restricted-imports` kuralları; ihlal `npm run lint`'i kırar.

| Katman         | İmport edebilir                                                                                                     | İmport EDEMEZ                                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `features/<x>` | Kendi klasörü, `@/ui`, `@/domain` (ve `@/domain/calc/*`), `@/data` (yalnızca index), `@/curriculum`, `@/app/routes` | Başka feature (`@/features/<y>`), `@/app/*` (routes hariç), `@/data/*` iç dosyaları, `dexie`, `dexie-react-hooks` |
| `ui/`          | Kendi dosyaları, `@/domain` tipleri, React, lucide-react                                                            | `@/features/*`, `@/data`, `@/app/*`, `@/curriculum/*`, Dexie                                                      |
| `domain/`      | Kendi dosyaları (göreli import)                                                                                     | `react`, `react-dom`, `react-router`, `zustand`, `@/*` (domain hariç), Dexie                                      |
| `curriculum/`  | `@/domain`, `@/curriculum`                                                                                          | `react`, diğer `@/*`, Dexie                                                                                       |
| `data/`        | `@/domain`, `@/curriculum`, Dexie, React (provider/hook'lar için)                                                   | `@/features/*`, `@/ui`, `@/app/*`                                                                                 |
| `app/`         | `@/features/*` (yalnızca `router.tsx` ekranları kaydetmek için), `@/ui`, `@/data`, `@/domain`                       | `@/data/*` iç dosyaları, Dexie                                                                                    |

Özet: **feature ↛ feature**; **Dexie'ye yalnızca `src/data` dokunur**; **ui saftır** (veri bilmez, prop alır); **domain framework'süzdür**. Rotalara link verirken `ROUTES.focus` gibi sabitleri kullan, string path yazma.

## Paralel oturumlar için ortak dosya protokolü

Birden fazla oturumun dokunabileceği dosyalar. Genel kural: **yalnızca ekleme (additive-only)**, küçük PR, `main` üzerine rebase, PR açıklamasında hangi ortak dosyaya ne eklendiğini belirt.

| Dosya                     | Kim değiştirebilir                            | Kural                                                                                                                                                                                                 |
| ------------------------- | --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `domain/types.ts`         | Varlığın sahibi olan modül (yukarıdaki tablo) | Yalnızca yeni alan/tip EKLE. Alan silme, yeniden adlandırma, tip daraltma YOK. Yeni alan `T \| null` olsun. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) eşleme tablosunu aynı PR'da güncelle.        |
| `data/repository.ts`      | Varlığın sahibi olan modül                    | Varlığa özel arayüze yeni metot EKLE (+ `data/dexie/` implementasyonu + test). Mevcut imzaları değiştirme.                                                                                            |
| `data/dexie/db.ts` (şema) | Varlığın sahibi olan modül                    | Mevcut `db.version(n)` bloklarına DOKUNMA. Yeni index/tablo için yeni bir `db.version(n + 1)` bloğu ekle. Aynı anda iki PR aynı versiyon numarasını alırsa ikinci gelen rebase edip numarayı artırır. |
| `domain/calc/<modül>.ts`  | Yalnızca o modülün oturumu                    | Diğer modüller yalnızca çağırır. Başka modülün calc'ına ihtiyaç duyulan fonksiyon ekleneceksek sahibine bırak veya kendi calc dosyanı aç.                                                             |
| `app/router.tsx`          | Herkes (yalnızca kendi satırı)                | Ekran kayıtları zaten var. Alt rota gerekiyorsa yalnızca kendi rota nesnene `children` ekle.                                                                                                          |
| `app/routes.ts`           | Herkes (yalnızca kendi anahtarı)              | `ROUTES`'a yalnızca yeni anahtar ekle; mevcut path'leri değiştirme. `NAV_ITEMS` sırası/`inTabBar` değişikliği ayrı bir PR'da tartışılır.                                                              |
| `ui/`                     | Herkes                                        | Yeni ortak bileşen `src/ui` altına, testiyle birlikte, `ui/index.ts` export'u ve `web/src/ui/README.md` girdisiyle eklenir. Mevcut bileşen prop'ları yalnızca opsiyonel prop eklenerek genişletilir.  |
| `curriculum/`             | Müfredat güncellemesi yapan                   | `catalogKey`'ler kalıcıdır, asla değiştirilmez/silinmez. Bkz. `web/src/curriculum/README.md`.                                                                                                         |

**İkinci bir modül bir şeye ihtiyaç duyarsa** onu ortak katmana taşı (`ui/`, `domain/`, `data/`) — asla feature'lar arası import yapma, kopyalama da yapma.

## Veri katmanı kuralları

- **Kimlik:** Her kayıt `id: UUID` (v4, küçük harf, `newId()`). Otomatik artan sayı yok. İstisna: müfredat katalog kayıtlarının id'si `catalogKey`'den deterministik UUID v5'tir (`catalogEntityId`) — her cihaz aynı id'yi üretir, CloudKit'te kopya oluşmaz. Önceden belirlenmiş id gerekiyorsa `repository.create(input, { id })`.
- **Ortak alanlar:** `createdAt`, `updatedAt`, `deletedAt` (`BaseEntity`). Repository doldurur; `NewEntity<T>` / `EntityPatch<T>` kullan.
- **Soft delete:** `delete()` yalnızca `deletedAt` set eder (CloudKit tombstone'u). Okumalar silinenleri varsayılan olarak hariç tutar. Kalıcı silme yok.
- **Türetilmiş değer saklanmaz:** net, süre, ilerleme yüzdesi, günlük toplam, ortalama → `domain/calc`'te hesaplanır.
- **Süreler zaman damgasından:** Odak süreleri `FocusSegment.startedAt/endedAt` farkından hesaplanır; sayaç değeri saklanmaz.
- **Tarih biçimleri:** Anlık zaman `ISODateTime` (UTC, `toISODateTime()`); takvim günü `ISODate` (`YYYY-MM-DD`, YEREL gün, `toISODate()`).
- **Değişmezlik:** Girdi nesnelerini mutasyona uğratma; repository yeni nesne döndürür. React state'i de kopyalanarak güncellenir.
- **Yazma → senkron kaydı:** Repository her yazmadan sonra `SyncService.recordLocalChange()` çağırır (data katmanının işi; feature'lar çağırmaz).
- **Şema yalnızca büyür:** CloudKit production şeması yalnızca eklemeye izin verir; web şeması da aynı disiplinle yönetilir. Alan eklerken [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) içindeki Swift/CloudKit eşleme tablosunu güncelle.
- **Erişim:** Feature'lar veriye yalnızca `@/data` üzerinden (`useServices().repositories`, `useLiveData`, `useCurrentProfile`) erişir.

## Test beklentileri

- **TDD:** Önce test (kırmızı), sonra minimal implementasyon (yeşil), sonra refactor.
- **Yer:** Vitest testleri kodun yanında: `foo.ts` → `foo.test.ts` (`src/**/*.test.{ts,tsx}`). E2E: `web/e2e/*.spec.ts`.
- **Kapsam:** Dokunulan kodda ≥ %80 (`npm run test:coverage`). `domain/calc` fonksiyonları %100 hedeflenir: sınır durumları (boş liste, açık segment, gece yarısı, saat dilimi) tablo tabanlı testlerle. Bu test vakaları Swift port'unda tekrar kullanılacak.
- **Bileşen testleri:** Testing Library + `user-event`; sorgular rol/etiket ile (Türkçe metin). Veri gereken testlerde `createTestServices()` (`@/test/services`) ile gerçek repository'ler (fake-indexeddb, test başına ayrı DB) oluştur, `ServicesProvider`'a ver, `afterEach`'te `dispose()` çağır. Feature testleri de Dexie'yi import edemez (ESLint). Örnek: `web/src/features/onboarding/OnboardingScreen.test.tsx`.
- **E2E:** Her modül en az kritik akışını Playwright'ta test eder; iki proje (`iphone`, `ipad`) otomatik çalışır.
- **PR öncesi:** `npm run lint && npm run format:check && npm run typecheck && npm test && npm run build` yeşil.

## Tasarım kuralları

- Yalnızca tasarım tokenları (Tailwind tema değişkenleri / `ui` tokenları). Ham renk (`#hex`, `rgb()`, `text-red-500` gibi palet sınıfları) yasak.
- Dokunma hedefleri ≥ 44×44 px. Kontrast WCAG AA. Klavye ile erişilebilir, görünür odak halkası.
- Önce ortak `ui` bileşenlerini kullan; yoksa ekle (bkz. protokol).
- 390px (iPhone) ve 1024px (iPad yatay) genişlikte, açık ve koyu temada kontrol et. iPhone: alt tab bar; iPad: kenar çubuğu (`app/layout/`).
- Native hissi: iOS benzeri liste/sayfa düzeni, sistem fontu, hareket azaltma (`prefers-reduced-motion`) desteği.
- Türkçe metinler: doğru büyük/küçük harf (`İ/ı`), `toLocaleUpperCase('tr-TR')`, sayılar `Intl.NumberFormat('tr-TR')`.

## Git

- Her modül/iş için ayrı dal: `feat/focus-timer`, `fix/tasks-due-date`, `docs/architecture`.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `perf:`, `ci:` (kapsam opsiyonel: `feat(focus): …`).
- PR hedefi `main`. Küçük tut; açmadan önce `main` üzerine rebase et. Türkçe PR açıklaması uygundur; şablondaki test planını doldur (`.github/pull_request_template.md`).
- Ortak dosyalara (yukarıdaki tablo) yapılan her değişikliği PR açıklamasında ayrıca belirt.
