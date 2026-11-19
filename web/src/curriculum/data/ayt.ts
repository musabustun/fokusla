/**
 * AYT (Alan Yeterlilik Testleri) dersleri ve konuları.
 *
 * Soru sayıları ve puan türlerine göre kullanılan testler: ÖSYM 2026-YKS Kılavuzu,
 * Tablo 1B (soru sayıları) ve Tablo 1E (SAY, EA, SÖZ ağırlıkları).
 *   SAY → Matematik + Fen Bilimleri (Fizik, Kimya, Biyoloji)
 *   EA  → Matematik + Türk Dili ve Edebiyatı-Sosyal Bilimler-1 (Edebiyat, Tarih-1, Coğrafya-1)
 *   SÖZ → Türk Dili ve Edebiyatı-Sosyal Bilimler-1 + Sosyal Bilimler-2
 *         (Tarih-2, Coğrafya-2, Felsefe Grubu, Din Kültürü)
 *
 * Konu listeleri MEB kazanım belgesindeki ünitelerden ve yaygın "YKS konuları" listelerinden
 * türetilmiştir; düzenlenebilir bir başlangıç noktasıdır (bkz. ../README.md).
 * Anahtarları (slug) ASLA değiştirme/silme.
 */
import type { YksField } from '@/domain'
import { defineSubject } from './define'

const EA_SOZ: YksField[] = ['EA', 'SOZ']
const SAY_EA: YksField[] = ['SAY', 'EA']

// ---------------------------------------------------------------------------
// Türk Dili ve Edebiyatı-Sosyal Bilimler-1 Testi (40 soru) — EA ve SÖZ
// ---------------------------------------------------------------------------

const edebiyat = defineSubject({
  key: 'ayt-edebiyat',
  name: 'Türk Dili ve Edebiyatı',
  exam: 'AYT',
  fields: EA_SOZ,
  questionCount: 24,
  topics: [
    ['anlam-bilgisi', 'Anlam Bilgisi (Sözcük, Cümle, Paragraf)'],
    ['dil-bilgisi', 'Dil Bilgisi'],
    ['siir-bilgisi', 'Şiir Bilgisi (Nazım Birimi, Ölçü, Kafiye, Redif)'],
    ['edebi-sanatlar', 'Edebî Sanatlar'],
    ['edebi-turler', 'Metinlerin Sınıflandırılması ve Edebî Türler'],
    ['islamiyet-oncesi-turk-edebiyati', 'İslamiyet Öncesi Türk Edebiyatı'],
    ['gecis-donemi-edebiyati', 'Geçiş Dönemi Türk Edebiyatı'],
    ['halk-edebiyati', 'Halk Edebiyatı'],
    ['divan-edebiyati', 'Divan Edebiyatı'],
    ['tanzimat-edebiyati', 'Tanzimat Edebiyatı'],
    ['servet-i-funun', 'Servet-i Fünun Edebiyatı'],
    ['fecr-i-ati', 'Fecr-i Âti Edebiyatı'],
    ['milli-edebiyat', 'Millî Edebiyat Dönemi'],
    ['cumhuriyet-donemi-1923-1940', 'Cumhuriyet Dönemi (1923–1940)'],
    ['cumhuriyet-donemi-1940-1960', 'Cumhuriyet Dönemi (1940–1960)'],
    ['cumhuriyet-donemi-1960-sonrasi', 'Cumhuriyet Dönemi (1960 Sonrası)'],
    ['edebi-akimlar', 'Edebiyat Akımları'],
    ['dunya-edebiyati', 'Dünya Edebiyatı'],
  ],
})

const tarih1 = defineSubject({
  key: 'ayt-tarih-1',
  name: 'Tarih-1',
  exam: 'AYT',
  fields: EA_SOZ,
  questionCount: 10,
  topics: [
    ['tarih-ve-zaman', 'Tarih ve Zaman'],
    ['insanligin-ilk-donemleri', 'İnsanlığın İlk Dönemleri'],
    ['orta-cagda-dunya', "Orta Çağ'da Dünya"],
    ['ilk-ve-orta-caglarda-turk-dunyasi', 'İlk ve Orta Çağlarda Türk Dünyası'],
    ['islam-medeniyetinin-dogusu', 'İslam Medeniyetinin Doğuşu'],
    ['ilk-turk-islam-devletleri', "Türklerin İslamiyet'i Kabulü ve İlk Türk İslam Devletleri"],
    ['selcuklu-turkiyesi', 'Yerleşme ve Devletleşme Sürecinde Selçuklu Türkiyesi'],
    ['beylikten-devlete-osmanli-siyaseti', 'Beylikten Devlete Osmanlı Siyaseti'],
    ['savascilar-ve-askerler', 'Devletleşme Sürecinde Savaşçılar ve Askerler'],
    ['beylikten-devlete-osmanli-medeniyeti', 'Beylikten Devlete Osmanlı Medeniyeti'],
    ['dunya-gucu-osmanli', 'Dünya Gücü Osmanlı'],
    ['sultan-ve-merkez-teskilati', 'Sultan ve Osmanlı Merkez Teşkilatı'],
    ['klasik-cagda-osmanli-toplum-duzeni', 'Klasik Çağda Osmanlı Toplum Düzeni'],
    ['degisen-dunya-dengeleri-osmanli', 'Değişen Dünya Dengeleri Karşısında Osmanlı Siyaseti'],
    ['degisim-caginda-avrupa-osmanli', 'Değişim Çağında Avrupa ve Osmanlı'],
    ['denge-stratejisi-1774-1914', 'Uluslararası İlişkilerde Denge Stratejisi (1774–1914)'],
    ['devrimler-caginda-devlet-toplum', 'Devrimler Çağında Değişen Devlet – Toplum İlişkileri'],
    ['sermaye-ve-emek', 'Sermaye ve Emek'],
    ['degisen-gundelik-hayat', 'XIX. ve XX. Yüzyılda Değişen Gündelik Hayat'],
    ['xx-yuzyil-baslarinda-osmanli', 'XX. Yüzyıl Başlarında Osmanlı Devleti ve Dünya'],
    ['milli-mucadele', 'Millî Mücadele'],
    ['ataturkculuk-ve-turk-inkilabi', 'Atatürkçülük ve Türk İnkılabı'],
  ],
})

/**
 * AYT Coğrafya-1. Kılavuz Tablo 1B dipnotu: 11–12. sınıfta yalnızca 4 saatlik programda
 * yer alan kazanımlar Coğrafya-1 kapsamı dışındadır.
 */
const cografya1 = defineSubject({
  key: 'ayt-cografya-1',
  name: 'Coğrafya-1',
  exam: 'AYT',
  fields: EA_SOZ,
  questionCount: 6,
  topics: [
    ['ekosistemler', 'Ekosistemler ve Biyoçeşitlilik'],
    ['nufus-politikalari', 'Nüfus Politikaları'],
    ['turkiyede-nufus-ve-yerlesme', "Türkiye'de Nüfus ve Yerleşme"],
    ['ekonomik-faaliyetler-ve-dogal-kaynaklar', 'Ekonomik Faaliyetler ve Doğal Kaynaklar'],
    ['turkiye-ekonomisi', 'Türkiye Ekonomisi (Tarım, Madencilik, Sanayi, Hizmetler)'],
    ['islevsel-bolgeler-ve-kalkinma', 'İşlevsel Bölgeler ve Kalkınma Projeleri'],
    ['kuresel-ticaret-ve-ulasim', 'Küresel Ticaret ve Ulaşım'],
    ['bolgeler-ve-ulkeler', 'Bölgeler ve Ülkeler'],
    ['cevre-ve-toplum', 'Çevre ve Toplum'],
    ['dogal-afetler', 'Doğal Afetler'],
  ],
})

// ---------------------------------------------------------------------------
// Sosyal Bilimler-2 Testi (40 soru) — yalnızca SÖZ
// ---------------------------------------------------------------------------

/**
 * AYT Tarih-2. ÖSYM Tarih-2 sorularında Tarih-1 konuları da yer alabilir; ortak konular
 * tekrar edilmesin diye Tarih-1 dersinde takip edilir. Burada SÖZ'e özgü çağdaş tarih vardır.
 */
const tarih2 = defineSubject({
  key: 'ayt-tarih-2',
  name: 'Tarih-2',
  exam: 'AYT',
  fields: ['SOZ'],
  questionCount: 11,
  topics: [
    ['iki-savas-arasi-donem', 'İki Savaş Arasındaki Dönemde Türkiye ve Dünya'],
    ['ii-dunya-savasi-sureci', 'II. Dünya Savaşı Sürecinde Türkiye ve Dünya'],
    ['ii-dunya-savasi-sonrasi', 'II. Dünya Savaşı Sonrasında Türkiye ve Dünya'],
    ['toplumsal-devrim-caginda-dunya', 'Toplumsal Devrim Çağında Dünya ve Türkiye'],
    ['xxi-yuzyilin-esiginde', 'XXI. Yüzyılın Eşiğinde Türkiye ve Dünya'],
  ],
})

const cografya2 = defineSubject({
  key: 'ayt-cografya-2',
  name: 'Coğrafya-2',
  exam: 'AYT',
  fields: ['SOZ'],
  questionCount: 11,
  topics: [
    ['biyocesitlilik', 'Biyoçeşitlilik'],
    ['ekosistemlerin-isleyisi', 'Ekosistemlerin İşleyişi, Enerji Akışı ve Madde Döngüsü'],
    ['nufus-politikalari', 'Nüfus Politikaları'],
    ['sehirlesme-ve-goc', 'Şehirleşme ve Göç'],
    ['ekonomik-faaliyetler', 'Ekonomik Faaliyetler ve Doğal Kaynaklar'],
    ['turkiyenin-islevsel-bolgeleri', "Türkiye'nin İşlevsel Bölgeleri"],
    ['kuresel-ve-bolgesel-orgutler', 'Küresel ve Bölgesel Örgütler'],
    ['kultur-bolgeleri', 'Kültür Bölgeleri'],
    ['ulkeler-arasi-etkilesim', 'Ülkeler Arası Etkileşim ve Jeopolitik Konum'],
    ['catisma-bolgeleri', 'Çatışma Bölgeleri'],
    ['cevre-sorunlari', 'Küresel Çevre Sorunları'],
  ],
})

/** Felsefe Grubu: Felsefe, Psikoloji, Sosyoloji, Mantık — toplam 12 soru (tek alt test). */
const felsefeGrubu = defineSubject({
  key: 'ayt-felsefe-grubu',
  name: 'Felsefe Grubu',
  exam: 'AYT',
  fields: ['SOZ'],
  questionCount: 12,
  topics: [
    ['felsefe-mo6-ms2', 'Felsefe: MÖ 6. – MS 2. Yüzyıl Felsefesi'],
    ['felsefe-ms2-ms15', 'Felsefe: MS 2. – MS 15. Yüzyıl Felsefesi'],
    ['felsefe-15-17', 'Felsefe: 15. – 17. Yüzyıl Felsefesi'],
    ['felsefe-18-19', 'Felsefe: 18. – 19. Yüzyıl Felsefesi'],
    ['felsefe-20', 'Felsefe: 20. Yüzyıl Felsefesi'],
    ['psikoloji-bilimini-taniyalim', 'Psikoloji: Psikoloji Bilimini Tanıyalım'],
    ['psikolojinin-temel-surecleri', 'Psikoloji: Psikolojinin Temel Süreçleri'],
    ['ogrenme-bellek-dusunme', 'Psikoloji: Öğrenme, Bellek, Düşünme'],
    ['ruh-sagligi', 'Psikoloji: Ruh Sağlığının Temelleri'],
    ['sosyolojiye-giris', 'Sosyoloji: Sosyolojiye Giriş'],
    ['birey-ve-toplum', 'Sosyoloji: Birey ve Toplum'],
    ['toplumsal-yapi', 'Sosyoloji: Toplumsal Yapı'],
    ['toplumsal-degisme', 'Sosyoloji: Toplumsal Değişme ve Gelişme'],
    ['toplum-ve-kultur', 'Sosyoloji: Toplum ve Kültür'],
    ['toplumsal-kurumlar', 'Sosyoloji: Toplumsal Kurumlar'],
    ['mantiga-giris', 'Mantık: Mantığa Giriş'],
    ['klasik-mantik', 'Mantık: Klasik Mantık'],
    ['mantik-ve-dil', 'Mantık: Mantık ve Dil'],
    ['sembolik-mantik', 'Mantık: Sembolik Mantık'],
  ],
})

/** Din Kültürü ve Ahlak Bilgisi — 6 soru; muaf adaylar yerine 6 ilave Felsefe Grubu sorusu çözer. */
const din = defineSubject({
  key: 'ayt-din',
  name: 'Din Kültürü ve Ahlak Bilgisi',
  exam: 'AYT',
  fields: ['SOZ'],
  questionCount: 6,
  topics: [
    ['dunya-ve-ahiret', 'Dünya ve Ahiret'],
    ['kurana-gore-hz-muhammed', "Kur'an'a Göre Hz. Muhammed"],
    ['kuranda-bazi-kavramlar', "Kur'an'da Bazı Kavramlar"],
    ['inancla-ilgili-meseleler', 'İnançla İlgili Meseleler'],
    ['yahudilik-ve-hristiyanlik', 'Yahudilik ve Hristiyanlık'],
    ['islam-ve-bilim', 'İslam ve Bilim'],
    ['anadoluda-islam', "Anadolu'da İslam"],
    ['tasavvufi-yorumlar', 'İslam Düşüncesinde Tasavvufi Yorumlar'],
    ['guncel-dini-meseleler', 'Güncel Dinî Meseleler'],
    ['hint-ve-cin-dinleri', 'Hint ve Çin Dinleri'],
  ],
})

// ---------------------------------------------------------------------------
// Matematik Testi (40 soru) — SAY ve EA
// ÖSYM'ye göre TEK test; matematik/geometri bölünmesi resmî olmadığından questionCount null.
// ---------------------------------------------------------------------------

const matematik = defineSubject({
  key: 'ayt-matematik',
  name: 'Matematik',
  exam: 'AYT',
  fields: SAY_EA,
  questionCount: null,
  topics: [
    ['fonksiyonlar', 'Fonksiyonlar'],
    ['polinomlar', 'Polinomlar'],
    ['ikinci-dereceden-denklemler', 'İkinci Dereceden Denklemler'],
    ['esitsizlikler', 'Eşitsizlikler ve Denklem Sistemleri'],
    ['parabol', 'Parabol (İkinci Dereceden Fonksiyonlar)'],
    ['permutasyon-kombinasyon-binom', 'Permütasyon, Kombinasyon ve Binom'],
    ['olasilik', 'Olasılık'],
    ['trigonometri', 'Trigonometri'],
    ['ustel-ve-logaritmik-fonksiyonlar', 'Üstel ve Logaritmik Fonksiyonlar'],
    ['diziler', 'Diziler'],
    ['limit-ve-sureklilik', 'Limit ve Süreklilik'],
    ['turev', 'Türev'],
    ['integral', 'İntegral'],
  ],
})

const geometri = defineSubject({
  key: 'ayt-geometri',
  name: 'Geometri',
  exam: 'AYT',
  fields: SAY_EA,
  questionCount: null,
  topics: [
    ['ucgenler', 'Üçgenler'],
    ['cokgenler-ve-dortgenler', 'Çokgenler ve Dörtgenler'],
    ['cember-ve-daire', 'Çember ve Daire'],
    ['dogrunun-analitigi', 'Doğrunun Analitik İncelenmesi'],
    ['donusum-geometrisi', 'Dönüşüm Geometrisi'],
    ['kati-cisimler', 'Katı Cisimler'],
    ['cemberin-analitigi', 'Çemberin Analitik İncelenmesi'],
  ],
})

// ---------------------------------------------------------------------------
// Fen Bilimleri Testi (40 soru) — yalnızca SAY
// ---------------------------------------------------------------------------

const fizik = defineSubject({
  key: 'ayt-fizik',
  name: 'Fizik',
  exam: 'AYT',
  fields: ['SAY'],
  questionCount: 14,
  topics: [
    ['vektorler', 'Vektörler'],
    ['bagil-hareket', 'Bağıl Hareket'],
    ['newtonun-hareket-yasalari', "Newton'un Hareket Yasaları"],
    ['bir-boyutta-sabit-ivmeli-hareket', 'Bir Boyutta Sabit İvmeli Hareket'],
    ['atislar', 'Atışlar (İki Boyutta Hareket)'],
    ['enerji-ve-hareket', 'Enerji ve Hareket'],
    ['itme-ve-momentum', 'İtme ve Çizgisel Momentum'],
    ['tork-ve-denge', 'Tork ve Denge'],
    ['kutle-merkezi', 'Kütle Merkezi'],
    ['basit-makineler', 'Basit Makineler'],
    ['elektriksel-kuvvet-ve-alan', 'Elektriksel Kuvvet ve Elektrik Alan'],
    ['elektriksel-potansiyel', 'Elektriksel Potansiyel'],
    ['duzgun-elektrik-alan-ve-siga', 'Düzgün Elektrik Alan ve Sığa'],
    ['manyetizma-ve-induksiyon', 'Manyetizma ve Elektromanyetik İndüksiyon'],
    ['alternatif-akim-transformator', 'Alternatif Akım ve Transformatörler'],
    ['cembersel-hareket', 'Düzgün Çembersel Hareket'],
    ['donerek-oteleme-acisal-momentum', 'Dönerek Öteleme ve Açısal Momentum'],
    ['kutle-cekim-kepler', 'Kütle Çekim ve Kepler Yasaları'],
    ['basit-harmonik-hareket', 'Basit Harmonik Hareket'],
    ['dalga-mekanigi', 'Dalga Mekaniği'],
    ['atom-fizigi-radyoaktivite', 'Atom Fiziğine Giriş ve Radyoaktivite'],
    ['modern-fizik', 'Modern Fizik'],
    ['modern-fizigin-uygulamalari', 'Modern Fiziğin Teknolojideki Uygulamaları'],
  ],
})

const kimya = defineSubject({
  key: 'ayt-kimya',
  name: 'Kimya',
  exam: 'AYT',
  fields: ['SAY'],
  questionCount: 13,
  topics: [
    ['modern-atom-teorisi', 'Modern Atom Teorisi'],
    ['gazlar', 'Gazlar'],
    ['sivi-cozeltiler-cozunurluk', 'Sıvı Çözeltiler ve Çözünürlük'],
    ['tepkimelerde-enerji', 'Kimyasal Tepkimelerde Enerji'],
    ['tepkimelerde-hiz', 'Kimyasal Tepkimelerde Hız'],
    ['tepkimelerde-denge', 'Kimyasal Tepkimelerde Denge'],
    ['asit-baz-dengesi', 'Asit – Baz Dengesi'],
    ['cozunurluk-dengesi', 'Çözünürlük Dengesi'],
    ['kimya-ve-elektrik', 'Kimya ve Elektrik'],
    ['karbon-kimyasina-giris', 'Karbon Kimyasına Giriş'],
    ['organik-bilesikler', 'Organik Bileşikler'],
    ['enerji-kaynaklari', 'Enerji Kaynakları ve Bilimsel Gelişmeler'],
  ],
})

const biyoloji = defineSubject({
  key: 'ayt-biyoloji',
  name: 'Biyoloji',
  exam: 'AYT',
  fields: ['SAY'],
  questionCount: 13,
  topics: [
    ['sinir-sistemi', 'Sinir Sistemi'],
    ['endokrin-sistem', 'Endokrin Sistem'],
    ['duyu-organlari', 'Duyu Organları'],
    ['destek-ve-hareket-sistemi', 'Destek ve Hareket Sistemi'],
    ['sindirim-sistemi', 'Sindirim Sistemi'],
    ['dolasim-ve-bagisiklik', 'Dolaşım Sistemi ve Bağışıklık'],
    ['solunum-sistemi', 'Solunum Sistemi'],
    ['uriner-sistem', 'Üriner Sistem'],
    ['ureme-ve-embriyonik-gelisim', 'Üreme Sistemi ve Embriyonik Gelişim'],
    ['komunite-ekolojisi', 'Komünite Ekolojisi'],
    ['populasyon-ekolojisi', 'Popülasyon Ekolojisi'],
    ['nukleik-asitler-genetik-sifre', 'Nükleik Asitler ve Genetik Şifre'],
    ['protein-sentezi', 'Protein Sentezi'],
    ['canlilik-ve-enerji', 'Canlılık ve Enerji (ATP)'],
    ['fotosentez', 'Fotosentez'],
    ['kemosentez', 'Kemosentez'],
    ['hucresel-solunum', 'Hücresel Solunum'],
    ['bitkilerin-yapisi', 'Bitkilerin Yapısı'],
    ['bitkilerde-madde-tasinmasi', 'Bitkilerde Madde Taşınması'],
    ['bitkilerde-eseyli-ureme', 'Bitkilerde Eşeyli Üreme'],
    ['canlilar-ve-cevre', 'Canlılar ve Çevre'],
  ],
})

/** Kitapçıktaki test sırasına göre. */
export const aytSubjects = [
  edebiyat,
  tarih1,
  cografya1,
  tarih2,
  cografya2,
  felsefeGrubu,
  din,
  matematik,
  geometri,
  fizik,
  kimya,
  biyoloji,
]
