/**
 * TYT (Temel Yeterlilik Testi) dersleri ve konuları — tüm alanlar (SAY, EA, SÖZ, DİL) girer.
 *
 * Soru sayıları: ÖSYM 2026-YKS Kılavuzu, Tablo 1A / Tablo 1B.
 * Konu listeleri: MEB "2026 Yılında Gerçekleştirilecek TYT, AYT ve YDT Sınavlarına Esas Ortak
 * Derslere Ait Kazanım ve Açıklamalar" belgesindeki ünitelerden ve yaygın "YKS konuları"
 * listelerinden türetilmiştir. Düzenlenebilir bir başlangıç noktasıdır (bkz. ../README.md).
 *
 * Konular yaklaşık öğretim sırasındadır. Anahtarları (slug) ASLA değiştirme/silme.
 */
import { ALL_FIELDS, defineSubject } from './define'

/** TYT Türkçe Testi — 40 soru. */
const turkce = defineSubject({
  key: 'tyt-turkce',
  name: 'Türkçe',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 40,
  topics: [
    ['sozcukte-anlam', 'Sözcükte Anlam'],
    ['soz-yorumu', 'Söz Yorumu'],
    ['deyim-ve-atasozu', 'Deyim ve Atasözü'],
    ['cumlede-anlam', 'Cümlede Anlam'],
    ['paragrafta-anlatim-teknikleri', 'Paragrafta Anlatım Teknikleri'],
    ['paragrafta-yapi', 'Paragrafta Yapı'],
    ['paragrafta-konu-ana-dusunce', 'Paragrafta Konu ve Ana Düşünce'],
    ['paragrafta-yardimci-dusunce', 'Paragrafta Yardımcı Düşünce'],
    ['ses-bilgisi', 'Ses Bilgisi'],
    ['yazim-kurallari', 'Yazım Kuralları'],
    ['noktalama-isaretleri', 'Noktalama İşaretleri'],
    ['sozcukte-yapi-ekler', 'Sözcükte Yapı ve Ekler'],
    ['isimler', 'İsimler'],
    ['sifatlar', 'Sıfatlar'],
    ['zamirler', 'Zamirler'],
    ['zarflar', 'Zarflar'],
    ['edat-baglac-unlem', 'Edat, Bağlaç ve Ünlem'],
    ['fiiller', 'Fiiller (Kip, Kişi, Yapı)'],
    ['ek-fiil', 'Ek Fiil'],
    ['fiilimsi', 'Fiilimsi'],
    ['fiilde-cati', 'Fiilde Çatı'],
    ['sozcuk-gruplari', 'Sözcük Grupları'],
    ['cumlenin-ogeleri', 'Cümlenin Ögeleri'],
    ['cumle-turleri', 'Cümle Türleri'],
    ['anlatim-bozuklugu', 'Anlatım Bozukluğu'],
  ],
})

/**
 * TYT Temel Matematik Testi — ÖSYM'ye göre matematik ve geometri birlikte TEK test, 40 soru.
 * Öğrenciler ayrı takip ettiği için iki derse bölündü. Yıldan yıla değişen bölünme (çoğunlukla
 * ~30 matematik / ~10 geometri) resmî olmadığından questionCount null; toplam ../structure.ts'te.
 */
const matematik = defineSubject({
  key: 'tyt-matematik',
  name: 'Matematik',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: null,
  topics: [
    ['temel-kavramlar', 'Temel Kavramlar'],
    ['sayi-basamaklari', 'Sayı Basamakları'],
    ['bolme-ve-bolunebilme', 'Bölme ve Bölünebilme'],
    ['ebob-ekok', 'EBOB – EKOK'],
    ['rasyonel-sayilar', 'Rasyonel Sayılar'],
    ['basit-esitsizlikler', 'Basit Eşitsizlikler'],
    ['mutlak-deger', 'Mutlak Değer'],
    ['uslu-sayilar', 'Üslü Sayılar'],
    ['koklu-sayilar', 'Köklü Sayılar'],
    ['carpanlara-ayirma', 'Çarpanlara Ayırma'],
    ['oran-oranti', 'Oran – Orantı'],
    ['denklem-cozme', 'Denklem Çözme'],
    ['sayi-kesir-problemleri', 'Sayı ve Kesir Problemleri'],
    ['yas-problemleri', 'Yaş Problemleri'],
    ['hareket-problemleri', 'Hareket Problemleri'],
    ['isci-havuz-problemleri', 'İşçi ve Havuz Problemleri'],
    ['yuzde-kar-zarar-problemleri', 'Yüzde, Kâr – Zarar Problemleri'],
    ['karisim-problemleri', 'Karışım Problemleri'],
    ['grafik-problemleri', 'Grafik Problemleri'],
    ['rutin-olmayan-problemler', 'Rutin Olmayan Problemler'],
    ['mantik', 'Mantık'],
    ['kumeler-kartezyen-carpim', 'Kümeler ve Kartezyen Çarpım'],
    ['fonksiyonlar', 'Fonksiyonlar'],
    ['polinomlar', 'Polinomlar'],
    ['ikinci-dereceden-denklemler', 'İkinci Dereceden Denklemler'],
    ['permutasyon-kombinasyon', 'Permütasyon ve Kombinasyon'],
    ['olasilik', 'Olasılık'],
    ['veri-istatistik', 'Veri ve İstatistik'],
  ],
})

/** TYT Temel Matematik Testi'nin geometri kısmı — bkz. matematik yorumu. */
const geometri = defineSubject({
  key: 'tyt-geometri',
  name: 'Geometri',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: null,
  topics: [
    ['dogruda-ve-ucgende-acilar', 'Doğruda ve Üçgende Açılar'],
    ['dik-ucgen', 'Dik Üçgen ve Pisagor'],
    ['ikizkenar-eskenar-ucgen', 'İkizkenar ve Eşkenar Üçgen'],
    ['ucgende-aciortay', 'Üçgende Açıortay'],
    ['ucgende-kenarortay', 'Üçgende Kenarortay'],
    ['ucgende-eslik-benzerlik', 'Üçgende Eşlik ve Benzerlik'],
    ['ucgende-aci-kenar-bagintilari', 'Üçgende Açı – Kenar Bağıntıları'],
    ['ucgende-alan', 'Üçgende Alan'],
    ['cokgenler', 'Çokgenler'],
    ['dortgenler', 'Dörtgenler'],
    ['yamuk', 'Yamuk'],
    ['paralelkenar', 'Paralelkenar'],
    ['eskenar-dortgen-deltoid', 'Eşkenar Dörtgen ve Deltoid'],
    ['dikdortgen-kare', 'Dikdörtgen ve Kare'],
    ['cember-ve-daire', 'Çember ve Daire'],
    ['noktanin-analitigi', 'Noktanın Analitik İncelenmesi'],
    ['dogrunun-analitigi', 'Doğrunun Analitik İncelenmesi'],
    ['kati-cisimler', 'Katı Cisimler'],
  ],
})

/** TYT Sosyal Bilimler Testi — Tarih 5 soru. */
const tarih = defineSubject({
  key: 'tyt-tarih',
  name: 'Tarih',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 5,
  topics: [
    ['tarih-ve-zaman', 'Tarih ve Zaman'],
    ['insanligin-ilk-donemleri', 'İnsanlığın İlk Dönemleri'],
    ['orta-cagda-dunya', "Orta Çağ'da Dünya"],
    ['ilk-ve-orta-caglarda-turk-dunyasi', 'İlk ve Orta Çağlarda Türk Dünyası'],
    ['islam-medeniyetinin-dogusu', 'İslam Medeniyetinin Doğuşu'],
    ['ilk-turk-islam-devletleri', "Türklerin İslamiyet'i Kabulü ve İlk Türk İslam Devletleri"],
    ['selcuklu-turkiyesi', 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi'],
    ['beylikten-devlete-osmanli', 'Beylikten Devlete Osmanlı'],
    ['dunya-gucu-osmanli', 'Dünya Gücü Osmanlı'],
    ['degisen-dunya-dengeleri-osmanli', 'Değişen Dünya Dengeleri Karşısında Osmanlı'],
    ['degisim-caginda-avrupa-osmanli', 'Değişim Çağında Avrupa ve Osmanlı'],
    ['xx-yuzyil-baslarinda-osmanli', 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya'],
    ['milli-mucadele', 'Millî Mücadele'],
    ['ataturkculuk-ve-turk-inkilabi', 'Atatürkçülük ve Türk İnkılabı'],
  ],
})

/** TYT Sosyal Bilimler Testi — Coğrafya 5 soru. */
const cografya = defineSubject({
  key: 'tyt-cografya',
  name: 'Coğrafya',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 5,
  topics: [
    ['doga-ve-insan', 'Doğa ve İnsan'],
    ['dunyanin-sekli-ve-hareketleri', "Dünya'nın Şekli ve Hareketleri"],
    ['cografi-konum', 'Coğrafi Konum'],
    ['harita-bilgisi', 'Harita Bilgisi'],
    ['atmosfer-ve-sicaklik', 'Atmosfer ve Sıcaklık'],
    ['basinc-ve-ruzgarlar', 'Basınç ve Rüzgârlar'],
    ['nem-yagis-buharlasma', 'Nem, Yağış ve Buharlaşma'],
    ['iklim-tipleri', 'İklim Tipleri'],
    ['ic-ve-dis-kuvvetler', 'İç ve Dış Kuvvetler'],
    ['su-toprak-bitki', 'Su, Toprak ve Bitki Örtüsü'],
    ['turkiyenin-yer-sekilleri', "Türkiye'nin Yer Şekilleri ve İklimi"],
    ['nufus', 'Nüfus'],
    ['goc', 'Göç'],
    ['yerlesme', 'Yerleşme'],
    ['ekonomik-faaliyetler', 'Ekonomik Faaliyetler'],
    ['bolgeler', 'Bölgeler'],
    ['uluslararasi-ulasim-hatlari', 'Uluslararası Ulaşım Hatları'],
    ['cevre-ve-toplum', 'Çevre ve Toplum'],
    ['dogal-afetler', 'Doğal Afetler'],
  ],
})

/** TYT Sosyal Bilimler Testi — Felsefe 5 soru (10. sınıf felsefe programı). */
const felsefe = defineSubject({
  key: 'tyt-felsefe',
  name: 'Felsefe',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 5,
  topics: [
    ['felsefeyi-tanima', 'Felsefeyi Tanıma'],
    ['felsefe-ile-dusunme', 'Felsefe ile Düşünme'],
    ['varlik-felsefesi', 'Varlık Felsefesi'],
    ['bilgi-felsefesi', 'Bilgi Felsefesi'],
    ['bilim-felsefesi', 'Bilim Felsefesi'],
    ['ahlak-felsefesi', 'Ahlak Felsefesi'],
    ['din-felsefesi', 'Din Felsefesi'],
    ['siyaset-felsefesi', 'Siyaset Felsefesi'],
    ['sanat-felsefesi', 'Sanat Felsefesi'],
  ],
})

/**
 * TYT Sosyal Bilimler Testi — Din Kültürü ve Ahlak Bilgisi 5 soru.
 * Bu dersten muaf adaylar bunun yerine 5 ilave Felsefe sorusu çözer (Kılavuz 3.10.1).
 */
const din = defineSubject({
  key: 'tyt-din',
  name: 'Din Kültürü ve Ahlak Bilgisi',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 5,
  topics: [
    ['bilgi-ve-inanc', 'Bilgi ve İnanç'],
    ['islam-ve-ibadet', 'İslam ve İbadet'],
    ['genclik-ve-degerler', 'Gençlik ve Değerler'],
    ['allah-insan-iliskisi', 'Allah – İnsan İlişkisi'],
    ['hz-muhammed', 'Hz. Muhammed ve Gençlik'],
    ['din-ve-hayat', 'Din ve Hayat'],
    ['ahlaki-tutum-ve-davranislar', 'Ahlaki Tutum ve Davranışlar'],
    ['islam-dusuncesinde-yorumlar', 'İslam Düşüncesinde Yorumlar'],
    ['din-kultur-medeniyet', 'Din, Kültür ve Medeniyet'],
  ],
})

/** TYT Fen Bilimleri Testi — Fizik 7 soru. */
const fizik = defineSubject({
  key: 'tyt-fizik',
  name: 'Fizik',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 7,
  topics: [
    ['fizik-bilimine-giris', 'Fizik Bilimine Giriş'],
    ['madde-ve-ozellikleri', 'Madde ve Özellikleri'],
    ['hareket-ve-kuvvet', 'Hareket ve Kuvvet'],
    ['is-guc-enerji', 'İş, Güç ve Enerji'],
    ['isi-sicaklik-genlesme', 'Isı, Sıcaklık ve Genleşme'],
    ['elektrostatik', 'Elektrostatik'],
    ['elektrik-akimi-ve-devreler', 'Elektrik Akımı ve Devreler'],
    ['manyetizma', 'Mıknatıslar ve Manyetizma'],
    ['basinc', 'Basınç'],
    ['kaldirma-kuvveti', 'Kaldırma Kuvveti'],
    ['dalgalar', 'Dalgalar'],
    ['optik', 'Optik'],
  ],
})

/** TYT Fen Bilimleri Testi — Kimya 7 soru. */
const kimya = defineSubject({
  key: 'tyt-kimya',
  name: 'Kimya',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 7,
  topics: [
    ['kimya-bilimi', 'Kimya Bilimi'],
    ['atom-ve-periyodik-sistem', 'Atom ve Periyodik Sistem'],
    ['kimyasal-turler-arasi-etkilesimler', 'Kimyasal Türler Arası Etkileşimler'],
    ['maddenin-halleri', 'Maddenin Halleri'],
    ['doga-ve-kimya', 'Doğa ve Kimya'],
    ['kimyanin-temel-kanunlari', 'Kimyanın Temel Kanunları'],
    ['mol-kavrami', 'Mol Kavramı'],
    ['kimyasal-tepkimeler-ve-hesaplamalar', 'Kimyasal Tepkimeler ve Hesaplamalar'],
    ['karisimlar', 'Karışımlar'],
    ['asitler-bazlar-tuzlar', 'Asitler, Bazlar ve Tuzlar'],
    ['kimya-her-yerde', 'Kimya Her Yerde'],
  ],
})

/** TYT Fen Bilimleri Testi — Biyoloji 6 soru. */
const biyoloji = defineSubject({
  key: 'tyt-biyoloji',
  name: 'Biyoloji',
  exam: 'TYT',
  fields: ALL_FIELDS,
  questionCount: 6,
  topics: [
    ['canlilarin-ortak-ozellikleri', 'Canlıların Ortak Özellikleri'],
    ['temel-bilesenler', 'Canlıların Yapısındaki Temel Bileşikler'],
    ['hucre-ve-organeller', 'Hücre ve Organeller'],
    ['hucre-zarindan-madde-gecisi', 'Hücre Zarından Madde Geçişi'],
    ['canlilarin-siniflandirilmasi', 'Canlıların Çeşitliliği ve Sınıflandırılması'],
    ['canli-alemleri', 'Canlı Âlemleri ve Özellikleri'],
    ['mitoz-ve-eseysiz-ureme', 'Mitoz ve Eşeysiz Üreme'],
    ['mayoz-ve-eseyli-ureme', 'Mayoz ve Eşeyli Üreme'],
    ['kalitim', 'Kalıtımın Genel İlkeleri'],
    ['ekosistem-ekolojisi', 'Ekosistem Ekolojisi'],
    ['guncel-cevre-sorunlari', 'Güncel Çevre Sorunları ve İnsan'],
  ],
})

export const tytSubjects = [
  turkce,
  matematik,
  geometri,
  tarih,
  cografya,
  felsefe,
  din,
  fizik,
  kimya,
  biyoloji,
]
