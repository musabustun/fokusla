## Özet

<!-- Bu PR neyi, neden değiştiriyor? İlgili modül: today / focus / analysis / books / tasks / social / settings / onboarding -->

## Değişiklikler

-

### Ortak dosyalar

<!-- domain/types.ts, data/repository.ts, data/dexie/db.ts, app/router.tsx, app/routes.ts, ui/ değiştiyse ne eklendiğini yaz. Yoksa "Yok". -->

## Test planı

- [ ] `npm run lint`
- [ ] `npm run format:check`
- [ ] `npm run typecheck`
- [ ] `npm test` (dokunulan kodda kapsam ≥ %80)
- [ ] `npm run build`
- [ ] `npm run e2e` (ekran/akış değiştiyse)
- [ ] 390px (iPhone) ve 1024px (iPad) genişlikte, açık ve koyu temada elle kontrol edildi

## Ekran görüntüleri

| iPhone | iPad |
| ------ | ---- |
|        |      |

## Kontrol listesi

- [ ] `domain/types.ts` değiştiyse `docs/ARCHITECTURE.md` eşleme tablosu güncellendi
- [ ] Dexie şeması değiştiyse yeni `db.version(n + 1)` bloğu eklendi (mevcut bloklar değişmedi)
- [ ] Başka bir feature'dan import yok; ortak kod ortak katmanda
- [ ] Arayüz metinleri Türkçe, kod tanımlayıcıları İngilizce
