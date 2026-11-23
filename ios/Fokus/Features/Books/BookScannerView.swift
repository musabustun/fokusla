import SwiftUI
import UIKit
import VisionKit

/// `DataScannerViewController` sarmalayıcısı: yalnızca EAN-13. İlk okumada titreşim ve sesli duyuru
/// verir, `onScan` ile ham metni iletir. Görüntü cihazdan çıkmaz.
struct BookScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onFailure: () -> Void

    /// Cihaz tarayıcıyı destekliyor ve kamera kullanılabilir mi (simülatör/eski cihaz/izin yok → hayır).
    @MainActor static var isUsable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        guard !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            onFailure()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: BookScannerView
        private var hasScanned = false

        init(parent: BookScannerView) { self.parent = parent }

        func dataScanner(
            _ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasScanned else { return }
            for case .barcode(let barcode) in addedItems {
                guard let value = barcode.payloadStringValue, !value.isEmpty else { continue }
                hasScanned = true
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                UIAccessibility.post(notification: .announcement, argument: "Barkod okundu")
                dataScanner.stopScanning()
                parent.onScan(value)
                return
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            parent.onFailure()
        }
    }
}
