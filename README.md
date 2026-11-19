# Fokus

YKS'ye hazırlanan öğrenciler için ücretsiz, reklamsız ve açık kaynak çalışma takip uygulaması.

- **Odak:** Kronometreyle odak oturumları, molalar, ortalama oturum ve mola süreleri
- **Konu analizi:** Ders/konu bazlı test sonuçları, doğru-yanlış-net takibi
- **Kitap takibi:** Kaynak kitaplarda nereye kadar gelindiği
- **Görevler:** Günlük rutinler ve ödevler
- **Sosyal:** Arkadaşlarla paralel odak oturumları

Veriler cihazda tutulur; iPhone ve iPad arasında iCloud (CloudKit) ile senkronize olur. Giriş zorunlu değildir; istersen "Apple ile Giriş" kullanabilirsin.

## Durum

1. Web prototipi (tasarım ve işleyiş) — `web/` — **iskelet hazır**: rotalar, veri katmanı sözleşmeleri, tasarım sistemi temeli, CI. Modüller geliştiriliyor.
2. Native iOS/iPadOS uygulaması (SwiftUI + SwiftData + CloudKit) — sonra. Geçiş planı: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Geliştirme

```bash
cd web
npm ci
npm run dev   # http://localhost:5173
```

Node.js ≥ 22.12 gerekir (`.nvmrc`: 26). Tüm komutlar: [web/README.md](web/README.md).

| Alan            | Teknoloji                                                                          |
| --------------- | ---------------------------------------------------------------------------------- |
| Arayüz          | React 19, TypeScript 6 (strict), Vite 8, Tailwind CSS 4, lucide-react              |
| Yönlendirme     | React Router 7 (data mode)                                                         |
| Veri            | IndexedDB — Dexie 4 + dexie-react-hooks; UI durumu için zustand 5                  |
| Senkron / giriş | Web'de mock (`SyncService`, `AuthService`); native'de CloudKit ve Apple ile Giriş  |
| Test            | Vitest + Testing Library + fake-indexeddb, Playwright (iPhone + iPad)              |
| Kalite          | ESLint (flat config, typescript-eslint, modül sınırları), Prettier, GitHub Actions |

Belgeler:

- [CLAUDE.md](CLAUDE.md) — proje kuralları, modül sahipliği ve sınırları
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — mimari, veri akışı, Swift/CloudKit eşlemesi
- [CONTRIBUTING.md](CONTRIBUTING.md) — katkı rehberi

## Lisans

[MIT](LICENSE)
