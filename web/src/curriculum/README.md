# YKS müfredat kataloğu

Bu klasör, Fokus'un ilk açılışta kullanıcıya önerdiği ders ve konu listesini içerir.
Katalog saf veridir; veri katmanı onu kullanıcının veritabanına `catalogKey` alanıyla
eşleştirerek tohumlar.

## Dosyalar

| Dosya          | İçerik                                                                    |
| -------------- | ------------------------------------------------------------------------- |
| `data/tyt.ts`  | TYT dersleri ve konuları (tüm alanlar)                                    |
| `data/ayt.ts`  | AYT dersleri ve konuları (SAY, EA, SÖZ)                                   |
| `data/ydt.ts`  | YDT (Yabancı Dil Testi) soru tipleri (DİL)                                |
| `structure.ts` | ÖSYM'nin resmî test yapısı ve soru sayıları (hangi ders hangi testte)     |
| `yks.ts`       | Kataloğu birleştirir; sınav yılı, kaynaklar ve doğrulama tarihi buradadır |
| `helpers.ts`   | Alan adları/açıklamaları, `subjectsForField`, `findSubject`               |
| `yks.test.ts`  | Kataloğun tutarlılık testleri                                             |

## Kaynaklar

- **Soru sayıları ve puan türleri:** ÖSYM 2026-YKS Kılavuzu (Tablo 1A, 1B, 1E).
- **Konular:** ÖSYM, soruların MEB'in "Ortak Derslere Ait Kazanım ve Açıklamalar" belgesine
  dayandığını söyler. Buradaki konu listeleri o belgedeki ünitelerden ve yaygın "YKS konuları"
  listelerinden **türetilmiştir**; resmî bir ÖSYM listesi değildir. Düzenlenebilir bir
  başlangıç noktasıdır.

Tam bağlantılar `yks.ts` içindeki `sources` alanındadır.

## Güvenli düzenleme kuralları

Anahtarlar (`key`) kullanıcı verisini kataloğa bağlar: kullanıcının dersleri ve konuları
`catalogKey` alanında bu anahtarları saklar. Bu yüzden:

1. **Bir anahtarı asla yeniden adlandırma.** Yazım hatası olsa bile değiştirme; eski
   kullanıcıların kayıtları kopar.
2. **Bir anahtarı asla silme.** Konu artık müfredatta yoksa önce ekiple konuş; kayıtlı
   kullanıcı verisi o anahtara bağlı olabilir.
3. **Adı (`name`) değiştirmek serbesttir.** Yazım düzeltmesi, Türkçe karakter düzeltmesi vb.
   anahtara dokunmadan yapılabilir.
4. **Yeni konu eklemek için yeni bir anahtar kullan.** Konuyu ilgili dersin listesine,
   öğretim sırasına uygun yere `['yeni-konu-slug', 'Yeni Konu Adı']` olarak ekle.
5. **Anahtar biçimi:** yalnızca küçük ASCII harf, rakam ve tire (`kebab-case`). Türkçe
   karakterleri sadeleştir: ç→c, ğ→g, ı→i, ö→o, ş→s, ü→u. Konunun tam anahtarı
   otomatik olarak `<ders-anahtarı>.<konu-slug>` olur (ör. `tyt-matematik.temel-kavramlar`).
6. **Yeni ders eklerken** `structure.ts` içinde onu doğru ÖSYM testine de ekle; testler
   her dersin tam olarak bir teste ait olmasını bekler.
7. **Kaynakları güncelle.** Yeni yılın ÖSYM kılavuzunu veya MEB belgesini kontrol ettiğinde
   `yks.ts` içindeki `examYear`, `sources` ve `verifiedAt` (YYYY-AA-GG) alanlarını güncelle.

Değişiklikten sonra kontrol et:

```bash
npx vitest run src/curriculum
npx eslint src/curriculum --max-warnings=0
npx prettier --write src/curriculum
```

## Bilinen sınırlamalar

- ÖSYM Temel Matematik (TYT) ve Matematik (AYT) testlerini matematik/geometri olarak
  ayırmaz. Öğrenciler ayrı takip ettiği için katalogda iki ders vardır; resmî bir bölünme
  olmadığından bu derslerin `questionCount` değeri `null`, testin toplamı `structure.ts`'tedir.
- AYT Tarih-2 soruları Tarih-1 konularını da kapsayabilir. Ortak konular tekrar edilmesin diye
  Tarih-1 dersinde takip edilir; Tarih-2 yalnızca SÖZ'e özgü çağdaş tarih konularını içerir.
- Din Kültürü ve Ahlak Bilgisi dersinden muaf adaylar, bu sorular yerine ilave Felsefe
  (TYT, 5 soru) / Felsefe Grubu (AYT, 6 soru) soruları çözer.
