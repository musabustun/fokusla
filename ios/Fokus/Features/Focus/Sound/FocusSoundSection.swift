import FokusAudio
import FokusDesign
import SwiftUI

/// GEÇİCİ İSKELET — ses motoru işi gerçek arayüzle (ses seçici, ses seviyesi, uyku zamanlayıcısı,
/// karıştırma anahtarı) bu dosyanın yerine geçer.
struct FocusSoundSection: View {
    let sound: any FocusSoundControlling

    var body: some View {
        Text("Odak sesleri").fokusTextStyle(.headline).foregroundStyle(.fkLabel)
    }
}
