# Fokus tasarım sistemi (`@/ui`)

iOS hissi veren, sakin ve token tabanlı bileşenler. Web prototipi daha sonra SwiftUI'a **birebir**
taşınacağı için her renk/boyut/yarıçap adlandırılmış bir token'dan gelir ve her bileşenin bir
SwiftUI karşılığı vardır. Feature'lar yalnızca `@/ui` public API'sini (`src/ui/index.ts`) import eder.

> Kural: bileşenlerde ve ekranlarda ham hex, `text-[13px]`, `bg-white` gibi değerler kullanılmaz.
> Tailwind'in varsayılan renk/yazı/yarıçap ölçekleri kapalıdır; yalnızca aşağıdaki token sınıfları
> vardır. Görünür metin Türkçe, kod tanımlayıcıları İngilizcedir.

## Token'lar

Kaynak: `tokens.ts` (TypeScript, SwiftUI eşlemesi) ve `tokens.css` (`--fk-*` değişkenleri).
`tokens.test.ts` ikisinin senkron olduğunu ve WCAG AA kontrastını doğrular. Yeni renk eklerken
**her iki dosyaya** ve gerekiyorsa `CONTRAST_PAIRS` listesine ekle.

### Renkler (`bg-*`, `text-*`, `border-*`, `stroke-*`)

| Token              | Açık        | Koyu        | iOS karşılığı / kullanım                                       | SwiftUI                     |
| ------------------ | ----------- | ----------- | -------------------------------------------------------------- | --------------------------- |
| `background`       | `#F2F2F7`   | `#000000`   | systemGroupedBackground — ekran zemini                         | `Color("Background")`       |
| `surface`          | `#FFFFFF`   | `#1C1C1E`   | secondarySystemGroupedBackground — kart, liste                 | `Color("Surface")`          |
| `surface-elevated` | `#FFFFFF`   | `#2C2C2E`   | Sheet/üst katman                                               | `Color("SurfaceElevated")`  |
| `fill`             | `#E3E3E8`   | `#38383A`   | systemFill — segment rayı, basılı satır, halka izi             | `Color("Fill")`             |
| `control-thumb`    | `#FFFFFF`   | `#636366`   | Seçili segment                                                 | `Color("ControlThumb")`     |
| `label`            | `#1C1C1E`   | `#FFFFFF`   | Birincil metin                                                 | `Color("Label")`            |
| `secondary-label`  | `#5F5F66`   | `#AEAEB2`   | İkincil metin (AA uyumlu, iOS'tan koyu)                        | `Color("SecondaryLabel")`   |
| `tertiary-label`   | `#7C7C82`   | `#8E8E93`   | **Yalnızca** ikon/chevron/devre dışı (3:1) — gövde metni değil | `Color("TertiaryLabel")`    |
| `separator`        | `#C6C6C8`   | `#38383A`   | Ayraç çizgileri                                                | `Color("Separator")`        |
| `accent`           | `#4B48D6`   | `#9895FF`   | Tint (indigo); bağlantı, seçili sekme, dolu buton              | `Color("Accent")` / `.tint` |
| `accent-contrast`  | `#FFFFFF`   | `#0B0A2E`   | `accent` zemin üzerindeki metin                                | `Color("AccentContrast")`   |
| `accent-subtle`    | `#E9E8FB`   | `#25234D`   | Tinted buton zemini                                            | `Color("AccentSubtle")`     |
| `success`          | `#1F7A35`   | `#30D158`   | Başarı metni/ikonu                                             | `Color("Success")`          |
| `warning`          | `#A35200`   | `#FFB340`   | Uyarı metni/ikonu                                              | `Color("Warning")`          |
| `danger`           | `#C9001A`   | `#FF6961`   | Yıkıcı eylem, hata                                             | `Color("Danger")`           |
| `danger-subtle`    | `#FCE8EA`   | `#3D1C1E`   | Destructive buton zemini                                       | `Color("DangerSubtle")`     |
| `scrim`            | `#00000066` | `#00000099` | Modal arka perdesi                                             | `Color("Scrim")`            |

iOS'un varsayılan mavisi (`#007AFF`) beyaz üzerinde ~4.0:1 olduğu için AA'yı geçmez; bu yüzden
accent daha koyu bir indigodur. Ölçülen oranlar (açık / koyu): `label` zemin üzerinde 15.3 / 21.0,
yüzey üzerinde 17.0 / 17.0; `accent` zemin üzerinde 5.9 / 8.1, yüzey üzerinde 6.6 / 6.6;
`accent-contrast` accent üzerinde 6.6 / 7.4.

### Tipografi (`text-*`, iOS Dynamic Type)

| Sınıf              | Boyut/satır | Ağırlık | SwiftUI                            |
| ------------------ | ----------- | ------- | ---------------------------------- |
| `text-large-title` | 34/41       | 700     | `.font(.largeTitle.bold())`        |
| `text-title1`      | 28/34       | 700     | `.font(.title.bold())`             |
| `text-title2`      | 22/28       | 700     | `.font(.title2.bold())`            |
| `text-title3`      | 20/25       | 600     | `.font(.title3.weight(.semibold))` |
| `text-headline`    | 17/22       | 600     | `.font(.headline)`                 |
| `text-body`        | 17/22       | 400     | `.font(.body)`                     |
| `text-callout`     | 16/21       | 400     | `.font(.callout)`                  |
| `text-subheadline` | 15/20       | 400     | `.font(.subheadline)`              |
| `text-footnote`    | 13/18       | 400     | `.font(.footnote)`                 |
| `text-caption`     | 12/16       | 400     | `.font(.caption)`                  |

Boyutlar `rem` cinsindendir (tarayıcı yazı boyutuyla ölçeklenir). Yazı ailesi sistem fontudur
(SF Pro). Gövde varsayılanı `text-body text-label`.

### Boşluk, yarıçap, dokunma hedefi

- Boşluk: 4pt ızgarası — Tailwind sayıları (`p-1` = 4px, `p-4` = 16px, `gap-3` = 12px).
- Yarıçap: `rounded-sm` 8, `rounded-md` 12, `rounded-lg` 16, `rounded-xl` 22, `rounded-full`.
- Minimum dokunma hedefi 44px: `min-h-11` (tüm etkileşimli bileşenler bunu uygular).
- Kırılımlar: `md` = 768px (iPad, kenar çubuğu), `lg` = 1024px.
- Odak halkası global: `:focus-visible` → 2px `accent` dış çizgi.

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

SwiftUI: filled → `.borderedProminent`, tinted → `.bordered`, plain → `.plain`/`.borderless`,
destructive → `.bordered` + `role: .destructive`.

**Bağlantıyı buton gibi göstermek:** `buttonStyles({ variant, size, fullWidth })` sınıf üretir:
`<Link to={ROUTES.focus} className={buttonStyles({ variant: 'tinted' })}>Odakla</Link>`.

### `Card` → `GroupBox` / yuvarlatılmış `VStack` + `.background(Color("Surface"))`

`{ title?: string; trailing?: ReactNode; children; ...HTMLAttributes }`. `title` verilirse `<h2>`
gösterilir ve kart `<section aria-labelledby>` olur. 16px iç boşluk, `rounded-lg`, `bg-surface`.

### `ListSection` + `ListRow` → `List { Section(header:footer:) { … } }.listStyle(.insetGrouped)`

```tsx
<ListSection header="Hakkında" footer="Fokus ücretsiz ve reklamsızdır.">
  <ListRow title="Sürüm" value="0.1.0" />
  <ListRow title="Tema" icon={<Palette className="size-5.5" />} accessory={<SegmentedControl … />} />
  <ListRow title="Yeni görev" onClick={openSheet} />
  <ListRow title="Kitaplar" render={(props) => <Link to={ROUTES.books} {...props} />} />
</ListSection>
```

`ListSection`: `{ header?: string; footer?: ReactNode; children; className? }` — `<section>` +
`<h2>` (küçük gri başlık) + `<ul>`. Çocukları **yalnızca `ListRow`** olmalıdır.

`ListRow` (`<li>` render eder):

| Prop        | Açıklama                                                                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| `title`     | Birincil metin (zorunlu)                                                                                                 |
| `subtitle`  | Altında ikincil metin                                                                                                    |
| `icon`      | Soldaki dekoratif ikon (accent renkli, ayraç ikona göre içeriden başlar)                                                 |
| `value`     | Sağda ikincil metin                                                                                                      |
| `accessory` | Sağda özel denetim (SegmentedControl, ileride Toggle)                                                                    |
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

### `SegmentedControl<T extends string>` → `Picker(…).pickerStyle(.segmented)`

```tsx
<SegmentedControl aria-label="Tema" options={[{ value: 'light', label: 'Açık' }, …]}
                  value={preference} onChange={setPreference} />
```

`{ options: readonly { value: T; label: string }[]; value: T; onChange: (v: T) => void;
'aria-label': string (zorunlu); fullWidth?; className? }`. `radiogroup`/`radio` semantiği, roving
tabindex; ←/↑ ve →/↓ seçer ve odaklar (uçlarda başa sarar), Home/End ilk/son.

### `Toggle` → `Toggle(isOn:)`

```tsx
<ListRow
  title="iCloud senkronu"
  accessory={<Toggle aria-label="iCloud senkronu" checked={on} onChange={setOn} />}
/>
```

`{ checked: boolean; onChange: (checked: boolean) => void; 'aria-label': string (zorunlu);
disabled?; className? }`. `role="switch"` + `aria-checked`; Boşluk/Enter ile değişir. Görsel boyut 51×31,
dokunma alanı ≥44px. Hareket azaltma tercihinde geçiş animasyonu kapanır.

### `ProgressRing` → `Circle().trim(from: 0, to: value).stroke(…).rotationEffect(.degrees(-90))`

`{ value: number (0–1, sınırlanır; NaN → 0); size? = 120; strokeWidth? = 10; label?: string;
tone?: 'accent' | 'success'; children? (ortadaki içerik); className? }`. `label` verilirse
`role="progressbar"` + `aria-valuenow` (0–100, yuvarlanmış) / `aria-valuemin=0` / `aria-valuemax=100`;
verilmezse `aria-hidden` (değeri metin olarak başka yerde ver). `clampProgress()` da dışa açıktır.

### `ProgressBar` → `ProgressView(value:).progressViewStyle(.linear)`

```tsx
<ProgressBar value={summary.ratio ?? 0} label="Kitap ilerlemesi" tone="success" />
```

`{ value: number (0–1, sınırlanır; NaN → 0); label?: string; tone?: 'accent' | 'success';
size?: 'small' (4px, liste satırı) | 'medium' (8px, varsayılan); className? }`. Erişilebilirlik
`ProgressRing` ile aynıdır: `label` varsa `role="progressbar"` + `aria-valuenow` (0–100), yoksa
`aria-hidden`. Hareket azaltma açıkken genişlik animasyonu yapılmaz.

### `EmptyState` → `ContentUnavailableView(title, systemImage:, description:)`

`{ icon?: ReactNode; title: string; message?: ReactNode; action?: ReactNode; className? }`.
Ortalanmış; başlık `<h2>`. `action` için `<Button>` ya da `buttonStyles()` ile bir `<Link>`.

### `ScreenHeader` → `.navigationTitle(title)` + `.navigationBarTitleDisplayMode(.large)`

`{ title: string; subtitle?: ReactNode; actions?: ReactNode; className? }` — ekranın tek `<h1>`'i
(`text-large-title`), altında ikincil alt başlık, sağda eylemler (ör. `variant="plain"` butonlar →
`.toolbar`). Her ekran bununla başlar.

## Tema

`ThemeProvider` (uygulamada bir kez, `App.tsx`'te) çözümlenen temayı `<html data-theme>` ve
`color-scheme` olarak uygular, sistem temasını (`prefers-color-scheme`) izler. `index.html`'deki
satır içi betik ilk boyamada doğru temayı ayarlar.

```ts
const { preference, resolved, setPreference } = useTheme()
// preference: 'system' | 'light' | 'dark'  ·  resolved: 'light' | 'dark'
```

Tercih cihaza özeldir (senkronize edilmez): `localStorage['fokus.theme']` (`THEME_STORAGE_KEY`).
SwiftUI: `@AppStorage("fokus.theme")` + `.preferredColorScheme(...)`.

## Yardımcılar

- `cx(...classes)` — koşullu sınıf birleştirme.
- `tokens` — `import { tokens } from '@/ui'` → `tokens.COLORS`, `tokens.TYPE_SCALE`, `tokens.RADII`…
- `contrastRatio()` (`src/ui/contrast.ts`) — WCAG kontrast oranı (testlerde kullanılır).
