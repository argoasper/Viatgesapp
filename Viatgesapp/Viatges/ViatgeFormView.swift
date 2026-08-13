import SwiftUI
import SwiftData

/// Formulari per crear o editar un viatge
struct ViatgeFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge?

    @State private var nom = ""
    @State private var destinacio = ""
    @State private var emoji = "✈️"
    @State private var dataInici = Date()
    @State private var dataFi = Date()
    @State private var notes = ""
    @State private var mostrarEmojis = false

    private var potDesar: Bool {
        !nom.trimmingCharacters(in: .whitespaces).isEmpty ||
        !destinacio.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Icona del viatge") {
                    Button {
                        mostrarEmojis = true
                    } label: {
                        HStack(spacing: 14) {
                            Text(emoji)
                                .font(.system(size: 40))
                            Text("Tria una icona")
                                .font(.title3)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section("Nom del viatge") {
                    TextField("p. ex. Estiu 2026", text: $nom)
                        .font(.title3)
                }
                Section("Destinació") {
                    TextField("p. ex. Japó", text: $destinacio)
                        .font(.title3)
                }
                Section("Dates") {
                    DatePicker("Data d'inici", selection: $dataInici, displayedComponents: .date)
                    DatePicker("Data de tornada", selection: $dataFi, in: dataInici..., displayedComponents: .date)
                }
                Section("Notes") {
                    TextField("Notes del viatge", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle(viatge == nil ? "Nou viatge" : "Edita el viatge")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { desar() }
                        .disabled(!potDesar)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .sheet(isPresented: $mostrarEmojis) {
                EmojiPickerView(seleccio: $emoji)
            }
            .onAppear {
                guard let viatge else { return }
                nom = viatge.nom
                destinacio = viatge.destinacio
                emoji = viatge.emoji
                dataInici = viatge.dataInici
                dataFi = viatge.dataFi
                notes = viatge.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private func desar() {
        let nomNet = nom.trimmingCharacters(in: .whitespaces)
        let destinacioNeta = destinacio.trimmingCharacters(in: .whitespaces)

        if let viatge {
            viatge.nom = nomNet
            viatge.destinacio = destinacioNeta
            viatge.emoji = emoji
            viatge.dataInici = dataInici
            viatge.dataFi = dataFi
            viatge.notes = notes
        } else {
            let nou = Viatge(nom: nomNet, destinacio: destinacioNeta, emoji: emoji,
                             dataInici: dataInici, dataFi: dataFi, notes: notes)
            context.insert(nou)
        }
        dismiss()
    }
}
