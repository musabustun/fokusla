import FokusAudio
import FokusDesign
import SwiftUI

/// GEÇİCİ İSKELET — Spotify işi gerçek arayüzle (bağlan, çalan parça, kontroller, "Spotify'da aç"
/// bağlantısı) bu dosyanın yerine geçer.
struct FocusMusicSection: View {
    let registry: MusicProviderRegistry

    var body: some View {
        Text("Müzik").fokusTextStyle(.headline).foregroundStyle(.fkLabel)
    }
}
