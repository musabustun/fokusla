import FokusDomain
import Testing

@testable import FokusData

struct BookLibraryCatalogTests {
    @Test func bundledCatalogDecodes() throws {
        let library = try BookLibrary.bundled()
        #expect(library.version >= 1)
        #expect(library.updatedAt.count == 10)
    }

    @Test func emptyCatalogFindsNothing() throws {
        let library = try BookLibrary.bundled()
        if library.books.isEmpty {
            #expect(BookLibraryLookup.find(in: library, barcode: "9781234567897") == nil)
        }
    }
}
