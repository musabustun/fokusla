import FokusDomain
import Foundation

// Paketle gelen gömülü kitap kütüphanesi (`Resources/book-library.json`). Kaynak web kataloğudur
// (`web/src/library/`); dosya `npm run export:ios-library` ile üretilir, elle düzenlenmez.

extension BookLibrary {
    public enum LoadError: Error, Equatable {
        case resourceMissing
    }

    /// Paket kaynağından kataloğu yükler.
    public static func bundled() throws -> BookLibrary {
        guard let url = Bundle.module.url(forResource: "book-library", withExtension: "json") else {
            throw LoadError.resourceMissing
        }
        return try JSONDecoder().decode(BookLibrary.self, from: Data(contentsOf: url))
    }
}
