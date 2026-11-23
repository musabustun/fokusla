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
5. Dashboard'daki **Client ID**'yi git dışı `ios/Config/Local.xcconfig` dosyasına yaz
   (`SPOTIFY_CLIENT_ID = <client id>`; `Fokus.xcconfig` bu dosyayı varsa `#include?` ile okur, `.gitignore`'dadır).
   Public repodaki `Fokus.xcconfig`'te değer boş kalır. Client Secret'a ihtiyaç yok (App Remote, Spotify
   uygulaması üzerinden yetkilendirir; token swap sunucumuz yok) ve ASLA koda/repoya/uygulamaya konmaz.
   Ardından `xcodegen generate` ve yeniden derle.
6. Cihazda Spotify uygulaması yüklü ve giriş yapılmış olmalı. İlk "Spotify'a bağlan"da Spotify açılıp izin
   ister, sonra Fokus'a döner. Çalmayı denetlemek çoğunlukla **Premium** gerektirir (Premium yoksa Spotify
   komutu reddeder; uygulama bunu Türkçe bir mesajla gösterir).

Simülatörde Spotify uygulaması yoktur; bağlantı akışı yalnızca gerçek cihazda uçtan uca denenebilir
(arayüz/kontroller `-FokusUITestSpotify connected` sahte sağlayıcısıyla UI testlerinde doğrulanır).

## Sistem entegrasyonları: Live Activity, widget'lar, Siri/Kestirmeler, Odak filtresi

Kod yerleşimi: `ios/Shared/` (uygulama VE widget hedefine derlenir: `FocusLiveActivity` = `ActivityAttributes` +
eşitleme, `FokusIntents`, `FocusActions`, `FokusSystemStore`), `ios/FokusWidgets/` (uzantı: widget'lar +
Live Activity arayüzü), `ios/Fokus/App/` (`FocusSystemCoordinator`, `FokusShortcuts`, `FocusFilter`).
Saf mantık FokusDomain'dedir ve test edilir: `FocusActivityCalc`, `WidgetCalc`, `SystemDialogs`.

- **Live Activity / Dynamic Island:** süre saklanmaz; `Text(timerInterval:)` ile sistem sayar. Odakta sayaç oturumun
  toplam odak süresini (mola hariç), molada açık mola segmentini gösterir; mola/devam yeni segment açtığı için
  etkinlik her geçişte güncellenir. `FocusSystemCoordinator` açık oturumu etkinlikle eşitler (uygulama öne gelince
  ve veri kaydedilince); Mola ver/Devam et ve Bitir `LiveActivityIntent`'tir (uygulama sürecinde çalışır).
  Push güncellemesi YOK; sistem 8 saat sonra etkinliği sonlandırır, uygulama açılınca yeniden başlatılır.
- **Widget'lar:** Bugünkü odak + hedef halkası (small/medium, kilit ekranı circular/rectangular/inline) ve bugünkü
  görevler (medium/large, daire düğmesi `ToggleTaskIntent` ile görevi widget'tan tamamlar). Veri App Group'taki
  SwiftData deposundan okunur; uygulama veri değişince `WidgetCenter.reloadAllTimelines()` çağırır. Odak sürerken
  sayaç sistemce sayılır, halka 5 dk aralıklı girdilerle ilerler. Palet: widget uzantısı varsayılan paleti kullanır.
- **App Group deposu:** `group.com.musabustun.fokus`. Depo (`Fokus.store` + `-wal` + `-shm`) ilk açılışta eski
  konumdan App Group kapsayıcısına TAŞINIR (`FokusAppGroup.migrateLegacyStoreIfNeeded`: önce kopyalar, başarılıysa
  eskiyi siler; hedef varsa ezmez; hata olursa eski depoyu olduğu gibi bırakır). CloudKit yapılandırması aynı kalır.
  Uzantı depoyu CloudKit'siz açar ve ASLA boş depo oluşturmaz (dosya yoksa "Fokus'u bir kez aç" gösterir).
  Yetki yoksa (imzasız simülatör derlemesi) varsayılan konum kullanılır: davranış eskisi gibi.
- **Siri ve Kestirmeler:** "Odak başlat" (ders opsiyonel, `SubjectEntity`), "Odağı bitir", "Bugün ne kadar çalıştım?",
  "Görev ekle"; Türkçe ifadeler `FokusShortcuts`'ta. "Odak başlat" uygulamayı açar (Live Activity yalnızca ön plandan başlar).
- **Odak filtresi** (`FokusFocusFilter`, Ayarlar → Odak → Odak filtreleri → Fokus): "Hatırlatmaları sustur" ve
  "Odak sesi". Sade: ayarlar App Group `UserDefaults`'ında tutulur; hatırlatmalar susturulur, yeni oturumda seçili
  ses çalar. Tam ekran odak zaten oturumla birlikte otomatik açılır.

### Hesapta yapılacaklar (kullanıcı onayıyla; bu PR hesapta HİÇBİR ŞEY kaydetmez)

1. **App Group** `group.com.musabustun.fokus` oluştur.
2. **App ID** `com.musabustun.fokus` → App Groups yeteneği ekle ve bu gruba bağla.
3. **Yeni App ID** `com.musabustun.fokus.widgets` (widget uzantısı) → App Groups yeteneği, aynı grup.
4. Xcode otomatik imzalamayla iki hedef için profil üretilir (ya da bir kez `-allowProvisioningUpdates`).
5. Live Activity için ek yetenek gerekmez (`NSSupportsLiveActivities` Info.plist'te); Siri/Kestirmeler ve Odak filtresi
   için de ek kayıt gerekmez.
6. Cihazda doğrula: depo taşıması (mevcut veri yerinde mi), widget'ın veriyi görmesi, widget'tan görev işaretleme
   (uzantı CloudKit'siz açtığı depoya yazar; uygulama öne gelince değişiklik CloudKit'e akar — gerçek cihazda
   doğrulanmalı), Live Activity düğmeleri, Odak filtresi.

## Cihazda çalıştırma (Apple tarafı)

Simülatör derlemesi imzasızdır (`CODE_SIGNING_ALLOWED=NO`); CloudKit ve Apple ile Giriş orada
çalışmaz (uygulama `.local` depoya düşer; giriş adımı hata mesajı gösterir, "Şimdilik atla" çalışır).
Gerçek cihaz için takım `395SFU52ZD` hesabında bir kez:

1. **App ID** `com.musabustun.fokus` — yetenekler: iCloud (CloudKit), Sign in with Apple, Push Notifications.
2. **iCloud kapsayıcısı** `iCloud.com.musabustun.fokus` oluştur ve App ID'ye bağla.
3. Xcode'da otomatik imzalama (ya da bir kez `xcodebuild -allowProvisioningUpdates`) ile geliştirme
   profili üretilir; cihaz takıma kayıtlı olmalı.
4. CloudKit Development şemasını başlat ve Production'a deploy et: aşağıdaki
   "CloudKit şemasını Production'a hazırlama" bölümü.
5. TestFlight/App Store öncesi `aps-environment` → `production` (Release imzası bunu otomatik yapar).

## CloudKit şemasını Production'a hazırlama

SwiftData bir kayıt tipini (`CD_<Model>`) yalnızca o tipten veri yazıldıkça Development ortamında oluşturur;
bu yüzden Console'da yalnızca kullanılmış tipler görünür ve olduğu gibi Production'a deploy edilirse şema
eksik kalır. DEBUG derlemesi, `FokusSchemaV1.models` içindeki TÜM modellerin kayıt tiplerini ve alanlarını
oluşturan tek seferlik bir yol içerir (`FokusCloudKitSchemaInitializer`, Apple'ın
`NSPersistentCloudKitContainer.initializeCloudKitSchema` yolu). Release derlemesinde bu kod yoktur.

1. **Debug derlemeyi cihaza kur** (iCloud'a girişli gerçek cihaz; simülatörde CloudKit yok):
   `xcodebuild build -project Fokus.xcodeproj -scheme Fokus -configuration Debug -destination 'id=<UDID>' -allowProvisioningUpdates`
   ve `xcrun devicectl device install app --device <UDID> <Fokus.app yolu>` (ya da Xcode'dan Run).
2. **Argümanla çalıştır:**

   ```bash
   xcrun devicectl device process launch --device <UDID> com.musabustun.fokus -- -FokusInitCloudKitSchema
   ```

   Uygulama normal açılır; şema başlatma arka planda sürer (ağ; ~10–60 sn). Sonucu `Logger` yazar
   (subsystem `com.musabustun.fokus`, category `cloudkit-schema`): başarıda
   `CloudKit şeması başlatıldı: 12 kayıt tipi — …`, hatada `CloudKit şeması başlatılamadı: …`. Cihaz
   günlüğü için Xcode → Devices and Simulators → Open Console, ya da `--console` bayrağını ekle.
   Gerçek `Fokus.store`'a dokunmaz: geçici ayrı bir depo kullanır ve siler. Development'a örnek kayıtlar
   yazılıp silinir (normal).
3. **Doğrula:** [CloudKit Console](https://icloud.developer.apple.com/dashboard) → `iCloud.com.musabustun.fokus`
   → **Development** → Schema → Record Types: 12 tipin hepsi (`CD_UserProfile`, `CD_Subject`, `CD_Topic`, `CD_Book`,
   `CD_BookProgress`, `CD_TestResult`, `CD_FocusSession`, `CD_FocusSegment`, `CD_StudyTask`, `CD_TaskCompletion`,
   `CD_Friend`, `CD_Room`) ve alanları görünmeli.
4. **Production'a gönder:** Console'da **Deploy Schema Changes…** → onayla. Sonra Production ortamında tipleri
   yeniden kontrol et.

**Şema yalnızca büyür:** Production'a deploy edilen kayıt tipi/alan silinemez ve yeniden adlandırılamaz.
Yeni alan/model eklediğinde (opsiyonel/varsayılanlı) adımları tekrarla ve yeniden deploy et; deploy etmeden
önce Development şemasını gözden geçir. Argüman tekrar çalıştırılırsa zararsızdır (idempotent).
