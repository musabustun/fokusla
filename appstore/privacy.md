# App Privacy — gerekçe ve App Store Connect cevapları

> **Sosyal (CloudKit) ile yayınlanan ilk sürümden itibaren** cevap değişir: **"User ID" — App Functionality, kullanıcıya bağlı, izleme yok.** Aşağıdaki "Data Not Collected" gerekçesi Sosyal'in gizli olduğu sürümler (1.0.x) içindir. Bkz. "Sosyal" bölümü.

**Cevap (Sosyal'siz sürümler): "Data Not Collected" (Veri Toplanmıyor).** App Store Connect → Uygulama Gizliliği → "Veri toplamıyoruz". Tracking: **Hayır**.

Apple'a göre "toplamak", verinin cihazdan çıkıp geliştiricinin (ya da üçüncü taraf ortağın) erişebileceği biçimde iletilmesidir. Aşağıdaki kod taraması bunun olmadığını gösterir (23 Kasım 2026, `main` @ ee283eb).

## Kod taraması bulguları

| Konu | Bulgu |
| --- | --- |
| Ağ kodu | `URLSession`, `URLRequest`, `WKWebView`, soket kullanımı **yok** (`ios/Fokus`, `ios/Shared`, `ios/FokusWidgets`, `ios/FokusKit/Sources`). Dış HTTP(S) çağrısı yok; yalnızca `Link(destination:)` ile GitHub/Spotify bağlantıları sistemde açılır. |
| Analitik / izleme / reklam / çökme raporu SDK'sı | **Yok.** Üçüncü taraf bağımlılık yalnızca `SpotifyiOS` (aşağıda). `project.yml` `packages:` → `FokusKit` (yerel) + `SpotifyiOS`. |
| Kimlik | IDFA / `ASIdentifierManager` / `AppTrackingTransparency` yok → `NSUserTrackingUsageDescription` gerekmez. |
| Cihaz izinleri | Mikrofon, kamera, konum, kişiler, fotoğraflar, Bluetooth izni **yok** (`Info.plist`'te `NS*UsageDescription` yok). Yalnızca yerel bildirim izni (çalışma anında istenir). |
| Veri deposu | SwiftData (cihaz). CloudKit yapılandırması yalnızca `.private("iCloud.com.musabustun.fokus")` — kullanıcının kendi özel veritabanı; geliştirici (public/shared DB yok) erişemez. |
| Apple ile Giriş | `AppleAuthService`: `credential.user` ve (varsa) `fullName` yalnızca profildeki `appleUserId`/`displayName` alanlarına yerel yazılır; sunucuya gönderilmez. |
| Spotify | `SpotifyMusicProvider`: Spotify iOS App Remote; cihazdaki Spotify uygulamasıyla konuşur. Erişim belirteci yalnızca bellekte tutulur, çalma kontrolü için kullanılır; profil/geçmiş/kitaplık verisi okunmaz. `SPOTIFY_CLIENT_ID` boşken entegrasyon kapalıdır. |
| Şifreleme | Yalnızca Apple sistem şifrelemesi (CloudKit/HTTPS). `CryptoKit` yalnızca `Identifiers.swift`'te UUID v5 için SHA-1 özeti (şifreleme değil). `ITSAppUsesNonExemptEncryption = NO`. |
| Bildirimler | Yalnızca yerel (`UNUserNotificationCenter`); `remote-notification` arka plan modu CloudKit sessiz bildirimi içindir, push sunucumuz yok. |
| Odak sesleri | AVAudioEngine ile cihazda sentez; dosya/ağ yok. |
| Gizlilik manifesti | `ios/Fokus/Resources/PrivacyInfo.xcprivacy`: izleme yok, toplanan veri türü yok, required-reason API: UserDefaults (`CA92.1` uygulamanın kendi tercihleri, `1C8F.1` App Group). `ios/FokusWidgets/PrivacyInfo.xcprivacy`: boş beyan. |

## Sosyal (CloudKit)

| Konu | Bulgu |
| --- | --- |
| Arkadaşlık, oda, odak durumu | Kullanıcıların private veritabanında, `CKShare` ile yalnız katılanlara açık; geliştirici erişemez → "collected" değildir. |
| Kullanıcı adı dizini (public) | `SocialClaim`: adın SHA-256 özeti, açık anahtar, rastgele posta kutusu; kaydı oluşturanın uygulamaya özel CloudKit kullanıcı kimliği. Geliştirici Console'dan görebilir → **Identifiers › User ID, App Functionality, Linked: Yes, Tracking: No**. |
| İstekler (public) | `SocialMail`: HPKE ile şifreli; geliştirici içeriği açamaz. |
| Manifest | `ios/Fokus/Resources/PrivacyInfo.xcprivacy` → `NSPrivacyCollectedDataTypeUserID`. |
| Hesap silme (5.1.1(v)) | Sosyal → "Sosyal profilimi sil"; Ayarlar → "Hesabı sil" / "Tüm verileri sil" de siler. |
| Kullanıcı içeriği (1.2) | Serbest metin yalnız kullanıcı adı ve oda adı (süzgeçli); arama/keşif/mesaj yok; engelle ve bildir var. |
| Şifreleme | Yalnızca Apple CryptoKit (HPKE) → `ITSAppUsesNonExemptEncryption = NO` yükleyen tarafından yeniden değerlendirilir. |

## iMessage uzantısı (1.1)

`ios/FokusMessages` (Messages app extension, `com.musabustun.fokus.messages`) verilerin yalnızca kullanıcının kendi eylemiyle, kendi sohbetinde paylaşıldığı bir yoldur; **"Data Not Collected" beyanı değişmez.**

| Konu | Bulgu |
| --- | --- |
| Ağ kodu | Uzantıda `URLSession`/soket yok. Mesaj, `MSConversation.insert` ile Mesajlar'ın yazı alanına konur; **gönderme kullanıcının dokunuşuyla** ve Apple'ın iMessage'ı üzerinden olur. Geliştirici bu mesajlara erişemez. |
| Sunucu | Yok. Oda durumu (kimlik, saat, süre, takma adlar) mesajın bağlantısında (`fokus://room?…`) taşınır; `MSSession` ile aynı mesaj güncellenir. |
| Veri erişimi | Uzantı App Group deposunu yalnızca okur (yazmaz). Cihaz başına rastgele bir katılımcı kimliğini App Group `UserDefaults`'a yazar (hesap/kişi bilgisi içermez). |
| Paylaşılan veri | Yalnızca kullanıcının kartta seçtiği alanlar: toplam süre, hedef, isteğe bağlı ders adları + süreleri ve seri; profil adı. Kullanıcı göndermeden önce kartı önizler. |
| Gizlilik manifesti | `ios/FokusMessages/PrivacyInfo.xcprivacy`: izleme yok, toplanan veri yok, required-reason API: UserDefaults (`CA92.1`, `1C8F.1`). |

## Dikkat: Spotify (üçüncü taraf SDK)

Apple, uygulamaya gömülü üçüncü taraf kodun topladığı veriyi de beyan etmeni ister. Spotify App Remote, verileri Spotify uygulamasına yerel olarak iletir ve Fokus Spotify'a bir profil/kimlik verisi göndermez; bu nedenle "Data Not Collected" makul ve dürüst bir beyandır. Spotify SDK'sı ayrıca kendi `PrivacyInfo.xcprivacy`'sini paketleyebilir; yükleme sonrası App Store Connect uyarı e-postası gelirse önce onu kontrol et. Bu karar nihai olarak yükleyen kişiye aittir: Spotify tarafında bir toplama olduğuna dair kanıt çıkarsa "Usage Data / Diagnostics → Not linked, not used for tracking" gibi beyan eklenmelidir.

## Beyan özeti (ASC'ye işlenecek)

- Veri toplama: **Hayır, veri toplamıyoruz.**
- Tracking: **Hayır.**
- Gizlilik politikası URL'si: `https://github.com/musabustun/fokusla/blob/main/docs/privacy.md`
- Gizlilik politikası metni: [`docs/privacy.md`](../docs/privacy.md).
- Dışa aktarma uyumu (ASC "Export Compliance"): Standart şifreleme dışında yok → `ITSAppUsesNonExemptEncryption = NO` (Info.plist'te var; ASC'de soru çıkmaz).
- Hesap silme zorunluluğu (5.1.1(v)): Hesap oluşturma yok (Apple ile Giriş yalnızca yerel tanımlayıcı); "Tüm verileri sil" Ayarlar'da mevcut.
