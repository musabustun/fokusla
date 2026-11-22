# App Store hazırlığı

Fokus 1.0.0'ın App Store Connect'e girilecek içerikleri. Yalnızca Türkçe (birincil dil `tr`).

| Yol | İçerik |
| --- | --- |
| `metadata/tr/*.txt` | ASC alanlarına birebir kopyalanacak düz metinler (ad, alt başlık, tanıtım metni, açıklama, anahtar kelimeler, yenilikler, inceleme notları, URL'ler, kategori, telif) |
| `metadata/tr/age_rating.md` | Yaş derecelendirmesi anketi için önerilen cevaplar (beklenen 4+) |
| `privacy.md` | App Privacy ("Data Not Collected") gerekçesi + kod tarama bulguları |
| `scripts/check_metadata.py` | Karakter/bayt sınırlarını doğrular: `python3 appstore/scripts/check_metadata.py` |
| `screenshots/` | (Aşama 2) iPhone 6.9" ve iPad 13" mağaza görselleri |

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
