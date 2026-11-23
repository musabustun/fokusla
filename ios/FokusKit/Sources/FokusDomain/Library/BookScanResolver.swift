import Foundation

/// Barkod okutma / elle girişin sonucu (Kitaplar → "+" → Barkod okut).
public enum BookScanOutcome: Sendable, Equatable {
    /// Barkod geçerli bir EAN-13'e çevrilemedi.
    case invalid
    /// Kullanıcının kitaplığında aynı barkodlu kitap zaten var.
    case existing(bookId: UUID)
    /// Gömülü katalogda bulundu.
    case found(ResolvedLibraryBook)
    /// Katalogda yok; form yalnızca (normalize) barkodla açılır.
    case notFound(barcode: String)
}

/// Barkod akışının saf mantığı: normalize → mevcut kitap → katalog → bulunamadı.
public enum BookScanResolver {
    /// - Parameters:
    ///   - raw: Ham metin (kamera ya da elle giriş).
    ///   - library: Gömülü katalog.
    ///   - existingBooks: Normalize barkod → kullanıcının kitap kimliği.
    public static func resolve(
        _ raw: String, library: BookLibrary, existingBooks: [String: UUID]
    ) -> BookScanOutcome {
        guard let barcode = Barcode.normalize(raw) else { return .invalid }
        if let bookId = existingBooks[barcode] { return .existing(bookId: bookId) }
        if let book = BookLibraryLookup.find(in: library, barcode: barcode) {
            return .found(book.resolved(barcode: barcode))
        }
        return .notFound(barcode: barcode)
    }
}
