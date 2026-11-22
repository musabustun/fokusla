import Observation
import SwiftUI

/// Kabuk gezinme durumu: seçili bölüm. Ekranlar (ör. Bugün'ün "Odak başlat" düğmesi) başka bir
/// bölüme geçmek için bunu ortamdan okur; böylece `Features/<Modül>` birbirinin tipine dokunmaz.
/// `AppShell` bir tane oluşturup ortama koyar; iPhone sekmesi ve iPad kenar çubuğu aynı değeri kullanır.
@MainActor @Observable
final class AppNavigation {
    var selection: AppSection

    init(selection: AppSection = .today) {
        self.selection = selection
    }

    /// `section`'a geçer. iPhone'da tab bar'da olmayan bölümler (Kitaplar, Sosyal) için
    /// `NavigationLink(value:)` kullan; bunlar sekme olarak seçilemez.
    func open(_ section: AppSection) {
        selection = section
    }
}
