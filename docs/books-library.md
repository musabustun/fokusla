# Barkodla kitap ekleme ve kitap kütüphanesi

Durum: Aşama 1 geliştiriliyor (hedef 1.0.1). Karar tarihi: 2026-11-22.
İlgili: [ARCHITECTURE.md](ARCHITECTURE.md) 4.3 (eşleme tablosu), 4.7 (public DB gizliliği), [../CLAUDE.md](../CLAUDE.md) "Değişmez kurallar".

## Amaç

Öğrenci kitabını barkodunu okutarak eklesin; kitabın adı, yayınevi, dersi, türü, toplam sayfa/test sayısı ve **bölüm listesi** (ör. "Türev — Test 1–12", müfredat konusuna bağlı) hazır gelsin. Bir kütüphanede olmayan kitabı ekleyen kullanıcı, isterse onu başkalarının da kullanabileceği ortak kütüphaneye önersin.

## Kararlar

| Konu | Karar |
| --- | --- |
| Kütüphane kaynağı | **Karışım:** uygulamaya gömülü, repoda yönetilen katalog (güvenilir çekirdek) + CloudKit **public database**'e kullanıcı önerileri (Aşama 2). |
| Kayıt içeriği | Temel bilgiler + bölüm listesi. Cevap anahtarı ve kapak görseli **yok** (telif). |
| Moderasyon | Topluluk doğrulaması (bağımsız 3 kullanıcı aynı öneriyi kullanırsa "Doğrulandı") + bakımcı onayı (iyi öneriler PR ile gömülü kataloğa taşınır). |
| Bulunamazsa | Form barkod dolu açılır. Aşama 2'de kayıttan sonra tek seferlik "Bu kitabı kütüphaneye ekle?" sorusu (varsayılan cevap yok). |
| Harici API | Open Library / Google Books **kullanılmaz** (Türk YKS kitaplarında kapsam zayıf, ISBN üçüncü tarafa gider). |
| Barkod okuma | Cihazda: VisionKit `DataScannerViewController`. Desteklenmiyorsa ya da kamera izni yoksa barkod elle yazılır. Ağ gerekmez. |

Kurallarla uyum: kaynak veri cihazda kalır (kütüphaneden eklenen kitap kullanıcının **özel kopyasıdır**), kendi sunucumuz yoktur (gömülü katalog + Apple'ın public DB'si), analitik yoktur.

## Akış

1. Kitaplar → "+" → **Barkod okut** (ya da **Elle ekle**).
2. Barkod normalize edilir (EAN-13; ISBN-10 ve UPC-A EAN-13'e çevrilir; geçersiz sağlama → hata).
3. Kullanıcıda aynı barkodlu kitap varsa → "Bu kitap zaten kitaplığında" ve kitaba git.
4. Gömülü katalogda aranır (çevrimdışı). Aşama 2'de bulunamazsa public DB'de aranır (doğrulanmışlar önce).
5. Bulunursa form dolu açılır; kullanıcı düzenleyebilir. Kayıt: `Book` (+ `barcode`, `libraryKey`) ve kitabın `BookSection` kayıtları.
6. Bulunamazsa form yalnızca barkod dolu açılır.

## Veri modeli (şema yalnızca büyür)

### Özel veri (SwiftData + CloudKit private; web Dexie)

| Değişiklik | Web (`types.ts`) | Swift | CloudKit |
| --- | --- | --- | --- |
| `Book.barcode` | `string \| null` | `String?` | `CD_barcode` |
| `Book.libraryKey` | `string \| null` | `String?` | `CD_libraryKey` |
| Yeni `BookSection` | `bookSections` tablosu | `@Model BookSection` | `CD_BookSection` |
| `TestResult.bookSectionId` (Aşama 3, sahibi analysis) | `UUID \| null` | `UUID?` | `CD_bookSectionId` |

`BookSection` alanları: `bookId: UUID?`, `title: String = ""`, `order: Int = 0`, `startUnit: Int?`, `endUnit: Int?` (kitabın birimiyle, ör. test 1–12), `topicId: UUID?` (katalog konusu).

Bölümler kitapla birlikte kullanıcının kopyasıdır; kütüphane kaydı sonradan değişse de kullanıcının ilerlemesi ve test sonuçları bozulmaz.

### Gömülü katalog

- Kaynak: `web/src/library/` (müfredat kataloğu deseni). iOS kopyası `npm run export:ios-library` ile `ios/FokusKit/Sources/FokusData/Resources/book-library.json` dosyasına yazılır; drift testi ikisinin aynı kaldığını denetler.
- Kayıt (`LibraryBook`): `key` (kalıcı, asla değişmez/silinmez), `barcodes[]`, `title`, `publisher`, `kind`, `exam`, `subjectCatalogKey`, `unit`, `totalUnits`, `editionYear`, `sections[{ title, order, startUnit, endUnit, topicCatalogKey }]`.
- Ders ve konular UUID ile değil **catalogKey** ile tutulur; cihaz `catalogEntityId` ile id'ye çevirir. Böylece kayıt her cihazda aynı sonucu verir.
- Katalog SwiftData/Dexie'ye **tohumlanmaz**; bellekte barkoda göre aranır (CloudKit'te kopya oluşmaz).
- Katkı: kitap bilgisi **kitabın kendisinden** girilir; yayınevi sitelerinden kopyalanmaz, ISBN uydurulmaz. Doğrulama testleri benzersiz anahtar/barkod, geçerli sağlama, var olan müfredat anahtarı ve tutarlı bölüm aralıklarını denetler.

### Public DB (Aşama 2; elle CloudKit API, `CD_` öneki yok)

| Kayıt | Alanlar | İzin |
| --- | --- | --- |
| `LibrarySubmission` | `barcode` (sorgulanabilir), `title`, `publisher`, `kindRaw`, `examRaw`, `subjectCatalogKey`, `unitRaw`, `totalUnits`, `editionYear`, `sectionsJSON`, `schemaVersion` | Herkes okur; kimliği doğrulanmış kullanıcı oluşturur; yalnızca sahibi yazar |
| `LibraryConfirmation` | recordName `<submissionId>:<userRecordName>`, `barcode` | Öneriyi değiştirmeden kullanan oluşturur (kişi başı tek) |
| `LibraryReport` | `submission`, `reason` | Kimliği doğrulanmış kullanıcı oluşturur; okuma yalnızca Console |

## Moderasyon ve App Store 1.2

"Topluluk önerisi" etiketi → 3 bağımsız onayla "Doğrulandı". **Bildir** ve **bu kişinin önerilerini gizle** (cihazda tutulur). Başlık uzunluk sınırı ve basit küfür filtresi. Destek iletişim bilgisi. Bakımcı kötü kayıtları CloudKit Console'dan siler, iyileri PR ile gömülü kataloğa taşır.

## Gizlilik

- Public DB'ye yalnızca **kitaba ait, kişisel olmayan** bilgi ve yalnızca açık rızayla gider. İlerleme, test sonucu, kullanıcı adı gitmez; kayıt sahibi Apple'ın uygulamaya özel takma adlı kimliğiyle görünür.
- Barkod araması Apple'a gider; bize hiçbir şey gelmez.
- Aşama 2'de ARCHITECTURE 4.7'deki "public DB'ye kitap içeriği gitmez" kuralı bu istisnayla güncellenir; gizlilik metni ve App Store gizlilik etiketi güncellenir.
- Kamera görüntüsü cihazdan çıkmaz (`NSCameraUsageDescription`).

## Aşamalar

**Aşama 1 — MVP (1.0.1, iOS, çevrimdışı)**
- Veri sözleşmesi: `Book.barcode`, `Book.libraryKey`, `BookSection` (web + iOS + ARCHITECTURE 4.3).
- Barkod mantığı (normalize, EAN-13 sağlama, ISBN-10/UPC-A dönüşümü) web `domain` + `FokusDomain`, aynı tablo vakalarıyla.
- Gömülü katalog altyapısı + doğrulama + iOS dışa aktarımı. Katalog **boş başlar**; kitaplar bakımcı tarafından kitaba bakılarak eklenir.
- iOS: barkod tarayıcı + elle barkod girişi, katalog araması, dolu form, bölüm kopyalama, kitap detayında bölüm listesi.
- Web: barkod alanı + gömülü katalogda arama (kamera yok).
- CloudKit: yeni alanlar/model için Development şeması cihazda hazırlanır ve Production'a deploy edilir (bakımcı).

**Aşama 2** — public DB önerileri, doğrulama, bildir/gizle, gizlilik metni.

**Aşama 3** — analizde bölüm seçici (`TestResult.bookSectionId`), bölüm bazlı ilerleme ("Test 37'ye geldim" → konu önerisi), başlıkla kütüphane araması, "kütüphanedeki güncellemeyi al", terfi betiği.

## Doğrulanmamış noktalar

- Public DB'nin iCloud hesabı olmadan okunabilmesi.
- CloudKit Console güvenlik rollerinin alan düzeyi inceliği.
- `DataScannerViewController` cihaz desteği (A12 ve sonrası; simülatörde desteklenmez → elle giriş yolu).
