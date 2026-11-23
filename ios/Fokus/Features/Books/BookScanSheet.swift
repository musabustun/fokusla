import AVFoundation
import FokusDesign
import FokusDomain
import SwiftUI
import VisionKit

/// Barkod okutma sayfası: kamera (destekleniyorsa) ya da elle giriş. Geçerli bir barkodla
/// `onOutcome` çağrılır (`.invalid` hiç iletilmez; satır içi hata gösterilir).
struct BookScanSheet: View {
    private enum Mode { case camera, manual }

    private static let invalidMessage = "Geçerli bir barkod değil. 13 haneli numarayı kontrol et."

    let resolve: (String) -> BookScanOutcome
    let onOutcome: (BookScanOutcome) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var mode: Mode = BookScannerView.isUsable ? .camera : .manual
    @State private var text = ""
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .camera: cameraBody
                case .manual: manualBody
                }
            }
            .background(.fkBackground)
            .navigationTitle("Barkod okut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }.accessibilityIdentifier("book.scan.cancel")
                }
            }
        }
        .accessibilityIdentifier("book.scan")
        .task { await requestCameraIfNeeded() }
    }

    // MARK: Kamera

    private var cameraBody: some View {
        VStack(spacing: FokusSpacing.lg) {
            BookScannerView(
                onScan: { submit($0) },
                onFailure: { mode = .manual }
            )
            .clipShape(RoundedRectangle(cornerRadius: FokusRadius.lg))
            .accessibilityLabel("Kamera görünümü. Kitabın arkasındaki barkodu çerçevenin içine getir.")
            .accessibilityIdentifier("book.scan.camera")
            Text("Kitabın arkasındaki barkodu çerçeveye getir.")
                .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
                .multilineTextAlignment(.center)
            if let errorMessage { errorText(errorMessage) }
            Button { mode = .manual } label: { Label("Barkodu elle yaz", systemImage: "keyboard") }
                .buttonStyle(.fokusSecondary)
                .accessibilityIdentifier("book.scan.manualToggle")
        }
        .padding(.horizontal, FokusSpacing.screenHorizontal)
        .padding(.vertical, FokusSpacing.lg)
    }

    // MARK: Elle giriş

    private var manualBody: some View {
        VStack(alignment: .leading, spacing: FokusSpacing.lg) {
            Text("Kitabın arkasındaki barkodun altındaki 13 haneli numarayı yaz (ISBN).")
                .fokusTextStyle(.subheadline).foregroundStyle(.fkSecondaryLabel)
            TextField("Ör. 9781234567897", text: $text)
                .keyboardType(.numbersAndPunctuation)
                .textContentType(.none)
                .autocorrectionDisabled()
                .focused($isFieldFocused)
                .submitLabel(.search)
                .onSubmit { submit(text) }
                .onChange(of: text) { errorMessage = nil }
                .padding(.horizontal, FokusSpacing.md)
                .frame(minHeight: fokusMinTapTarget)
                .background(.fkSurface, in: RoundedRectangle(cornerRadius: FokusRadius.md))
                .accessibilityLabel("Barkod numarası")
                .accessibilityIdentifier("book.scan.field")
            if let errorMessage { errorText(errorMessage) }
            Button("Ara") { submit(text) }
                .buttonStyle(.fokusPrimary)
                .accessibilityIdentifier("book.scan.search")
            if BookScannerView.isUsable {
                Button { mode = .camera } label: { Label("Kamerayla okut", systemImage: "barcode.viewfinder") }
                    .buttonStyle(.fokusSecondary)
                    .accessibilityIdentifier("book.scan.cameraToggle")
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, FokusSpacing.screenHorizontal)
        .padding(.vertical, FokusSpacing.lg)
        .onAppear { isFieldFocused = true }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .fokusTextStyle(.subheadline).foregroundStyle(.fkDanger)
            .accessibilityIdentifier("book.scan.error")
    }

    private func submit(_ raw: String) {
        let outcome = resolve(raw)
        if outcome == .invalid {
            // Kamera bir okumadan sonra durur; geçersiz okumada elle girişe, okunan numarayla geç.
            if mode == .camera {
                text = raw
                mode = .manual
            }
            errorMessage = Self.invalidMessage
            return
        }
        onOutcome(outcome)
    }

    /// Kamera izni henüz sorulmadıysa sorar; izin verilirse kameraya geçer.
    private func requestCameraIfNeeded() async {
        guard mode == .manual, DataScannerViewController.isSupported,
            AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
        else { return }
        let isGranted = await AVCaptureDevice.requestAccess(for: .video)
        if isGranted, BookScannerView.isUsable { mode = .camera }
    }
}
