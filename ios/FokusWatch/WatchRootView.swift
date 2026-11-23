import SwiftUI

/// İki sayfa, dikey kaydırma: Odak ve Bugün. Odak sürerken açılış sayfası her zaman Odak'tır.
struct WatchRootView: View {
    var body: some View {
        NavigationStack {
            TabView {
                FocusPage()
                TodayPage()
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
