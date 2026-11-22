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
    ├── Sources/FokusAudio   Cihazda üretilen odak sesleri (AVAudioEngine) + `MusicProvider` sözleşmesi (bkz. "Odak sesleri ve müzik")
    └── Tests/…              Swift Testing birim testleri
```

Bağımlılık yönü (web ile aynı): `FokusDomain` ← `FokusData`, `FokusDomain` ← `FokusDesign`,
uygulama hepsine bağlı. Domain hiçbir şeye bağlı değildir; Design veri bilmez; Data UI bilmez.
`FokusAudio` hiçbir FokusKit hedefine bağlı değildir (yalnızca Foundation/AVFoundation/Observation);
uygulama hedefi dışında kimse ona bağlanmaz.

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
Tema = palet × görünüm, web ile aynı anahtarlar: `@AppStorage("fokus.palette")` (`coffee` varsayılan,
`mono`, `strawberry`, `matcha`, `blueberry`, `lemonade`) ve `@AppStorage("fokus.theme")`
(`system` varsayılan / `light` / `dark`); kökte `.fokusTheme()`. Seçim: onboarding "Temanı seç" adımı ve
Ayarlar (`PalettePicker`). Renklerin tek kaynağı web `tokens.ts`:
`cd web && npm run export:ios-palettes` → `python3 scripts/generate_palette_assets.py`.

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

## Odak: tam ekran, sesler ve müzik

**Tam ekran (StandBy benzeri)** — `Fokus/Features/Focus/Immersive/`. Odak başlayınca (ya da açık
oturumla uygulama açılınca) `fullScreenCover` açılır: ekran sönmez, durum çubuğu ve ev göstergesi
gizlidir, dikey + yatay çalışır. Yatay kaydırmalı sayfalar: kronometre + saat, ilerleme halkası, "gece"
(saf siyah, yalnızca süre), bugünün özeti, ses ve müzik. Son sayfa `@AppStorage("fokus.focus.immersivePage")`
ile hatırlanır. Dokununca beliren kontrol katmanından mola / devam / bitir / küçült. iPhone yön kilidi
(`FokusApp`'teki delegate) yalnızca tam ekranda yatayı açar; iPad her yönde çalışır.

**Sesler (cihazda üretilir, dosya yok)** — `FokusKit/Sources/FokusAudio/Sound/`. Beyaz / pembe /
kahverengi gürültü, yağmur (filtrelenmiş gürültü + rastgele damla darbeleri) ve yumuşak pentatonik
melodi `AVAudioEngine` + `AVAudioSourceNode` ile gerçek zamanlı sentezlenir; indirme, ağ ve telif yoktur.
Saf DSP parçaları (PRNG, biquad katsayıları, gürültü üreteçleri, damla zamanlayıcı, nota eşleme, fade
eğrisi) birim testlidir ve her ses çevrimdışı (manual rendering) render edilip sessiz olmadığı doğrulanır.
`AVAudioSession` `.playback`; arka planda ve kilitliyken çalmaya `UIBackgroundModes: audio` ile devam
eder. "Diğer seslerle karıştır" açıkken (`.mixWithOthers`, varsayılan) Spotify gibi uygulamalarla birlikte
çalar. Arama / Siri kesintisi sesi duraklatır ve kesinti bitince sürdürür; kulaklık çıkarılınca duraklatır
(otomatik sürdürmez). Uyku zamanlayıcısı sesi son saniyelerde yumuşakça kısıp durdurur. Arayüz sözleşmesi
`FocusSoundControlling`; gerçek uygulama `FocusSoundPlayer`.

**Müzik sağlayıcıları (isteğe bağlı)** — `MusicProvider` protokolü `FokusAudio/Music/`'tadır; sağlayıcılar
`MusicProviderRegistry`'ye kaydedilir (kök `FokusApp`, `onOpenURL` ve sahne yaşam döngüsünü iletir).
Spotify uygulaması `Fokus/Features/Focus/Music/` altındadır (SDK uygulama hedefinin bağımlılığıdır;
FokusKit SDK'sızdır). Apple Music için yalnızca uzantı noktası vardır (`MusicProviderID.appleMusic`),
uygulanmadı: yeni sağlayıcı = `MusicProviderID` + `MusicProvider` uygulaması + `FocusMusicProviders`'a kayıt.

### Spotify'ı etkinleştirme (kullanıcının yapacakları)

Spotify entegrasyonu **kapalı gelir**: `SPOTIFY_CLIENT_ID` boşken (ya da Spotify yüklü değilken) ses
sayfasında yalnızca "Spotify'da aç" bağlantısı görünür. Etkinleştirmek için (Spotify Developer
hesabında hiçbir şey otomatik oluşturulmaz; hepsini sen yaparsın):

1. [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard) → **Create app**. Ad/açıklama
   serbest. **Which API/SDKs are you planning to use?** altında **iOS** seç.
2. Uygulama ayarlarında **Redirect URIs** → `fokus://spotify-callback` ekle (birebir; kodda sabittir).
3. **Bundle IDs** → `com.musabustun.fokus` ekle.
4. Uygulama **Development mode**'dayken yalnızca Dashboard'daki **User Management**'a eklediğin
   kullanıcılar (Spotify hesabının e-postasıyla; sınırlı sayıda) bağlanabilir. Herkese açmak Spotify'ın
   kendi "extended quota" incelemesine bağlıdır.
5. Dashboard'daki **Client ID**'yi `ios/Config/Fokus.xcconfig` içindeki `SPOTIFY_CLIENT_ID =` satırına yaz
   (Client Secret'a ihtiyaç yok ve ASLA koda/repoya konmaz). Ardından `xcodegen generate` ve yeniden derle.
6. Cihazda Spotify uygulaması yüklü ve giriş yapılmış olmalı. İlk "Spotify'a bağlan"da Spotify açılıp izin
   ister, sonra Fokus'a döner. Çalmayı denetlemek çoğunlukla **Premium** gerektirir (Premium yoksa Spotify
   komutu reddeder; uygulama bunu Türkçe bir mesajla gösterir).

Simülatörde Spotify uygulaması yoktur; bağlantı akışı yalnızca gerçek cihazda uçtan uca denenebilir
(arayüz/kontroller `-FokusUITestSpotify connected` sahte sağlayıcısıyla UI testlerinde doğrulanır).

## Odak — Live Activity / kilit ekranı kronometresi (plan, uygulanmadı)

Oturum açıkken kilit ekranı ve Dynamic Island'da kronometre göstermek için (yer tutucu; kod yok):

1. **Hedef:** `FokusWidgets` adında yeni bir Widget Extension (`project.yml`'e `app-extension` hedefi); `NSSupportsLiveActivities = YES` (`Info.plist`). Paylaşılan ActivityAttributes tipi FokusKit'e (örn. `FokusDomain/FocusActivityAttributes.swift`, yalnızca değer tipleri) eklenir; böylece uygulama ve eklenti aynı tipi kullanır.
2. **İçerik:** `ActivityAttributes` sabit kısmı: ders etiketi. `ContentState`: `phase` (`focus`/`break`), `phaseStartedAt: Date`, `focusMsBeforePhase: Double` (önceki odak toplamı). Süre sayacı **sistem tarafından** çizilir: `Text(timerInterval: phaseStartedAt...Date.distantFuture, countsDown: false)`; uygulama her saniye güncelleme göndermez.
3. **Yaşam döngüsü:** `FocusRepository.start/pause/resume` sonrası `Activity.request/update`, `finish` sonrası `end` (kayıt sonucu `FocusScreen` değil, ince bir `FocusActivityController` çağırır; ekran kapalıyken de çalışsın diye `AppEnvironment`'ta tutulur). Uygulama açılışında açık oturum varsa etkinlik yeniden bağlanır (`Activity.activities`).
4. **Eylemler:** iOS 17+ `LiveActivityIntent` ile kilit ekranından "Mola ver / Devam et / Bitir"; intent aynı `FocusRepository` üzerinden depoya yazar (App Group + paylaşılan SwiftData deposu gerekir: `ModelConfiguration(groupContainer:)`, CloudKit ile uyumlu olduğu doğrulanmalı).
5. **Tuzaklar:** Push ile güncelleme (APNs) YOK — yalnızca yerel güncelleme (sunucumuz yok); Live Activity 8 saat sonra sistem tarafından sonlandırılır → açılışta yeniden isteme; imzasız simülatör derlemesi için `ActivityKit` izinleri ve App Group yetkisi Apple Developer hesabında kayıt gerektirir (kullanıcı onayıyla).

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
