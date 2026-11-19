# Fokus — web prototipi

Fokus'un tasarımını ve davranışını netleştirmek için yazılan web prototipi. Veri tarayıcıda (IndexedDB) tutulur; senkron ve Apple ile Giriş mock'tur.

## Komutlar

| Komut                   | Ne yapar                                              |
| ----------------------- | ----------------------------------------------------- |
| `npm ci`                | Bağımlılıkları kurar                                  |
| `npm run dev`           | Geliştirme sunucusu (http://localhost:5173)           |
| `npm run build`         | Tip kontrolü + üretim derlemesi (`dist/`)             |
| `npm run preview`       | Derlemeyi yerelde sunar                               |
| `npm run typecheck`     | `tsc -b`                                              |
| `npm run lint`          | ESLint (uyarı da hata sayılır, modül sınırları dahil) |
| `npm run format`        | Prettier ile biçimlendirir                            |
| `npm run format:check`  | Biçim kontrolü (CI)                                   |
| `npm test`              | Vitest birim ve bileşen testleri                      |
| `npm run test:watch`    | Vitest izleme modu                                    |
| `npm run test:coverage` | Kapsam raporu (`coverage/`)                           |
| `npm run e2e`           | Playwright E2E (iPhone + iPad projeleri)              |

## Belgeler

- [../CLAUDE.md](../CLAUDE.md) — kurallar, klasör yapısı, modül sahipliği
- [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) — mimari ve Swift geçiş planı
- [../CONTRIBUTING.md](../CONTRIBUTING.md) — katkı rehberi
