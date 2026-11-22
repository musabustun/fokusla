import CoreTransferable
import FokusData
import SwiftData
import UniformTypeIdentifiers

/// `ShareLink` için tüm veriyi JSON dosyası olarak üretir. Dosya paylaşım anında, yalnızca cihazda
/// (geçici klasörde) oluşturulur; hiçbir yere gönderilmez.
struct BackupFile: Transferable {
    let container: ModelContainer

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { backup in
            let (data, name) = try await MainActor.run {
                let service = LocalDataService(context: backup.container.mainContext)
                return (try service.exportJSON(), LocalDataService.exportFileName())
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}
