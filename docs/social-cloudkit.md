# Sosyal: CloudKit paylaşım tasarımı (yalnızca tasarım notu)

Durum: **uygulanmadı.** iOS'ta Sosyal bugün `MockSocialService` ile çalışır (ağ yok, sabit sahte
dünya, yerel durum). Bu not, gerçek senkronun nasıl yapılacağını özetler; ayrıntılı kayıt tipi ve
işlem eşlemesi [ARCHITECTURE.md 4.7](ARCHITECTURE.md) içindedir — burada tekrarlanmaz, yalnızca karar
ve sıra verilir. "Doğrulanmadı" denen her şey Apple dokümanından/cihazdan teyit edilmelidir.

## 1. Hedef ve sınırlar

- Kendi sunucumuz YOK; yalnızca Apple CloudKit (kullanıcının iCloud hesabı + uygulamanın kapsayıcısı).
- Ücretsiz, reklamsız. Public DB kotaları uygulamanın CloudKit kapsamına yazılır (doğrulanmadı).
- Kullanıcıların çoğu 18 yaş altı → paylaşılan veri **asgari** (bkz. 3. Gizlilik).
- Giriş opsiyoneldir; Sosyal ise bir hesap ister: "Apple ile Giriş" (kimlik) + `CKContainer.accountStatus() == .available`.

## 2. Mimari: nereye takılır

```
FokusData/Social/SocialService (protokol, @MainActor)   ← UI yalnızca bunu bilir
   ├─ MockSocialService        (bugün; web ile aynı sahte dünya)
   └─ CloudKitSocialService    (gelecek; aynı sözleşme, aynı hata kodları)
```

- Değişim tek yerde: `AppEnvironment.makeSocialService`. UI, `SocialSnapshot` değer tiplerini okur;
  CloudKit tipleri (`CKRecord`, `CKShare`) FokusData dışına sızmaz.
- Sözleşme `SocialError.code` ile hata verir (`usernameTaken`, `roomNotFound` …); CloudKit hataları
  (`serverRecordChanged`, `unknownItem`, `networkUnavailable` …) bu kodlara çevrilir, bilinmeyenler
  genel "tekrar dene" mesajına düşer.
- Kendi odak durumum `SocialCalc.ownPresenceFromFocus` ile (FokusDomain) odak kayıtlarından
  **yalnızca okunarak** üretilir. Yayın, uygulama düzeyinde `SocialPresencePublisher` ile yapılır
  (Sosyal ekranı kapalıyken de): durum değişince + ~60 sn kalp atışı.

## 3. Veri ve gizlilik

| Ne                      | Nerede                                     | Kim görür                         |
| ----------------------- | ------------------------------------------ | --------------------------------- |
| Kullanıcı adı, davet kodu, "görün" bayrağı | Public DB `PublicProfile`, `UsernameClaim`, `InviteCode` | Uygulamanın tüm kullanıcıları (kasıtlı, asgari) |
| Odak durumu/süreleri    | Public DB `Presence` (`SocialPresence` alanları) | Arkadaşlar (okuma kısıtı Console'da, **doğrulanmadı**) |
| Arkadaş listesi         | Private DB `CD_Friend` (SwiftData mirroring) | Yalnız ben (cihazlarım)           |
| Oda ve üyeleri          | Oda sahibinin özel bölgesi + `CKShare`     | Yalnız davetli üyeler (shared DB) |

- **Asla paylaşılmaz:** Apple kimliği, ad, e-posta, ders/konu/test/kitap/görev içeriği.
- `isDiscoverable == false` → `Presence` kaydı **silinir**; kullanıcı adıyla aranamaz; davet kodu çalışır.
- Serbest metin yalnızca kullanıcı adı (3–20, `[a-z0-9._]`) ve oda adı (≤ 40); ikisi de istemcide
  doğrulanır (`SocialCalc.validateUsername`, oda adı uzunluğu).
- Kötüye kullanım: giden istek hız sınırı, engelleme (`FriendStatus.blocked`), odadan çıkma her zaman
  mümkün; sunucu olmadığı için moderasyon sınırlı (küfür filtresi + bildir ileride).

## 4. Oda paylaşımı (CKShare)

1. **Oluştur:** oda sahibi private DB'de özel `CKRecordZone` açar; `Room` + kendi `RoomMember`'ını yazar;
   bölge kökü için `CKShare` (`publicPermission = .none`, davetle katılım) üretir; kısa kod için public
   `RoomInvite` (kod → `shareURL`) yazar.
2. **Katıl:** kod → `RoomInvite` → `shareURL` → `CKShare.Metadata` → `CKAcceptSharesOperation`; katılan
   kendi `RoomMember` kaydını shared DB'ye yazar.
3. **Durumlar:** oda üyesinin odak durumu odadan değil üyenin `Presence`'ından okunur (tek doğruluk
   kaynağı); oda yalnızca "kim içeride"yi taşır.
4. **Ayrıl:** üye `RoomMember`'ını siler ve paylaşımdan çıkar; ev sahibi `CKShare` + bölgeyi silerek odayı
   kapatır (mock ile aynı kural).
5. Açık: katılımcı üst sınırı, ev sahibi gidince oda kapanması kabulü (bkz. ARCHITECTURE 4.7 sorular).

## 5. Gerçek zamanlı değil

CloudKit anlık değildir; push en iyi çabadır. Bu yüzden: (1) ~60 sn kalp atışı + geçişte yayın,
(2) öne gelince / çek-yenile ile `refresh()`, (3) `CKQuerySubscription` yalnızca "şimdi çek" ipucu,
(4) UI süreleri `updatedAt`/`stateSince`'ten **yerelde** her saniye ilerletir (`SocialCalc.live*`),
(5) 10 dk bayat durum çevrimdışı sayılır (`presenceStaleAfterMs`). Mock bu kuralların hepsini zaten
uygular; gerçek servis yalnızca veri kaynağını değiştirir.

## 6. Mock → gerçek geçiş sırası

1. Kapsayıcıda şemayı **development** ortamında oluştur (kullanıcı onayıyla; Apple Developer hesabında
   kayıt/oluşturma yalnızca kullanıcının onayıyla yapılır). Production'a yalnızca ekleme olarak çıkılır.
2. `CloudKitSocialService`: önce salt okuma (`refresh`, `checkUsername`), sonra `claimUsername`
   (`UsernameClaim` tekilliği `serverRecordChanged` ile), arkadaşlık, en son oda paylaşımı.
3. Aynı sözleşme testleri (`MockSocialServiceTests` vaka adları) CloudKit'in yerel/izole kapsayıcısına
   karşı çalıştırılır; fark çıkan her davranış sözleşmeye mi servise mi ait, karar verilir.
4. `AppEnvironment` iCloud durumuna göre servis seçer; `accountStatus != .available` ise kapı ekranı
   "Sosyal için iCloud'a giriş yapmalısın" der (mock modda önizleme yine açık kalabilir).
5. Sürümden önce: yaş sınırı/ebeveyn onayı gereksinimlerinin hukuki incelemesi (App Store + mevzuat).
