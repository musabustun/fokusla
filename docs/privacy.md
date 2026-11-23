# Fokus — Gizlilik Politikası

Son güncelleme: 23 Kasım 2026 · Sürüm: 1.0.0

Fokus, YKS'ye hazırlanan öğrenciler için ücretsiz, reklamsız ve açık kaynaklı (MIT) bir çalışma takip uygulamasıdır. Kısaca: **Fokus senden hiçbir veri toplamaz.** Geliştirici olarak verilerine erişemeyiz, onları sunucuya göndermeyiz, satmayız ve paylaşmayız.

## Hangi veriler var ve nerede duruyor?

Uygulamada girdiğin her şey (odak oturumların, ders/konu ve test sonuçların, kitaplar, görevler, günlük hedefin, tercihlerin) **yalnızca cihazında**, uygulamanın kendi veri deposunda saklanır. Fokus'un kendi sunucusu yoktur ve uygulamada analitik, reklam, izleme ya da çökme raporlama gibi üçüncü taraf bir hizmet yoktur.

## iCloud eşitleme (isteğe bağlı)

Cihazında iCloud'a giriş yapılmışsa ve Ayarlar'da eşitleme kapalı değilse verilerin, **yalnızca senin iCloud hesabına ait özel (private) CloudKit veritabanı** üzerinden iPhone ve iPad cihazların arasında eşitlenir. Bu veritabanı Apple tarafından şifreli saklanır; Fokus geliştiricisi dahil kimse bu verilere erişemez. Eşitlemeyi Ayarlar'dan kapatabilirsin. Verilerin Apple'ın iCloud'unda nasıl işlendiği [Apple'ın gizlilik politikasına](https://www.apple.com/legal/privacy/tr/) tabidir.

## Apple ile Giriş (isteğe bağlı)

Giriş zorunlu değildir; "Şimdilik atla" ile uygulama girişsiz tam çalışır. Apple ile Giriş yaparsan Apple'ın verdiği hesap tanımlayıcısı (ve paylaşmayı seçersen adın) yalnızca cihazında saklanır; Apple ID'nin iptal edilip edilmediğini denetlemek için kullanılır. Hiçbir sunucuya gönderilmez.

## Spotify (isteğe bağlı)

Odak ekranında istersen Spotify'ı bağlayıp çalan müziği denetleyebilirsin. Bu özellik yalnızca cihazındaki Spotify uygulamasıyla konuşur ve çalma kontrolü (oynat/duraklat/sonraki, çalan parçanın adı) için kullanılır. Fokus Spotify hesabının profil bilgilerini, çalma geçmişini ya da kütüphaneni almaz ve saklamaz. Spotify'ın kendi veri işlemesi [Spotify gizlilik politikasına](https://www.spotify.com/tr/legal/privacy-policy/) tabidir. Bağlantıyı istediğin an Spotify'dan veya Fokus'tan kesebilirsin.

## Bildirimler

Günlük hatırlatma ve hedef bildirimleri **yalnızca cihazında yerel olarak** planlanır; bir sunucu veya push servisi kullanılmaz. İzin isteğe bağlıdır ve iOS Ayarları'ndan geri alınabilir.

## Odak sesleri

Beyaz/pembe/kahverengi gürültü, yağmur ve melodi sesleri cihazında üretilir; indirme veya ağ erişimi gerektirmez. Mikrofon, kamera, konum, kişiler veya fotoğraflarına erişmeyiz.

## Widget'lar, Live Activity ve Siri/Kestirmeler

Widget'lar ve Live Activity (Dynamic Island) aynı cihazdaki uygulama verisini gösterir; veri cihazdan çıkmaz. Siri ve Kestirmeler komutları da cihaz üzerinde çalışır.

## Verilerini yönetme

- **Dışa aktar:** Ayarlar → Veri → "Verileri dışa aktar" ile tüm verini JSON dosyası olarak alabilirsin. Dosya yalnızca cihazında oluşturulur; nereye paylaşacağını sen seçersin.
- **Sil:** Ayarlar → Veri → "Tüm verileri sil" ile uygulamadaki tüm verini silebilirsin (iCloud eşitleme açıksa silme senin diğer cihazlarına da yansır). Uygulamayı kaldırmak yerel verileri siler.

## Çocuklar

Fokus kişisel veri toplamadığı için çocuklardan veri toplamaz. Hesap oluşturmak zorunlu değildir.

## Değişiklikler

Politika değişirse bu sayfa güncellenir ve üstteki tarih değişir. Uygulamanın kaynak kodu herkese açıktır; yaptığımız söylenenleri kodda doğrulayabilirsin: [github.com/musabustun/fokusla](https://github.com/musabustun/fokusla).

## İletişim

Sorular için GitHub'da [issue aç](https://github.com/musabustun/fokusla/issues) (ayrıntı: [Destek](support.md)).

Geliştirici: Musab Yusuf Üstün
