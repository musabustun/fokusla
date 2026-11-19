# Fokus tasarım sistemi (`@/ui`) — "Gece mesaisi"

Ciddi ve sade: koyu öncelikli sıcak zemin, kart kutusu yerine **1px çizgiler**, **tek kehribar vurgu**
ve ekranın ana öğesi olan **büyük mono rakamlar**. Web prototipi SwiftUI'a **birebir** taşınacağı için her
renk/boyut/yarıçap/hareket adlandırılmış bir token'dan gelir ve her bileşenin bir SwiftUI karşılığı vardır
(bkz. [docs/ARCHITECTURE.md § 4.9](../../../docs/ARCHITECTURE.md)). Feature'lar yalnızca `@/ui` public
API'sini (`src/ui/index.ts`) import eder.

> Kural: bileşenlerde ve ekranlarda ham hex, `text-[13px]`, `bg-white` gibi değerler kullanılmaz.
> Tailwind'in varsayılan renk/yazı/yarıçap/harf aralığı ölçekleri kapalıdır; yalnızca aşağıdaki token
> sınıfları vardır. Görünür metin Türkçe, kod tanımlayıcıları İngilizcedir.

## İlkeler

1. **Çizgi, kutu değil.** Bölümler `border-t border-separator` + küçük mono etiketle ayrılır (`Card`,
   `ListSection`). Dolu yüzey (`surface-elevated`) yalnızca Sheet gibi üst katmanlardadır.
2. **Tek vurgu: kehribar.** Ana eylem (ekranda bir tane, `Button` filled), seçili gezinme işareti ve
   ilerleme yayı. Başka her şey nötr. Mola/başarı adaçayı (`success`), hata kırmızı (`danger`). Mor yok.
3. **Rakam ana öğedir.** Süre, net, sayfa, yüzde: `numeric` + `text-numeral-*` (JetBrains Mono, tabular)
   veya `Metric`. Birim küçük ve ikincil.
4. **Hareket anlamlıdır.** Basınca hafif küçülme, ilerleme yayının akışı, sekme değişince tek kısa
   giriş. Scroll animasyonu yok; `prefers-reduced-motion`'da hepsi durur (global kural, `tokens.css`).

## Token'lar

Kaynak: `tokens.ts` (TypeScript, SwiftUI eşlemesi) ve `tokens.css` (`--fk-*` değişkenleri).
`tokens.test.ts` ikisinin senkron olduğunu ve `CONTRAST_PAIRS` listesindeki her çiftin WCAG AA
kontrastını doğrular. Yeni renk eklerken **her iki dosyaya** ve gerekiyorsa `CONTRAST_PAIRS`'e ekle.

### Renkler (`bg-*`, `text-*`, `border-*`, `stroke-*`)

Varsayılan tema **koyu** ("gece"); açık tema ("gündüz") kullanıcı seçimidir.

| Token              | Gündüz      | Gece        | Kullanım                                                        | SwiftUI                    |
| ------------------ | ----------- | ----------- | --------------------------------------------------------------- | -------------------------- |
| `background`       | `#F5F2EA`   | `#0E0F0C`   | Ekran zemini (sıcak kırık beyaz / neredeyse siyah)              | `Color("Background")`      |
| `surface`          | `#FBF9F4`   | `#141511`   | Nadir dolu yüzey                                                | `Color("Surface")`         |
| `surface-elevated` | `#FFFDF8`   | `#1A1B17`   | Sheet / üst katman                                              | `Color("SurfaceElevated")` |
| `fill`             | `#E8E3D7`   | `#22231E`   | Hover/basılı zemin, Switch rayı                                 | `Color("Fill")`            |
| `control-thumb`    | `#1B1A16`   | `#EDEAE2`   | Seçili segment (ters renk; üstündeki metin `text-background`)   | `Color("ControlThumb")`    |
| `switch-thumb-off` | `#77736A`   | `#8A877F`   | Kapalı Switch topuzu (`fill` üzerinde ≥3:1)                     | `Color("SwitchThumbOff")`  |
| `label`            | `#1B1A16`   | `#EDEAE2`   | Birincil metin (mürekkep / kırık beyaz)                         | `Color("Label")`           |
| `secondary-label`  | `#5C5950`   | `#9A978E`   | İkincil metin, bölüm etiketi (sıcak gri, AA)                    | `Color("SecondaryLabel")`  |
| `tertiary-label`   | `#7A766C`   | `#6F6C64`   | **Yalnızca** ikon/chevron/devre dışı (3:1)                      | `Color("TertiaryLabel")`   |
| `separator`        | `#DCD6C9`   | `#2A2A25`   | Bölüm ve satır çizgileri, halka izi                             | `Color("Separator")`       |
| `separator-strong` | `#8C877B`   | `#6A675F`   | Giriş alanı, çizgili buton sınırı (≥3:1, WCAG 1.4.11)           | `Color("SeparatorStrong")` |
| `accent`           | `#FFB547`   | `#FFB547`   | Kehribar **dolgu**: ana eylem hapı, seçili işaret, bugün çubuğu | `Color("Accent")`/`.tint`  |
| `accent-contrast`  | `#1A1205`   | `#1A1205`   | `accent` üstündeki metin                                        | `Color("AccentContrast")`  |
| `accent-ink`       | `#955500`   | `#FFB547`   | Kehribar **metin/ikon/yay** (gündüzde AA için koyulaştırılmış)  | `Color("AccentInk")`       |
| `accent-subtle`    | `#F8E5C0`   | `#2A2214`   | Seyrek rozet zemini (üstünde `accent-ink`)                      | `Color("AccentSubtle")`    |
| `success`          | `#2D6A43`   | `#8FD3A6`   | Adaçayı: mola, tamamlandı, "odakta"                             | `Color("Success")`         |
| `success-contrast` | `#FFFFFF`   | `#0B1A10`   | `success` üstündeki işaret/metin                                | `Color("SuccessContrast")` |
| `warning`          | `#955500`   | `#FFB547`   | Uyarı = kehribar mürekkep (ayrı renk yok)                       | `Color("Warning")`         |
| `danger`           | `#B3261E`   | `#FF7A6B`   | Hata, yıkıcı eylem                                              | `Color("Danger")`          |
| `danger-subtle`    | `#F7E1DC`   | `#2C1613`   | Yıkıcı buton hover zemini                                       | `Color("DangerSubtle")`    |
| `scrim`            | `#1B1A1666` | `#000000B3` | Modal arka perdesi                                              | `Color("Scrim")`           |

Ölçülen oranlar (gündüz / gece, zemin üzerinde): `label` 15.6 / 16.0, `secondary-label` 6.3 / 6.6,
`accent-ink` 5.3 / 10.9, `success` 5.8 / 11.0, `danger` 5.8 / 7.6; `accent-contrast` kehribar üzerinde
10.6. Parlak kehribar (`accent`) gündüz zemininde 1.57:1 kaldığı için **gündüzde metin/çizgi olarak
kullanılmaz** — onun yerine `accent-ink`. İlerleme yayı ve çubuğu bu yüzden `accent-ink` çizer.

### Tipografi

Yerelde barındırılan yazı tipleri (`@fontsource-variable/*`, `src/index.css`; Google'a istek yok):

| Rol     | Aile                | Kullanım                                                         |
| ------- | ------------------- | ---------------------------------------------------------------- |
| display | Bricolage Grotesque | `h1`–`h3` otomatik (base katmanı); `font-display` ile elle       |
| text    | Sistem (SF Pro)     | Gövde varsayılanı                                                |
| mono    | JetBrains Mono      | `numeric` (tabular rakam) ve `eyebrow` yardımcıları; `font-mono` |

| Sınıf                | Boyut/satır | Ağırlık | Aile    | Not                                     |
| -------------------- | ----------- | ------- | ------- | --------------------------------------- |
| `text-display`       | 44/48       | 800     | display | iPad büyük başlığı (`ScreenHeader` md:) |
| `text-large-title`   | 36/40       | 800     | display | Ekran başlığı, −0.035em                 |
| `text-title1`        | 28/32       | 800     | display |                                         |
| `text-title2`        | 22/28       | 500     | display |                                         |
| `text-title3`        | 20/24       | 500     | display | Sheet başlığı, boş durum                |
| `text-headline`      | 17/22       | 600     | text    |                                         |
| `text-body`          | 17/24       | 400     | text    | Varsayılan                              |
| `text-callout`       | 16/22       | 400     | text    |                                         |
| `text-subheadline`   | 15/20       | 400     | text    |                                         |
| `text-footnote`      | 13/18       | 400     | text    |                                         |
| `text-caption`       | 12/16       | 400     | text    |                                         |
| `eyebrow` (yardımcı) | 11/16       | 500     | mono    | BÜYÜK HARF, +0.12em, ikincil renk       |
| `text-numeral-hero`  | 72/72       | 400     | mono\*  | Kronometre, Bugün toplamı               |
| `text-numeral-xl`    | 56/56       | 400     | mono\*  | Ekranın ana sayısı                      |
| `text-numeral-lg`    | 36/40       | 400     | mono\*  | `Metric` varsayılanı                    |
| `text-numeral`       | 24/30       | 400     | mono\*  | İkincil istatistik                      |
| `text-numeral-sm`    | 17/22       | 500     | mono\*  | Satır içi değer                         |

\* `text-numeral-*` yalnızca boyut taşır; aileyi `numeric` yardımcısı verir: `className="numeric text-numeral-xl"`.
Boyutlar `rem` (tarayıcı yazı boyutuyla ölçeklenir). Türkçe büyük harf `lang="tr"` sayesinde doğru (`İ`).

### Boşluk, yarıçap, hareket, dokunma hedefi

- Boşluk: 4pt ızgarası — Tailwind sayıları (`p-1` = 4px, `gap-10` = 40px). Bölümler arası cömert (`gap-10`).
- Yarıçap: `rounded-sm` 6, `rounded-md` 10, `rounded-lg` 14, `rounded-xl` 20; eylemler `rounded-full` (hap).
- Hareket (`MOTION`, `EASINGS`): basınca `active:scale-97` (120ms), renk geçişi 200ms `ease-standard`,
  ekran girişi `animate-screen-in` (240ms), sheet `animate-sheet-in` (280ms), ilerleme akışı 700ms
  `ease-emphasized`. Kendi tıklanabilir öğende:
  `transition-[background-color,transform] duration-200 ease-standard hover:bg-fill active:scale-97 motion-reduce:active:scale-100`.
- Minimum dokunma hedefi 44px: `min-h-11` (tüm etkileşimli bileşenler bunu uygular).
- Kırılımlar: `md` = 768px (iPad, kenar çubuğu), `lg` = 1024px (iki sütun).
- Odak halkası global: `:focus-visible` → 2px `accent-ink` dış çizgi.

## Bileşenler

### `Button` → `Button` + `.buttonStyle(.borderedProminent / .bordered / .plain)`

```tsx
<Button variant="filled" size="large" fullWidth onClick={start} icon={<Play />}>
  Başlat
</Button>
```

| Prop        | Tip                                                       | Varsayılan |
| ----------- | --------------------------------------------------------- | ---------- |
| `variant`   | `'filled' \| 'tinted' \| 'plain' \| 'destructive'`        | `'filled'` |
| `size`      | `'small' \| 'medium' \| 'large'`                          | `'medium'` |
| `fullWidth` | `boolean`                                                 | `false`    |
| `loading`   | `boolean` — devre dışı + `aria-busy` + dönen gösterge     | `false`    |
| `icon`      | `ReactNode` — etiketin solunda (dekoratif)                | —          |
| …           | tüm `<button>` nitelikleri; `type` varsayılanı `"button"` |            |

Görünüm: hepsi hap (`rounded-full`) ve basınca küçülür. filled = kehribar dolgu (ekranın ana eylemi,
bir tane); tinted = 1px `separator-strong` çizgili, nötr metin (ikincil eylem); plain = kehribar mürekkep
metin, hover'da `fill`; destructive = kırmızı çizgili.
SwiftUI: filled → `.borderedProminent` + `.buttonBorderShape(.capsule)`, tinted → `.bordered` + capsule
stroke, plain → `.plain`/`.borderless`, destructive → `.bordered` + `role: .destructive`.

**Bağlantıyı buton gibi göstermek:** `buttonStyles({ variant, size, fullWidth })` sınıf üretir:
`<Link to={ROUTES.focus} className={buttonStyles({ variant: 'tinted' })}>Odakla</Link>`.

### `AppleSignInButton` → `SignInWithAppleButton` (AuthenticationServices)

```tsx
<AppleSignInButton loading={busy} onClick={signIn} />
```

`{ onClick; loading?; disabled?; label? = "Apple ile Giriş"; className? }`. Apple yönergelerine
yakın: gündüzde mürekkep (`bg-label`), gecede kırık beyaz; hap, tam genişlik, 52px yükseklik. `loading`
iken devre dışı + `aria-busy` + "Giriş yapılıyor…". Giriş isteyen her ekran (Sosyal, ileride
Ayarlar/onboarding) bunu kullanır.

### `Card` (çizgili bölüm) → `VStack` + üstte `Divider()`

`{ title?: string; trailing?: ReactNode; children; ...HTMLAttributes }`. Kutu yoktur: üstte 1px
`separator` çizgisi, `title` verilirse küçük mono bölüm etiketi (`<h2 class="eyebrow">`) ve bölüm
`<section aria-labelledby>` olur. `trailing` başlığın sağında (ör. plain "Tümü" bağlantısı).

### `Metric` → `VStack(alignment: .leading) { Text(label).eyebrow(); Text(value).numeral() }`

```tsx
<Metric
  label="Bugün"
  value="2:45"
  unit="sa"
  size="hero"
  tone="accent"
  caption="Dünden 20 dk fazla"
/>
```

`{ label; value; unit?; caption?; size?: 'hero' | 'xl' | 'lg' (varsayılan) | 'md' | 'sm';
tone?: 'default' | 'accent' | 'success'; className? }`. Etiket üstte (eyebrow), değer mono + tabular,
birim küçük ve ikincil. `tone="accent"` yalnızca ekranın ana sayısı için.

### `inputStyles()` + `FIELD_LABEL_CLASS` / `FIELD_HINT_CLASS` / `FIELD_ERROR_CLASS`

```tsx
<label htmlFor={id} className={FIELD_LABEL_CLASS}>Başlık</label>
<input id={id} className={inputStyles()} aria-invalid={Boolean(error) || undefined} />
<textarea className={inputStyles({ multiline: true })} />
```

Şeffaf zemin, 1px `separator-strong` çizgi (≥3:1), `rounded-md`, ≥44px; hover'da çizgi koyulaşır,
`aria-invalid` iken `danger`. SwiftUI: `TextField` + `.textFieldStyle(.plain)` + stroke overlay.

### `ListSection` + `ListRow` → `List { Section(header:footer:) { … } }.listStyle(.plain)`

```tsx
<ListSection header="Hakkında" footer="Fokus ücretsiz ve reklamsızdır.">
  <ListRow title="Sürüm" value="0.1.0" />
  <ListRow title="Tema" icon={<Palette className="size-5.5" />} accessory={<SegmentedControl … />} />
  <ListRow title="Yeni görev" onClick={openSheet} />
  <ListRow title="Kitaplar" render={(props) => <Link to={ROUTES.books} {...props} />} />
</ListSection>
```

`ListSection`: `{ header?: string; footer?: ReactNode; children; className? }` — `<section>` +
`<h2 class="eyebrow">` + üstü/altı çizgili `<ul>` (kutu yok). Çocukları **yalnızca `ListRow`** olmalıdır.
Satırlar 52px, aralarında ince ayraç; etkileşimli satır hover'da `fill`, basınca hafif küçülür.

`ListRow` (`<li>` render eder):

| Prop        | Açıklama                                                                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| `title`     | Birincil metin (zorunlu)                                                                                                 |
| `subtitle`  | Altında ikincil metin                                                                                                    |
| `icon`      | Soldaki dekoratif ikon (ikincil renk, ayraç ikona göre içeriden başlar)                                                  |
| `value`     | Sağda ikincil metin                                                                                                      |
| `accessory` | Sağda özel denetim (SegmentedControl, Switch)                                                                            |
| `chevron`   | `>` göstergesi; varsayılan: satır etkileşimliyse `true`                                                                  |
| `onClick`   | Satır `<button type="button">` olur                                                                                      |
| `href`      | Satır düz `<a href>` olur (router dışı/harici)                                                                           |
| `render`    | Router bağlantısı: `(props: { className, children }) => ReactElement` — `props`'u olduğu gibi `<Link>`/`<NavLink>`'e yay |

`@/ui` react-router'ı import edemez; bu yüzden router bağlantıları `render` ile verilir.
Hiçbiri verilmezse satır statik bir `<div>`'dir. SwiftUI: `NavigationLink` / `Button` / `LabeledContent`.

### `Sheet` → `.sheet(isPresented:)` (+ iPad'de `.presentationSizing(.form)`)

```tsx
<Sheet
  open={isOpen}
  onClose={() => setOpen(false)}
  title="Görev ekle"
  description="İsteğe bağlı açıklama"
  footer={<Button fullWidth>Kaydet</Button>}
>
  …form…
</Sheet>
```

`{ open: boolean; onClose: () => void; title: string; description?: string; children; footer? }`.
Yerel `<dialog>` + `showModal()`: arka plan inert, `aria-modal`, odak içeri taşınır; Esc, arka
plana tıklama ve "Kapat" düğmesi `onClose` çağırır (birden fazla çağrılabilir — idempotent tut);
kapanınca odak açan öğeye döner; açıkken sayfa kaydırması kilitlidir. <768px'de alttan sheet
(tutamaçlı), ≥768px'de ortalanmış form sheet (max 32rem). İçerik yalnızca açıkken render edilir.

### `SegmentedControl<T extends string>` → `Picker(…).pickerStyle(.segmented)` (özel stil)

```tsx
<SegmentedControl aria-label="Tema" options={[{ value: 'light', label: 'Açık' }, …]}
                  value={preference} onChange={setPreference} />
```

`{ options: readonly { value: T; label: string }[]; value: T; onChange: (v: T) => void;
'aria-label': string (zorunlu); fullWidth?; className? }`. `radiogroup`/`radio` semantiği, roving
tabindex; ←/↑ ve →/↓ seçer ve odaklar (uçlarda başa sarar), Home/End ilk/son. Görünüm: 1px çizgili
hap ray; seçili seçenek ters renk (`bg-control-thumb text-background`) — kehribar değil.

### `Switch` → `Toggle(isOn:).toggleStyle(.switch)`

```tsx
<ListRow
  title={<span id="share-presence">Durumumu paylaş</span>}
  accessory={<Switch aria-labelledby="share-presence" checked={isSharing} onChange={setSharing} />}
/>
```

| Prop                             | Tip                                                         | Varsayılan |
| -------------------------------- | ----------------------------------------------------------- | ---------- |
| `checked`                        | `boolean` (kontrollü)                                       | —          |
| `onChange`                       | `(checked: boolean) => void` — yeni değerle çağrılır        | —          |
| `aria-labelledby` / `aria-label` | Erişilebilir ad: görünür etiketin id'si ya da metin (biri!) | —          |
| `aria-describedby`               | Açıklama metninin id'si (ör. ListRow `subtitle`)            | —          |
| `disabled`, `id`, `className`    | Standart                                                    | `false`    |

`<button type="button" role="switch" aria-checked>`; tıklama, Space ve Enter değiştirir. 44×44
dokunma alanı içinde 51×31 ray (1px çizgi dahil) ve 27px topuz; hareket `prefers-reduced-motion`'da
kapanır. Renkler: açık → ray `accent` (kehribar), topuz `accent-contrast`; kapalı → ray `fill` +
`separator-strong` çizgi, topuz `switch-thumb-off`. Durum ayrıca topuzun konumuyla anlatılır.
SwiftUI: sistem `Toggle` + `.tint(Color("Accent"))`; topuz rengini sistem çizer.

### `ProgressRing` → `Circle().trim(from: 0, to: value).stroke(…).rotationEffect(.degrees(-90))`

İnce iz (`separator`) + yuvarlak uçlu yay (`accent-ink` ya da `success`); değer değişince yay 700ms akar.
`{ value: number (0–1, sınırlanır; NaN → 0); size? = 120; strokeWidth? = 6; label?: string;
tone?: 'accent' | 'success'; children? (ortadaki içerik); className? }`. `label` verilirse
`role="progressbar"` + `aria-valuenow` (0–100, yuvarlanmış) / `aria-valuemin=0` / `aria-valuemax=100`;
verilmezse `aria-hidden` (değeri metin olarak başka yerde ver). `clampProgress()` da dışa açıktır.

### `ProgressBar` → `ProgressView(value:).progressViewStyle(.linear)`

```tsx
<ProgressBar value={summary.ratio ?? 0} label="Kitap ilerlemesi" tone="success" />
```

`{ value: number (0–1, sınırlanır; NaN → 0); label?: string; tone?: 'accent' | 'success';
size?: 'small' (2px, liste satırı) | 'medium' (4px, varsayılan); className? }`. İz `separator`, dolgu
`accent-ink` ya da `success`. Erişilebilirlik
`ProgressRing` ile aynıdır: `label` varsa `role="progressbar"` + `aria-valuenow` (0–100), yoksa
`aria-hidden`. Hareket azaltma açıkken genişlik animasyonu yapılmaz.

### `EmptyState` → `ContentUnavailableView(title, systemImage:, description:)`

`{ icon?: ReactNode; title: string; message?: ReactNode; action?: ReactNode; className? }`.
Ortalanmış; ikon ince çizgili bir dairede, başlık `<h2>` (`text-title3`, Bricolage). `action` için `<Button>` ya da `buttonStyles()` ile bir `<Link>`.

### `ScreenHeader` → `.navigationTitle(title)` + `.navigationBarTitleDisplayMode(.large)`

`{ title: string; subtitle?: ReactNode; actions?: ReactNode; className? }` — ekranın tek `<h1>`'i
(`text-large-title`, iPad'de `text-display`; Bricolage 800, sıkı aralık), altında ikincil alt başlık, sağda eylemler (ör. `variant="plain"` butonlar →
`.toolbar`). Her ekran bununla başlar.

## Tema

`ThemeProvider` (uygulamada bir kez, `App.tsx`'te) çözümlenen temayı `<html data-theme>` ve
`color-scheme` olarak uygular, sistem temasını (`prefers-color-scheme`) izler. `index.html`'deki
satır içi betik ilk boyamada doğru temayı ayarlar. **Kayıtlı tercih yoksa koyu**
(`DEFAULT_THEME_PREFERENCE = 'dark'`); "Sistem" seçilirse cihazı izler.

```ts
const { preference, resolved, setPreference } = useTheme()
// preference: 'system' | 'light' | 'dark'  ·  resolved: 'light' | 'dark'
```

Tercih cihaza özeldir (senkronize edilmez): `localStorage['fokus.theme']` (`THEME_STORAGE_KEY`).
SwiftUI: `@AppStorage("fokus.theme")` + `.preferredColorScheme(...)`.

## Yardımcılar

- `cx(...classes)` — koşullu sınıf birleştirme.
- `tokens` — `import { tokens } from '@/ui'` → `tokens.COLORS`, `tokens.TYPE_SCALE`, `tokens.RADII`,
  `tokens.MOTION`, `tokens.FONT_FAMILIES`…
- Yardımcı sınıflar (`tokens.css`): `numeric` (mono + tabular rakam), `eyebrow` (bölüm etiketi).
- `contrastRatio()` (`src/ui/contrast.ts`) — WCAG kontrast oranı (testlerde kullanılır).
