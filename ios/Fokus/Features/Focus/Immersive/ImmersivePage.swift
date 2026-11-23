import FokusData
import FokusDesign
import Foundation

/// Tam ekran görünümün sayfa/tercih saklama sabitleri. Sayfa türü `StandByPage` (FokusDesign); burada yalnızca
/// UserDefaults anahtarları ve ortak yardımcılar durur.
enum ImmersiveStorage {
    /// Son seçilen sayfanın (`StandByPage.rawValue`) saklandığı anahtar. UI testi: `-FokusUITestImmersivePage <raw>`.
    static let pageKey = "fokus.focus.immersivePage"
    static let defaultPage: StandByPage = .stopwatch

    /// StandBy tercihlerinin saklandığı defaults: App Group (varsa), yoksa standart.
    static var preferencesDefaults: UserDefaults {
        UserDefaults(suiteName: FokusAppGroup.identifier) ?? .standard
    }
}

extension Array where Element == StandByPage {
    /// Verilen sayfanın listedeki 0 tabanlı sırası (yoksa 0).
    func position(of page: StandByPage) -> Int { firstIndex(of: page) ?? 0 }

    /// `page`'e `offset` kadar kayar; uçlarda durur.
    func advanced(from page: StandByPage, by offset: Int) -> StandByPage {
        guard !isEmpty else { return page }
        return self[Swift.min(Swift.max(position(of: page) + offset, 0), count - 1)]
    }
}
