# Fokus — Gizlilik Politikası

Son güncelleme: 24 Kasım 2026 · Sürüm: 1.0.2

Fokus, YKS'ye hazırlanan öğrenciler için ücretsiz, reklamsız ve açık kaynaklı (MIT) bir çalışma takip uygulamasıdır. Kısaca: çalışma verilerin **senindir**; onlara erişemeyiz, satmayız, reklam ya da izleme için kullanmayız. Cihazından dışarı yalnızca senin açtığın özellikler (iCloud eşitleme, Sosyal, Spotify, iMessage) için aşağıda yazanlar çıkar.

## Hangi veriler var ve nerede duruyor?

Uygulamada girdiğin her şey (odak oturumların, ders/konu ve test sonuçların, kitaplar, görevler, günlük hedefin, tercihlerin) **yalnızca cihazında**, uygulamanın kendi veri deposunda saklanır. Fokus'un kendi sunucusu yoktur ve uygulamada analitik, reklam, izleme ya da çökme raporlama gibi üçüncü taraf bir hizmet yoktur.

## iCloud eşitleme (isteğe bağlı)

Cihazında iCloud'a giriş yapılmışsa ve Ayarlar'da eşitleme kapalı değilse verilerin, **yalnızca senin iCloud hesabına ait özel (private) CloudKit veritabanı** üzerinden iPhone ve iPad cihazların arasında eşitlenir. Bu veritabanı Apple tarafından şifreli saklanır; Fokus geliştiricisi dahil kimse bu verilere erişemez. Eşitlemeyi Ayarlar'dan kapatabilirsin. Verilerin Apple'ın iCloud'unda nasıl işlendiği [Apple'ın gizlilik politikasına](https://www.apple.com/legal/privacy/tr/) tabidir.

## Apple ile Giriş (isteğe bağlı)

Giriş zorunlu değildir; "Şimdilik atla" ile uygulama girişsiz tam çalışır. Apple ile Giriş yaparsan Apple'ın verdiği hesap tanımlayıcısı (ve paylaşmayı seçersen adın) yalnızca cihazında saklanır; Apple ID'nin iptal edilip edilmediğini denetlemek için kullanılır. Hiçbir sunucuya gönderilmez. (Sosyal'i kullanırsan aşağıdaki bölüm geçerlidir.)

## Sosyal (isteğe bağlı)

Sosyal'i kullanmazsan bu bölümdeki hiçbir şey gerçekleşmez. Kullanmak için Apple ile Giriş ve cihazında iCloud gerekir; eşleşme yalnızca Apple'ın CloudKit'i üzerinden yapılır, bizim bir sunucumuz yoktur.

- **Kim ne görür:** Yalnızca kabul ettiğin arkadaşların ve girdiğin odadaki kişiler kullanıcı adını, odakta/molada olup olmadığını, oturum süreni, bugünkü toplam çalışma süreni ve (ev sahibiysen) açık odanı görür. Ders, konu, test, kitap ve görevlerin, gerçek adın ve e-postan Fokus tarafından **asla** paylaşılmaz.
- **Nerede durur:** Arkadaşlık ve oda bilgileri, daveti açan kişinin kendi iCloud alanında durur ve yalnızca katılanlarla paylaşılır; geliştirici erişemez.
- **Kullanıcı adı:** Kimse adları arayamaz ya da listeleyemez. Uygulamanın ortak CloudKit alanında kullanıcı adının yalnızca özeti (hash), bir şifreleme anahtarı, rastgele bir posta kutusu numarası ve Apple'ın uygulamaya özel hesap tanımlayıcısı tutulur; amaç yalnızca sana istek ulaştırabilmektir. İsteklerin içeriği uçtan uca şifrelidir; yalnız alıcı açabilir.
- **iCloud adın:** Davet bağlantısını açan kişiye iOS'un kendi davet ekranı, daveti oluşturan kişinin iCloud adını gösterebilir. Bağlantını yalnızca tanıdıklarınla paylaş.
- **Denetim sende:** "Sosyalde görün"ü kapatınca durumun paylaşılmaz ve adına istek gelmez. Arkadaşlıktan çıkabilir, birini engelleyebilir, odadan ayrılabilirsin. "Sosyal profilimi sil" kullanıcı adını, isteklerini, arkadaşlıklarını ve odanı kalıcı olarak siler.

## Spotify (isteğe bağlı)

Odak ekranında istersen Spotify'ı bağlayıp çalan müziği denetleyebilirsin. Bu özellik çalmayı cihazındaki Spotify uygulaması üzerinden denetler ve yalnızca çalma kontrolü (oynat/duraklat/sonraki, çalan parçanın adı) için kullanılır. Fokus Spotify hesabının profil bilgilerini, çalma geçmişini ya da kütüphaneni almaz ve saklamaz.

İlk bağlanışta Spotify uygulamasına geçilir ve Spotify kendi izin ekranını gösterir (yalnızca "uygulamadan çalmayı denetleme" izni istenir; şifren Fokus'a gelmez). Her saat yeniden izin istememek için Spotify'ın verdiği erişim ve yenileme anahtarları **yalnızca cihazının Keychain'inde** saklanır (iCloud'a ve yedeğe girmez). Fokus bu anahtarları yalnızca Spotify'ın hesap sunucusuna (`accounts.spotify.com`) göndererek yeniler; iCloud dışında Fokus'un kendi yaptığı tek ağ isteği budur ve Spotify'ı bağlamadıysan hiç yapılmaz. Bizim bir sunucumuz yoktur. "Bağlantıyı kes" anahtarları cihazdan siler; Spotify'daki uygulama erişimini Spotify hesap ayarlarından kaldırabilirsin. Spotify'ın kendi veri işlemesi [Spotify gizlilik politikasına](https://www.spotify.com/tr/legal/privacy-policy/) tabidir. Bağlantıyı istediğin an Spotify'dan veya Fokus'tan kesebilirsin.

## iMessage uygulaması (isteğe bağlı)

Fokus'un Mesajlar (iMessage) uzantısı, istersen "bugün şu kadar çalıştım" kartını ya da ortak odak davetini bir sohbete göndermeni sağlar. Uzantı verini cihazındaki Fokus deposundan **yalnızca okur**. Kart ya da davet, **sen Mesajlar'da gönder düğmesine bastığında** yalnızca o sohbete, Apple'ın iMessage'ı üzerinden gider; ondan önce hiçbir şey cihazdan çıkmaz ve Fokus'un kendi sunucusu yoktur. Kartta yalnızca senin seçtiğin alanlar (toplam süre, hedef durumu, isteğe bağlı ders dağılımı ve seri) ile profil adın bulunur. Oda davetinde ortak odanın saati, süresi ve katılanların adları mesajın içinde taşınır; katılan herkesin uygulaması o mesajı kendi cihazında açar. Bu bilgiler sohbetin diğer üyelerine görünür; göndermeden önce kartı önizleyip neyin gideceğini görürsün.

## Apple Watch uygulaması (isteğe bağlı)

Saatteki Fokus verisini saatin kendi deposunda tutar; saat iCloud eşitlemesi yapmaz. Odak kayıtların ile tema, hedef ve ders adı gibi tercihlerin yalnızca eşleştirilmiş saatinle iPhone'un arasında, Apple'ın WatchConnectivity bağlantısı üzerinden eşlenir; bizim bir sunucumuza uğramaz. Sağlık (HealthKit) verisine erişilmez.

## Bildirimler

Günlük hatırlatma ve hedef bildirimleri **yalnızca cihazında yerel olarak** planlanır; bir sunucu veya push servisi kullanılmaz. İzin isteğe bağlıdır ve iOS Ayarları'ndan geri alınabilir.

## Odak sesleri

Beyaz/pembe/kahverengi gürültü, yağmur ve melodi sesleri cihazında üretilir; indirme veya ağ erişimi gerektirmez. Mikrofon, konum, kişiler veya fotoğraflarına erişmeyiz. Kamera yalnızca bir kitabın barkodunu okutmak istediğinde, izninle açılır; görüntü cihazında işlenir, kaydedilmez ve hiçbir yere gönderilmez.

## Widget'lar, Live Activity ve Siri/Kestirmeler

Widget'lar ve Live Activity (Dynamic Island) aynı cihazdaki uygulama verisini gösterir; veri cihazdan çıkmaz. Siri ve Kestirmeler komutları da cihaz üzerinde çalışır.

## Verilerini yönetme

- **Dışa aktar:** Ayarlar → Veri → "Verileri dışa aktar" ile tüm verini JSON dosyası olarak alabilirsin. Dosya yalnızca cihazında oluşturulur; nereye paylaşacağını sen seçersin.
- **Sil:** Ayarlar → Veri → "Tüm verileri sil" ile uygulamadaki tüm verini (Sosyal profilin dahil) silebilirsin (iCloud eşitleme açıksa silme senin diğer cihazlarına da yansır). Uygulamayı kaldırmak yerel verileri siler.

## Çocuklar

Hesap oluşturmak zorunlu değildir; Sosyal'i kullanmayan hiç kimseden veri alınmaz. Sosyal'de arama, keşfet ya da mesajlaşma yoktur; kimse kabul etmediğin sürece seni göremez. Kullanıcı adında gerçek adını ya da okulunu kullanma.

## Değişiklikler

Politika değişirse bu sayfa güncellenir ve üstteki tarih değişir. Uygulamanın kaynak kodu herkese açıktır; yaptığımız söylenenleri kodda doğrulayabilirsin: [github.com/musabustun/fokusla](https://github.com/musabustun/fokusla).

## İletişim

Sorular için GitHub'da [issue aç](https://github.com/musabustun/fokusla/issues) (ayrıntı: [Destek](support.md)).

Geliştirici: Musab Yusuf Üstün
