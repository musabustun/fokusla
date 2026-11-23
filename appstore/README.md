# App Store hazırlığı

Fokus 1.0.0'ın App Store Connect'e girilecek içerikleri. Yalnızca Türkçe (birincil dil `tr`).

| Yol | İçerik |
| --- | --- |
| `metadata/tr/*.txt` | ASC alanlarına birebir kopyalanacak düz metinler (ad, alt başlık, tanıtım metni, açıklama, anahtar kelimeler, yenilikler, inceleme notları, URL'ler, kategori, telif) |
| `metadata/tr/age_rating.md` | Yaş derecelendirmesi anketi için önerilen cevaplar (beklenen 4+) |
| `privacy.md` | App Privacy ("Data Not Collected") gerekçesi + kod tarama bulguları |
| `scripts/check_metadata.py` | Karakter/bayt sınırlarını doğrular: `python3 appstore/scripts/check_metadata.py` |
| `screenshots/iphone-6.3/` | **ASC'de zorunlu** "Dynamic Island (orta ekran)" yuvası: 1206×2622, alfasız PNG (şablon yerel boyutunda render edilir, yeniden örnekleme yok) |
| `screenshots/iphone-6.9/`, `screenshots/ipad-13/` | 6.9" (1320×2868, isteğe bağlı) ve iPad 13" (2064×2752) karuseli, alfasız PNG |
| `screenshots/watch/` | Apple Watch yuvası: 422×514 (Ultra 3, 49 mm), alfasız PNG; simülatör ekran görüntüsü olduğu gibi (`01-baslat`, `02-sayac`) |
| `screenshots/build_screenshots.py`, `screenshots/src/` | Mockup + karusel üretimi (HTML/CSS + headless Chrome; başlıklar `src/*.json`) |
| `scripts/capture_screenshots.sh` | Ham ekran görüntüleri: `StoreScreenshotsUITests` (demo veri: `-FokusUITestMode -FokusDemoData`) |
| `header/`, `search-results/` | ASC "Header" (5244×2950, 3840×1646) ve "Arama sonuçları" (5244×2950, 3840×2560) görselleri; `scripts/build_header.py` |

Gizlilik ve destek sayfaları: [`docs/privacy.md`](../docs/privacy.md), [`docs/support.md`](../docs/support.md).

## Sürüm yapılandırması

- `ios/Config/Fokus.xcconfig`: `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 2` (uygulama ve widget uzantısı aynı değeri kullanır; her ASC yüklemesinde build numarası artırılır).
- `ITSAppUsesNonExemptEncryption = NO` (`ios/Fokus/Info.plist`): yalnızca Apple sistem şifrelemesi.
- `PrivacyInfo.xcprivacy` (uygulama + widget): izleme yok, toplanan veri yok, UserDefaults required-reason beyanı.
- **Sosyal sekmesi Release'te gizli:** `AppSection.isAvailable` (`#if DEBUG`). Kenar çubuğu, Bugün "Diğer" ve Ayarlar "Daha fazla" listeleri bunu kullanır. Debug ve UI testlerinde Sosyal aynen görünür.

## Yükleme öncesi kontrol listesi

1. `python3 appstore/scripts/check_metadata.py`
2. Release arşivi (cihaz imzalı) → ASC; Spotify Client ID `ios/Config/Local.xcconfig`'tedir (git dışı). Boşsa Spotify yalnızca "Spotify'da aç" bağlantısı gösterir.
3. ASC: App Privacy = Veri toplanmıyor; Export Compliance sorusu çıkmaz; Yaş derecelendirmesi `age_rating.md`; kategori `category.txt`.
4. İnceleme notları `review_notes.txt`; demo hesap gerekmez.

## Ekran görüntülerini yeniden üretme

```bash
cd ios && xcodegen generate && cd ..
xcrun simctl create "Fokus Shots 6.9" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-2
xcrun simctl create "Fokus Shots 6.3" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-27-2   # 1206x2622
xcrun simctl create "Fokus Shots iPad 13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-2
appstore/scripts/capture_screenshots.sh iphone <UDID> /tmp/raw/iphone      # 6.9"; 6.3" için: iphone63 <UDID> /tmp/raw/iphone63; ve ipad
python3 appstore/screenshots/build_screenshots.py --raw /tmp/raw --out appstore/screenshots   # iphone-6.9, iphone-6.3 (raw/iphone63 yoksa 6.9" ham görüntülerden), ipad-13
# Apple Watch (simülatör: Apple Watch Ultra 3 49mm, watchOS 27.2; saat saati override edilemez)
#   xcodebuild build -project ios/Fokus.xcodeproj -scheme FokusWatch -destination 'platform=watchOS Simulator,id=<UDID>' -derivedDataPath ios/build/DerivedDataShots CODE_SIGNING_ALLOWED=NO
#   xcrun simctl install <UDID> <...>/Debug-watchsimulator/FokusWatch.app
#   xcrun simctl launch <UDID> com.musabustun.fokus.watchkitapp                           # 01-baslat
#   xcrun simctl launch <UDID> com.musabustun.fokus.watchkitapp -FokusWatchDemoSession    # 02-sayac (23 dk'lık açık oturum, DEBUG)
#   xcrun simctl io <UDID> screenshot 01-baslat.png
python3 appstore/scripts/build_header.py
```

Demo veri yalnızca DEBUG'da ve `-FokusUITestMode` ile birlikte çalışır (bellek içi depo); `-FokusDemoOpenSession` açık bir odak oturumu başlatır. `-FokusDemoData` açıkken Sosyal gizlenir (Release ile aynı görünüm).
