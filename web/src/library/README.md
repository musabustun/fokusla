# Gömülü kitap kütüphanesi

Bu klasör, barkod okutulunca kitap formunu dolduran **gömülü kitap kataloğunu** içerir
(tasarım: `docs/books-library.md`). Katalog saf veridir; kullanıcı kütüphaneden kitap eklediğinde
kendi **özel kopyasını** alır. Katalog **boş başlar**; kitaplar tek tek, bakımcı tarafından eklenir.

## Dosyalar

| Dosya          | İçerik                                                                       |
| -------------- | ---------------------------------------------------------------------------- |
| `books.ts`     | `bookLibrary` — kitap kayıtları (düzenlediğin tek veri dosyası)              |
| `types.ts`     | `LibraryBook`, `LibrarySection`, `BookLibrary`                               |
| `lookup.ts`    | `findLibraryBook(library, rawBarcode)`, `resolveLibraryBook(book, barcode?)` |
| `validate.ts`  | `validateLibrary(library, curriculum)` → hata listesi                        |
| `iosExport.ts` | iOS JSON dışa aktarımı (kararlı anahtar sırası)                              |
| `fixtures.ts`  | Yalnızca testler için sentetik kitap                                         |

Barkod normalleştirme `@/domain` içindedir (`normalizeBarcode`: EAN-13 / ISBN-10 / UPC-A → EAN-13).

## Kitap ekleme kuralları

1. **Kitabı elinde tutarak gir.** Başlık, yayınevi, sayfa/test sayısı ve içindekiler kitabın
   kendisinden okunur. **Satış sitelerinden, başka uygulamalardan veya veri tabanlarından kopyalama.**
2. **`key` kalıcıdır.** Yazım hatası olsa bile asla değiştirme, asla silme: kullanıcı kayıtları
   `libraryKey` ile bu anahtara bağlıdır. Biçim: `<yayinevi>-<ders>-<ad>[-<yil>]` (küçük harf, tire,
   Türkçe karakterler ASCII'ye: `ç→c ğ→g ı→i ö→o ş→s ü→u`).
3. Başlık ve yayınevi adları serbestçe düzeltilebilir; anahtara dokunulmaz.
4. `barcodes` normalleştirilmiş **EAN-13** olmalıdır (ISBN-10 veya tireli yazma; önce çevir).
   Aynı kitabın başka baskı barkodu varsa diziye ekle. Bir barkod katalogda yalnızca bir kitapta olabilir.
5. `subjectCatalogKey` ve `topicCatalogKey` müfredat anahtarlarıdır (`web/src/curriculum`); bölümün
   konusu kitabın dersine ait olmalıdır. Emin değilsen `null` bırak.
6. `sections[].order` 1'den başlar, artan ve benzersizdir. `startUnit ≤ endUnit ≤ totalUnits`.

## Örnek kayıt (kurgusal)

```ts
{
  key: 'ornek-yayinlari-tyt-matematik-soru-bankasi',
  barcodes: ['9781234567897'],
  title: 'Örnek Yayınları TYT Matematik Soru Bankası',
  publisher: 'Örnek Yayınları',
  kind: 'questionBank',
  exam: 'TYT',
  subjectCatalogKey: 'tyt-matematik',
  unit: 'test',
  totalUnits: 40,
  editionYear: 2026,
  sections: [
    { title: 'Temel Kavramlar', order: 1, startUnit: 1, endUnit: 10,
      topicCatalogKey: 'tyt-matematik.temel-kavramlar' },
  ],
}
```

Her içerik değişikliğinde `version`'ı artır ve `updatedAt`'i güncelle.

## Doğrulama ve iOS dışa aktarımı

```bash
cd web
npm test -- src/library          # validateLibrary(bookLibrary, yksCurriculum) hatasız olmalı
npm run export:ios-library       # ios/FokusKit/Sources/FokusData/Resources/book-library.json
```

JSON'u elle düzenleme; `iosExport.test.ts` drift testi web kataloğu ile JSON'un aynı kaldığını denetler.
