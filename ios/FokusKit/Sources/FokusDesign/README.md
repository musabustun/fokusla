# FokusDesign — SwiftUI tasarım sistemi ("Gece mesaisi")

`web/src/ui/README.md` dosyasının SwiftUI karşılığıdır. Kaynak her zaman `web/src/ui/tokens.ts`:
renk, yazı ölçeği, yarıçap ve hareket değerleri orada değişir, burada **aynen** yansıtılır.
Koyu öncelikli, 1px çizgili (kart yok), tek kehribar vurgulu, büyük mono rakamlı bir dildir.

## Başlangıç

```swift
@main struct FokusApp: App {
    init() { FokusFonts.registerAll() }          // fontları bir kez kaydet (idempotent)
    var body: some Scene {
        WindowGroup { RootView().fokusTheme() }   // palet + görünüm + tint
    }
}
```

`.fokusTheme()` `@AppStorage` içindeki palet (`FokusThemeKeys.palette`) ve görünüm
(`FokusThemeKeys.appearance`: sistem/açık/koyu) tercihini okur, paleti `\.fokusPalette` ortamına yazar.

## Token'lar

- **Renk:** `FokusColorToken` (web `COLOR_TOKENS` ile aynı 21 token). Kullanım:
  `.foregroundStyle(.fkLabel)`, `.background(.fkBackground)`; `Color` gerekirse
  `FokusColor.color(.accent, palette:)`. Asset adı PascalCase (`SecondaryLabel`) ve
  `Colors.xcassets/<Palet>/` klasöründe (namespace) durur; Any = gündüz, Dark = gece.
- **Yazı:** `FokusTextStyle` — `.fokusTextStyle(.largeTitle)`. Boyutlar web ile aynı
  (`display` 44 … `numeralSM` 17), Dynamic Type ile ölçeklenir. Başlıklar Bricolage Grotesque
  (500/800), rakam ve `eyebrow` JetBrains Mono, gövde sistem fontu. Eş genişlikli rakam yalnızca
  `numeral*` stillerinde; `eyebrow` büyük harf ve +0.12em aralıklıdır.
- **Boşluk / yarıçap / hareket:** `FokusSpacing` (4pt ızgara), `FokusRadius`, `FokusMotion`
  (`press` 0.12s, `base` 0.2s, `enter` 0.24s, `sheet` 0.28s, `progress` 0.7s; hazır
  `pressAnimation`, `baseAnimation`, `progressAnimation`, `pressScale` = 0.97).
- **Dokunma hedefi:** `fokusMinTapTarget` = 44pt.

## Bileşenler

| SwiftUI                                                    | Web karşılığı                | Not                                                                   |
| ---------------------------------------------------------- | ---------------------------- | --------------------------------------------------------------------- |
| `.buttonStyle(.fokusPrimary)`                              | `Button` filled              | Kehribar hap; ekranda bir tane. Devre dışıyken %40 opaklık.           |
| `.buttonStyle(.fokusSecondary)`                            | `Button` tinted              | Çizgili hap (`separatorStrong`).                                      |
| `.buttonStyle(.fokusPlain)` / `.fokusDestructive`          | `Button` plain / destructive | Nötr metin eylemi / kırmızı çizgili hap.                              |
| `ScreenHeader(_:eyebrow:subtitle:trailing:)`               | `ScreenHeader`               | iPad genişliğinde (`.regular`) `display` boyutu.                      |
| `LineSection(_:footer:content:)`                           | `ListSection`                | Eyebrow başlık + 1px çizgi; kart yok.                                 |
| `LineRow(_:subtitle:value:accessory:)`, `showsChevron:`    | `ListRow`                    | ≥44pt. `Button`/`NavigationLink` içinde `.buttonStyle(.fokusRow)`.    |
| `ProgressRing(progress:lineWidth:tone:label:)`              | `ProgressRing`               | 700ms akar; hareket azaltmada anında. Boyut `.frame` ile verilir.     |
| `ProgressBar(value:label:tone:size:)`                      | `ProgressBar`                | Yatay çubuk: `.small` 2pt (liste), `.medium` 4pt. `label` varsa VoiceOver okur. 700ms akar. |
| `Metric(label:value:unit:caption:size:tone:isNumeric:)`    | `Metric`                     | Eyebrow etiket + büyük mono rakam. `tone: .accent` ekranda tek.       |
| `EmptyStateView(_:systemImage:message:action:)`            | `EmptyState`                 | `ContentUnavailableView` yerine marka diliyle.                        |

```swift
VStack(alignment: .leading, spacing: FokusSpacing.xl) {
    ScreenHeader("Bugün", eyebrow: "19 Kasım")
    Metric(label: "Bugün", value: "2:45", unit: "sa", size: .hero, tone: .accent)
    LineSection("Dersler") {
        LineRow("Matematik", value: "1:20")
        LineRow("Kitaplar", showsChevron: true)
    }
    Button("Başlat") { start() }.buttonStyle(.fokusPrimary)
}
.padding(.horizontal, FokusSpacing.screenHorizontal)
```

Her bileşen dosyasında koyu ve açık `#Preview` vardır (`Components/`).

## Paletler

Altı palet (web `PALETTE_NAMES` sırasıyla): `coffee` Kahve (varsayılan), `mono` Tek renk,
`strawberry` Çilek, `matcha` Matcha, `blueberry` Yaban mersini, `lemonade` Limonata; her biri
açık (Any) + koyu (Dark). Tercihler web ile aynı anahtarlarda: `@AppStorage("fokus.palette")`,
`@AppStorage("fokus.theme")` (`system`/`light`/`dark`). Seçim için `PalettePicker`.

### Palet ekleme / renk değiştirme

Tek kaynak web `web/src/ui/tokens.ts` (`PALETTES`, `PALETTE_LABELS`, `PALETTE_NAMES`). Renkleri
burada uydurma.

1. Web'de paleti ekle/güncelle (kontrast testleri `tokens.test.ts`'te).
2. `cd web && npm run export:ios-palettes` → `Tests/FokusDesignTests/Fixtures/palettes.web.json`.
3. `python3 ios/scripts/generate_palette_assets.py` → `Resources/Colors.xcassets/<Palet>/`
   (Any/Dark, 21 token; kaynakta olmayan eski klasörler silinir). Üretilenleri commit'le.
4. Yeni paletse `Theme/FokusPalette.swift`'e case + `displayName` satırı ekle (raw value = web adı).
5. Uygulama ikonu palete uyar (`Theme/FokusAppIcon.swift`; `Fokus/App/AppIconSync.swift`
   `setAlternateIconName` çağırır). Yeni palette ya da vurgu rengi değişince
   `scripts/generate_palette_app_icons.py`'deki listeyi güncelle, `python3 ios/scripts/generate_palette_app_icons.py`
   çalıştır ve `project.yml` `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`'e adı ekle
   (`FokusAppIconTests` üçünün eşitliğini denetler).

`FokusDesignTests` sırayı, adları, anahtarları ve her token'ın açık/koyu RGBA'sını JSON'la
karşılaştırır; web tarafında `src/ui/iosPalettes.test.ts` JSON'un güncel olduğunu denetler.

## Kurallar

- **Yalnızca token:** bileşen ve ekranlarda ham renk (`Color(red:)`, `.red`, `Color.black`), ham
  punto (`.font(.system(size:))`) ve sihirli boşluk kullanma. Renk `fk*`, yazı `fokusTextStyle`.
- **≥ 44pt dokunma hedefi** (`fokusMinTapTarget`); kontrast WCAG AA (token seçimi bunu sağlar:
  gündüzde kehribar metin için `accentInk`, `accent` yalnızca dolgu).
- **Hareket azaltma:** `@Environment(\.accessibilityReduceMotion)` açıkken basınç ölçeği ve
  ilerleme animasyonu yoktur; yeni animasyonlar da buna uymalı.
- **Dynamic Type:** özel fontlar `relativeTo:` ile ölçeklenir; sabit yükseklik verme, `minHeight` kullan.
- **Tek vurgu:** ekran başına bir kehribar ana eylem; mor yok.
- **Fontlar:** yalnızca `Resources/Fonts/` içindeki 4 ağırlık (OFL lisansları yanlarında);
  PostScript adları `FokusFonts` sabitleridir.

## StandBy (tam ekran odak) — müzik ve düzenleyici

`Sources/FokusDesign/StandBy/`. Tercih sözleşmesi `StandByPreferences`; veri/ses katmanı bilinmez.

- `NowPlayingInfo` (title, artist, artworkData, isPaused) + `NowPlayingCard`: tam sayfa müzik kartı; geniş
  alanda kapak solda, dar alanda dikey. Kimlikler `immersive.nowPlaying[.title|.artist|.playPause|.next|.previous]`.
- `NowPlayingChip`: köşe çipi (28pt kapak + tek satır başlık + eşitleyici; hareket azaltmada durağan),
  `immersive.nowPlayingChip`.
- `StandByEditorPanel`: düzenleme modunun alt tepsisi (Sayfalar | Yazı | Renk | Zemin). Bağlamaya her seferinde
  yeni `StandByPreferences` yazar. Kimlikler `immersive.editor[.tab.*|.page.*|.clock.*|.accent.*|.tintedDigits|.backdrop.*|.night.*|.nowPlayingChip|.reset|.done]`.
  Saf yardımcılar: `rowOrder(for:)`, `movingEnabled(_:fromOffsets:toOffset:)`.

## StandBy (tam ekran odak)

`StandBy/` tam ekran odak görünümünün yapı taşlarıdır (tercihler: `StandByPreferences`).

- `StandByDigits(text:style:)`: alana sığan, titremeyen (sabit hücre genişlikli) büyük rakamlar;
  `fontSize(text:style:in:)` / `cellWidths(text:style:)` saf ve testlidir. Renk `foregroundStyle`'dan.
- `StandByBackdropView(_:)`: `plain` / `gradient` / `aura` (hareket azaltmada durağan) / `black` zemin.
- `.standByNightTint(_:)`: gece kırmızısı (siyah üstünde soluk tek renk). `StandByNightTint.nightRed`
  ve `Color.black` (OLED zemini), "yalnızca token" kuralının belgelenmiş TEK ham renk istisnalarıdır.
- `StandByAnalogClock(date:showsSecondHand:)`: ince çizgili analog saat; hareket azaltmada
  `showsSecondHand: false` verin.
