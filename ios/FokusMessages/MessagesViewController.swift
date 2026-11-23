import FokusDesign
import Messages
import SwiftUI
import UIKit

/// Fokus iMessage uygulaması: "bugün çalıştım" kartı ve sunucusuz oda daveti. Mesajlar yalnızca
/// kullanıcının "gönder"ine basmasıyla çıkar; uzantı App Group deposunu yalnızca okur.
final class MessagesViewController: MSMessagesAppViewController {
    private let model = MessagesModel()
    private var hosting: UIHostingController<AnyView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        FokusFonts.registerAll()
        let actions = MessagesActions(
            insert: { [weak self] message in self?.insert(message) },
            open: { [weak self] url in self?.extensionContext?.open(url) },
            expand: { [weak self] in self?.requestPresentationStyle(.expanded) })
        let root = AnyView(MessagesRootView(model: model, actions: actions).fokusTheme())
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
        hosting = host
    }

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        model.reload()
        model.select(conversation.selectedMessage)
        model.isExpanded = presentationStyle == .expanded
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        model.select(message)
        requestPresentationStyle(.expanded)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        model.isExpanded = presentationStyle == .expanded
    }

    /// Mesajı yazı alanına koyar (gönderilmez); ardından kullanıcının gönder düğmesini görmesi için küçülür.
    private func insert(_ message: MSMessage) {
        activeConversation?.insert(message) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.model.errorText = "Mesaj hazırlanamadı: \(error.localizedDescription)"
                    return
                }
                self?.model.joinMessageInserted = true
                self?.requestPresentationStyle(.compact)
            }
        }
    }
}

/// SwiftUI'den görünüm denetleyicisine giden eylemler.
struct MessagesActions {
    var insert: (MSMessage) -> Void
    var open: (URL) -> Void
    var expand: () -> Void
}
