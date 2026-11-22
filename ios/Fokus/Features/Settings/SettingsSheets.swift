import FokusData
import FokusDesign
import FokusDomain
import SwiftData
import SwiftUI

/// Ayarlar'dan açılan sayfalar.
enum SettingsSheet: String, Identifiable {
    case displayName, field, deleteAccount, wipeData
    var id: String { rawValue }
}

/// Görünen ad (web `DisplayNameSheet`).
struct DisplayNameSheet: View {
    let initialName: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var name: String
    @State private var saveError: String?

    init(initialName: String, onClose: @escaping () -> Void) {
        self.initialName = initialName
        self.onClose = onClose
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Ad") {
                        TextField("Ad", text: $name, prompt: Text("Adın"))
                            .multilineTextAlignment(.trailing)
                            .textContentType(.nickname)
                            .submitLabel(.done)
                            .onSubmit(save)
                            .onChange(of: name) { _, value in
                                if value.count > ProfileRepository.displayNameMaxLength {
                                    name = String(value.prefix(ProfileRepository.displayNameMaxLength))
                                }
                            }
                            .accessibilityIdentifier("settings.name.field")
                    }
                } footer: {
                    Text("İstersen bir ad ekle; arkadaşların seni böyle görür. Boş bırakabilirsin.")
                }
                if let saveError {
                    Section { Text(saveError).foregroundStyle(.fkDanger) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.fkBackground)
            .navigationTitle("Görünen ad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", action: onClose).accessibilityIdentifier("settings.name.cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save).fontWeight(.semibold)
                        .accessibilityIdentifier("settings.name.save")
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("settings.nameSheet")
    }

    private func save() {
        do {
            try ProfileRepository(context: modelContext).setDisplayName(name)
            onClose()
        } catch {
            saveError = "Kaydedilemedi. Lütfen tekrar dene."
        }
    }
}

/// YKS alanı seçimi (web `FieldSheet`): seçim anında kaydedilir; veriler silinmez.
struct FieldSheet: View {
    let current: YksField
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FokusSpacing.md) {
                    Text("Alanını değiştirirsen AYT/YDT dersleri buna göre görünür. Mevcut verilerin silinmez.")
                        .fokusTextStyle(.subheadline)
                        .foregroundStyle(.fkSecondaryLabel)
                    VStack(spacing: 0) {
                        Divider().overlay(.fkSeparator)
                        ForEach(YksField.allCases, id: \.self) { field in
                            fieldRow(field)
                        }
                    }
                    if let saveError { SettingsMessage(text: saveError, isError: true) }
                }
                .padding(.horizontal, FokusSpacing.screenHorizontal)
                .padding(.vertical, FokusSpacing.lg)
            }
            .background(.fkBackground)
            .navigationTitle("YKS alanı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat", action: onClose).accessibilityIdentifier("settings.field.close")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("settings.fieldSheet")
    }

    private func fieldRow(_ field: YksField) -> some View {
        Button { select(field) } label: {
            VStack(spacing: 0) {
                HStack(spacing: FokusSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(field.shortLabel) · \(field.label)").fokusTextStyle(.body).foregroundStyle(.fkLabel)
                        Text(field.summary).fokusTextStyle(.footnote).foregroundStyle(.fkSecondaryLabel)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: FokusSpacing.sm)
                    if field == current {
                        Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.fkAccentInk)
                    }
                }
                .frame(minHeight: fokusMinTapTarget)
                .padding(.vertical, FokusSpacing.md)
                Divider().overlay(.fkSeparator)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.fokusRow)
        .accessibilityAddTraits(field == current ? .isSelected : [])
        .accessibilityIdentifier("settings.field.\(field.rawValue)")
    }

    private func select(_ field: YksField) {
        do {
            try ProfileRepository(context: modelContext).setField(field)
            onClose()
        } catch {
            saveError = "Alan değiştirilemedi. Lütfen tekrar dene."
        }
    }
}
