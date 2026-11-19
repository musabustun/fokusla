# Fokus — iOS / iPadOS

SwiftUI + SwiftData + CloudKit ile yazılan native uygulama. Tasarım ve davranışın referansı `web/`
prototipidir; sözleşmeler (varlıklar, raw value'lar, hesaplar, katalog id'leri) birebir korunur.
Kurallar: kök [`CLAUDE.md`](../CLAUDE.md) → "iOS" bölümü; eşleme: [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) bölüm 4.

## Gereksinimler

- Xcode 27+ (iOS 18.0 dağıtım hedefi, Swift 6 dil modu, strict concurrency)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `.xcodeproj` üretilir, git'e girmez

## Komutlar

Hepsi `ios/` içinde:

```bash
xcodegen generate                       # Fokus.xcodeproj üret (project.yml değişince tekrar)
open Fokus.xcodeproj

# Simülatör derlemesi (imzasız)
xcodebuild build -project Fokus.xcodeproj -scheme Fokus \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Tüm testler (paket birim testleri + XCUITest) — iPhone ve iPad
xcodebuild test -project Fokus.xcodeproj -scheme Fokus \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
xcodebuild test -project Fokus.xcodeproj -scheme Fokus \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' CODE_SIGNING_ALLOWED=NO

# Hızlı döngü: Domain/Data testleri macOS'ta, simülatörsüz
cd FokusKit && swift test --filter FokusDomainTests
cd FokusKit && swift test --filter FokusDataTests
```

PR öncesi: `xcodegen generate` + yukarıdaki `build` ve iki `test` komutu yeşil. GitHub Actions
kapalı; doğrulama yereldir.

## Yapı

```
ios/
├── project.yml              XcodeGen spesifikasyonu (hedefler, şema, paket)
├── Config/Fokus.xcconfig    Kimlikler: bundle ID, iCloud kapsayıcısı, takım, sürüm
├── Fokus/                   Uygulama hedefi — yalnızca kompozisyon + ekranlar
│   ├── App/                 FokusApp, container kurulumu, kök kapı, kabuk (TabView / NavigationSplitView)
│   ├── Features/<Modül>/    Modül ekranları (Today, Focus, Analysis, Books, Tasks, Social, Settings, Onboarding)
│   ├── Resources/           Assets.xcassets (uygulama ikonu, AccentColor)
│   ├── Info.plist, Fokus.entitlements
├── FokusUITests/            XCUITest duman testleri
└── FokusKit/                Yerel Swift paketi
    ├── Sources/FokusDomain  Saf tipler + hesaplar (Foundation + CryptoKit; framework yok)
    ├── Sources/FokusData    SwiftData @Model'ler, şema, store, repository'ler, katalog, Auth/Sync servisleri
    ├── Sources/FokusDesign  Tokenlar, paletler, fontlar, ortak bileşenler (rehber: FokusDesign/README.md)
    └── Tests/…              Swift Testing birim testleri
```

Bağımlılık yönü (web ile aynı): `FokusDomain` ← `FokusData`, `FokusDomain` ← `FokusDesign`,
uygulama hepsine bağlı. Domain hiçbir şeye bağlı değildir; Design veri bilmez; Data UI bilmez.

## Veri

- **Modeller:** `FokusData/Models/` — `docs/ARCHITECTURE.md` 4.3 tablosundaki 12 varlık. CloudKit
  kuralları: `@Attribute(.unique)` yok, tüm özellikler opsiyonel ya da varsayılanlı, ilişki yok
  (düz `UUID?` yabancı anahtar), `id: UUID`, `createdAt/updatedAt/deletedAt`. Enum'lar raw string
  saklanır (`fieldRaw`), hesaplanan özellikle sunulur. Model adları CloudKit kayıt tipini belirler
  (`CD_<Model>`): **asla yeniden adlandırma**.
- **Şema:** `FokusSchemaV1` + `FokusMigrationPlan`. Yalnızca ekleme; `SchemaCloudKitRulesTests` kuralları denetler.
- **Store:** `FokusStore.preferredMode(...)` → iCloud hesabı varsa ve kullanıcı senkronu kapatmadıysa
  `.cloudKit` (`ModelConfiguration(cloudKitDatabase: .private("iCloud.com.musabustun.fokus"))`),
  aksi halde `.local`; testler/önizlemeler `.inMemory`. UI testleri `-FokusUITestMode` ile bellek içi açılır.
- **Okuma/yazma:** Ekranlar okumak için `@Query` (silinmemiş: `#Predicate { $0.deletedAt == nil }`),
  yazmak için repository (`EntityStore<T>`, `ProfileRepository`, modülün kendi repository'si) kullanır.
  Silme = `softDelete` (tombstone). Türetilmiş değer saklanmaz.
- **Katalog:** `FokusData/Resources/yks-curriculum.json` web `web/src/curriculum/` kataloğundan üretilir;
  `CurriculumSeeder` açılışta idempotent tohumlar. Katalog id'leri `Identifiers.catalogEntityId`
  (UUID v5, web ile aynı namespace) — `CatalogIdTests` web'in ürettiği id'lerle karşılaştırır.

### Müfredatı güncelleme

1. Web kataloğunu güncelle (`web/src/curriculum/`, kurallar onun README'sinde).
2. `cd web && npm run export:ios-curriculum` → JSON kaynağı ve id fikstürü yeniden yazılır.
3. Web (`npx vitest run src/curriculum`) ve iOS testleri yeşil olmalı.

## Tasarım ve paletler

Rehber: [`FokusKit/Sources/FokusDesign/README.md`](FokusKit/Sources/FokusDesign/README.md).
Tema = palet × görünüm. `@AppStorage("fokus.theme.palette")` (varsayılan `kahve`) ve
`@AppStorage("fokus.theme.appearance")` (`system` / `light` / `dark`), kökte `.fokusTheme()`.
Şimdilik yalnızca **Kahve** (mevcut "Gece mesaisi") var. Web'deki palet PR'ı birleşince her palet:
`FokusPalette`'e bir case + `Colors.xcassets/<Palet>/` klasörü (Any = açık, Dark = koyu) +
test tablosuna hex değerleri. Ardından onboarding'deki tema adımı (yer tutucu) açılır.

## Port edilecek hesaplar (modül oturumları)

Referans port: `FokusDomain/Calc/FocusCalc.swift` (web `focus.ts`, tüm test vakalarıyla). Kalanlar,
aynı desenle (saf `enum`, `now`/`calendar` parametre, snapshot girdiler, web test tabloları birebir):

| Web dosyası             | Swift hedefi                        | Sahip modül |
| ----------------------- | ----------------------------------- | ----------- |
| `domain/calc/tests.ts`  | `FokusDomain/Calc/TestsCalc.swift`  | analysis    |
| `domain/calc/books.ts`  | `FokusDomain/Calc/BooksCalc.swift`  | books       |
| `domain/calc/tasks.ts`  | `FokusDomain/Calc/TasksCalc.swift`  | tasks       |
| `domain/calc/today.ts`  | `FokusDomain/Calc/TodayCalc.swift`  | today       |
| `domain/calc/social.ts` | `FokusDomain/Calc/SocialCalc.swift` | social      |

Gereken snapshot tipleri `FokusDomain/Snapshots.swift`'e eklenir; `@Model` tarafında `.snapshot`.

## Cihazda çalıştırma (Apple tarafı)

Simülatör derlemesi imzasızdır (`CODE_SIGNING_ALLOWED=NO`); CloudKit ve Apple ile Giriş orada
çalışmaz (uygulama `.local` depoya düşer; giriş adımı hata mesajı gösterir, "Şimdilik atla" çalışır).
Gerçek cihaz için takım `395SFU52ZD` hesabında bir kez:

1. **App ID** `com.musabustun.fokus` — yetenekler: iCloud (CloudKit), Sign in with Apple, Push Notifications.
2. **iCloud kapsayıcısı** `iCloud.com.musabustun.fokus` oluştur ve App ID'ye bağla.
3. Xcode'da otomatik imzalama (ya da bir kez `xcodebuild -allowProvisioningUpdates`) ile geliştirme
   profili üretilir; cihaz takıma kayıtlı olmalı.
4. CloudKit Development şemasını başlat: DEBUG derlemesini iCloud'a girişli bir cihazda çalıştırıp
   veri yaz (ya da `NSPersistentCloudKitContainer.initializeCloudKitSchema()` ile tek seferlik bir
   yardımcı); CloudKit Console'da kayıt tiplerini (`CD_UserProfile` …) doğrula; yayından önce Production'a deploy et.
5. TestFlight/App Store öncesi `aps-environment` → `production` (Release imzası bunu otomatik yapar).
