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

## Yeni palet ekleme (2 adım)

Web'de yeni paletin renkleri (`COLORS`) birleştirildikten sonra:

1. **Enum case'i:** `Theme/FokusPalette.swift` içinde `FokusPalette`'e case ekle ve
   `displayName` / `assetFolder` `switch`'lerine birer satır yaz (klasör adı PascalCase, ör. `TekRenk`).
   Raw value web palet kimliğiyle aynı olsun.
2. **Asset klasörü:** `ios/scripts/generate_palette_assets.py` içindeki `PALETTES` sözlüğüne
   web'deki hex değerlerini (light + dark, 21 token) aynen ekle ve çalıştır:
   `python3 ios/scripts/generate_palette_assets.py <Palet>`. Üretilen
   `Colors.xcassets/<Palet>/` dosyalarını commit'le.

Ardından `Tests/FokusDesignTests/FokusDesignTests.swift` içindeki `webColors` tablosuna paletin
hex'lerini ekle: test, her token'ın açık/koyu çözümlenmiş RGBA'sını web ile karşılaştırır. Ayar
ekranı `FokusPalette.allCases` ile listelediği için ek UI işi yoktur. Paletlerin renklerini
uydurma; yalnızca web'deki değerler kullanılır.

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
