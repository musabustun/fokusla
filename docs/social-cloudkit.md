# Sosyal: CloudKit tasarımı

Durum: **uygulandı** (`FokusData/Social/Cloud`). Gerçek iki iCloud hesabıyla cihazda doğrulama ve
Production şema deploy'u ayrı, kullanıcı onaylı adımlardır (bkz. 8).

## 1. Ürün kararları (kullanıcı, 2026-11-24)

| Konu | Karar |
| --- | --- |
| Arkadaş ekleme | (a) Tek kullanımlık **davet bağlantısı / QR**, (b) **kullanıcı adına istek**. |
| Kullanıcı adı | Arama ve listeleme YOK. Posta gibi: tam ad yazılır; varsa istek gider, yoksa gitmez. Kabul edilmeden kimse kimsenin adını/durumunu görmez. |
| Arkadaşlık | Kabul edilince iki taraf birbirinin kullanıcı adını, canlı durumunu ve bugünkü süresini görür; paylaşım açık kaldığı sürece. |
| Hesap | Apple ile Giriş **ve** cihazda iCloud. Uygulamanın kalanı girişsiz çalışır. |
| Oda | Bağlantısı olan herkes (en çok 20 kişi). Ev sahibi kapatınca oda silinir. |

## 2. Temel fikir: tek arkadaşlık mekanizması, iki teslim yolu

Her arkadaşlık, davet edenin **private** veritabanında ayrı bir bölgedir (`friend-<uuid>`) ve bölge
genelinde bir `CKShare` ile yalnızca bir kişiyle paylaşılır (`publicPermission = .none`,
`CKShare.Participant.oneTimeURLParticipant()`, iOS 18+). Bölgede iki kart durur: benimki ve onunki.
İki kart da varsa arkadaşız.

- **Bağlantı / QR:** tek kullanımlık `CKShare` adresi doğrudan paylaşılır.
- **Kullanıcı adı:** aynı adres, alıcının açık anahtarıyla **şifrelenip** (HPKE, Curve25519) public
  posta kutusuna bırakılır. Yalnız alıcının cihazı açabilir; kabul = aynı `CKShare`'i kabul etmek.

Arkadaş başına ayrı bölge olduğu için arkadaşlarım birbirini göremez.

## 3. Kayıt tipleri

| Kayıt | Veritabanı | recordName | Alanlar |
| --- | --- | --- | --- |
| `SocialIdentity` | Private, `social-identity` bölgesi | `identity` | `payload` (JSON baytları: kullanıcı adı, `personId`, posta kutusu, özel anahtar, gizlilik bayrağı, işlenmiş/engelli kimlikler) |
| `SocialSpaceInfo` | Private/Shared, `friend-*` / `room-*` | `info` | `kind`, `name`, `hostPersonId`, `toUsername`, `mailId`, `createdAt` |
| `SocialCard` | aynı bölge | `card-<personId>` | `personId`, `username`, `state`, `sessionStartedAt`, `stateSince`, `todayFocusMs`, `presenceUpdatedAt`, `expiresAt`, `joinedAt`, `leftAt`, `roomId`, `roomName`, `roomURL`, `roomMemberCount`, `roomFocusingCount` |
| `SocialClaim` | Public | `u1-<SHA256(kullanıcı adı)>` | `publicKey`, `mailbox`, `acceptsRequests` |
| `SocialMail` | Public | UUID | `mailbox` (QUERYABLE), `sealed` (şifreli baytlar) |

Şema dosyası: [cloudkit/social.ckdb](cloudkit/social.ckdb). SwiftData şeması (`CD_*`) **değişmez**; eski
`CD_Friend`/`CD_Room` modelleri dokunulmadan durur (yalnızca büyüyen şema).

**Neden kimse listelenemez:** `SocialClaim`'de hiçbir alan (recordName dahil) sorgulanabilir değildir;
yalnız tam kullanıcı adının özetiyle tek kayıt okunur. `SocialMail` yalnız posta kutusu kimliğiyle
sorgulanır; içeriği şifrelidir. Güvenlik rolleri: okuma ve oluşturma `_icloud`, yazma/silme `_creator`.
Şema Development'ta **elle/dosyayla** kurulmalıdır: CloudKit'in ilk kayıtta kendiliğinden açtığı alanlar
varsayılan olarak sorgulanabilir gelir ve bu garantiyi bozar.

**Sahtecilik:** Mektubu yazan (`creatorUserRecordID`, sunucu belirler) ile iddia edilen kullanıcı adının
`SocialClaim` sahibi aynı değilse mektup yok sayılır.

## 4. Katmanlar

```
FokusDomain   SocialDirectory (özet), SocialMailCrypto (HPKE), SocialContentFilter, SocialCalc
FokusData     SocialService (protokol) ← UI yalnızca bunu bilir
                └─ CloudSocialService (@Observable; tüm kurallar, taşıma bağımsız)
                     └─ SocialCloud (protokol)
                          ├─ CloudKitSocialCloud (ince CloudKit köprüsü)
                          └─ InMemorySocialCloud (testler, UI testleri, önizleme: çok kullanıcılı sahte sunucu)
```

CloudKit tipleri FokusData dışına sızmaz; tek istisna sistemin verdiği `CKShare.Metadata`'nın
`SocialInvite(metadata:)` ile sarılmasıdır.

## 5. Durum (presence)

- Kendi durumum odak kayıtlarından **yalnızca okunarak** üretilir (`SocialCalc.ownPresenceFromFocus`).
- Yayın: durum değişince, ~60 sn kalp atışında ve `ModelContext.didSave`'de (Live Activity ve saat
  üzerinden bitirme dahil). Her arkadaş/oda bölgesindeki kendi kartım yazılır.
- **Arka plan:** telefon kilitliyken uygulama askıya alınır, kalp atışı durur. Bu yüzden `focusing`/`onBreak`
  kartı `expiresAt` taşır (varsayılan 3 saat); o ana kadar süre karşı cihazda yerelde ilerler. `expiresAt`
  yoksa eski 10 dk kuralı geçerlidir.
- **Gün dönümü:** dünkü `todayFocusMs` bugünkü toplam olarak gösterilmez (`SocialCalc.presenceForToday`).
- Gerçek zamanlı değildir: Sosyal açıkken 20 sn'de bir artımlı çekme; açılışta ve öne gelişte `refresh()`.
  Push aboneliği bu sürümde yok.

## 6. Yaşam döngüsü

- **Bekleyen davet:** benim bölgem, karşı kart yok. 30 gün sonra (ya da "Geri çek") bölge ve mektup silinir.
- **Kabul:** karşı taraf kartını yazar. Gönderen bir sonraki yenilemede mektubunu siler.
- **Arkadaşlıktan çıkma:** sahip bölgeyi siler; katılımcı kartına `leftAt` yazıp paylaşımdan ayrılır, sahip
  bir sonraki yenilemede bölgeyi siler.
- **Engelleme:** arkadaşlık silinir, `creatorUserRecordID` ve `personId` engel listesine girer; istekleri görünmez.
- **Çift davet:** iki taraf aynı anda davet ettiyse adı küçük olan bölge kalır, diğeri silinir.
- **Sosyal profili silme:** kullanıcı adı, mektuplar, bölgeler ve kimlik silinir (App Store 5.1.1(v)).
  Ayarlar'daki "Hesabı sil" ve "Tüm verileri sil" de bunu çağırır.

## 7. Gizlilik

- Paylaşılan: kullanıcı adı, durum, oturum/durum başlangıcı, bugünkü süre, açık oda. Ders, konu, test, kitap,
  görev, gerçek ad, e-posta **asla**.
- Davet bağlantısını açarken iOS, davet edenin **iCloud adını** gösterebilir (sistem ekranı; engellenemez).
  Arayüz bunu davet paylaşılmadan önce söyler.
- "Sosyalde görün" kapalı: durum yayınlanmaz, kullanıcı adına istek gelmez (gönderen "bulunamadı" görür).
- Public'te kullanıcı adının özeti, açık anahtar ve posta kutusu durduğundan **App Store gizlilik etiketi
  "Veri toplanmıyor" olarak kalamaz**: "Kullanıcı Kimliği — Uygulama İşlevi, izleme yok" beyan edilir
  ([../appstore/privacy.md](../appstore/privacy.md)).

## 8. Yayına alma (kullanıcı onayıyla)

1. CloudKit Console → Development → şemayı [social.ckdb](cloudkit/social.ckdb) ile genişlet; `_icloud`/`_creator` rollerini doğrula.
2. İki gerçek iCloud hesabı ve iki cihazla: bağlantı, kullanıcı adı isteği, kabul/ret, oda, ayrılma, engelleme, silme.
3. Production'a deploy. TestFlight Production ortamını kullanır: deploy'dan önce Sosyal orada hata verir.
4. App Store Connect gizlilik etiketini ve inceleme notlarını güncelle.
