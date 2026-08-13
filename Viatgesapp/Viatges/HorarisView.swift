import SwiftUI
import SwiftData

/// Horaris de transport del viatge (avió, tren, vaixell, cotxe, autobús)
struct HorarisView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge

    @State private var mostrarNou = false
    @State private var horariPerEditar: Horari?

    private var pendents: [Horari] { viatge.horarisLlista.filter { !$0.completat } }
    private var completats: [Horari] { viatge.horarisLlista.filter(\.completat) }

    var body: some View {
        List {
            Section("Propers") {
                ForEach(pendents) { horari in
                    filaHorari(horari)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(pendents[index]) }
                }
                .onMove(perform: moure)

                if pendents.isEmpty {
                    Text("Cap horari pendent. Prem ＋.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if !completats.isEmpty {
                Section("Completat") {
                    ForEach(completats) { horari in
                        filaHorari(horari)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(completats[index]) }
                    }
                }
            }
        }
        .navigationTitle("Horaris")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Button {
                    mostrarNou = true
                } label: {
                    Label("Nou horari", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarNou) {
            HorariFormView(viatge: viatge)
        }
        .sheet(item: $horariPerEditar) { horari in
            HorariFormView(viatge: viatge, horari: horari)
        }
    }

    @ViewBuilder
    private func filaHorari(_ horari: Horari) -> some View {
        HStack(spacing: 10) {
            IconaEmoji(emoji: horari.emojiTransport, mida: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(horari.origen) → \(horari.desti)")
                    .font(.title3.weight(.semibold))
                    .strikethrough(horari.completat)
                    .foregroundStyle(horari.completat ? .secondary : .primary)
                Text(horari.dataHora.formatCatala(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if !horari.duracio.isEmpty {
                    Text("Durada: \(horari.duracio)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !horari.notes.isEmpty {
                    Text(horari.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button {
                horari.completat.toggle()
            } label: {
                Image(systemName: horari.completat ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(horari.completat ? .green : .secondary)
            }
            .buttonStyle(.borderless)
            .help(horari.completat ? "Torna a propers" : "Marca com a completat")
            Button {
                horariPerEditar = horari
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Edita", systemImage: "pencil") { horariPerEditar = horari }
            Button(horari.completat ? "Torna a propers" : "Marca com a completat",
                   systemImage: "checkmark.circle") {
                horari.completat.toggle()
            }
            Button("Esborra l'horari", systemImage: "trash", role: .destructive) {
                context.delete(horari)
            }
        }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var llista = pendents
        llista.move(fromOffsets: origen, toOffset: desti)
        for (index, horari) in llista.enumerated() { horari.ordre = index }
    }
}

// MARK: - Formulari d'un horari

struct HorariFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var horari: Horari?

    @State private var tipus = TipusTransport.avio.rawValue
    @State private var origen = ""
    @State private var desti = ""
    @State private var dataHora = Date()
    @State private var duracio = ""
    @State private var notes = ""

    private var potDesar: Bool {
        !origen.trimmingCharacters(in: .whitespaces).isEmpty &&
        !desti.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Mitjà de transport") {
                    Picker("Transport", selection: $tipus) {
                        ForEach(TipusTransport.allCases, id: \.rawValue) { transport in
                            Text("\(transport.emoji) \(transport.rawValue)")
                                .tag(transport.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Trajecte") {
                    TextField("Lloc de sortida (p. ex. Barcelona)", text: $origen)
                        .font(.title3)
                    TextField("Lloc d'arribada (p. ex. Tòquio)", text: $desti)
                        .font(.title3)
                }
                Section("Dia i hora de sortida") {
                    DatePicker("Sortida", selection: $dataHora)
                }
                Section("Durada (opcional)") {
                    TextField("p. ex. 14 h 30 min", text: $duracio)
                }
                Section("Notes (opcional)") {
                    TextField("Seient, terminal, localitzador...", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(horari == nil ? "Nou horari" : "Edita l'horari")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { desar() }
                        .disabled(!potDesar)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .onAppear {
                guard let horari else {
                    dataHora = viatge.dataInici
                    return
                }
                tipus = horari.tipus
                origen = horari.origen
                desti = horari.desti
                dataHora = horari.dataHora
                duracio = horari.duracio
                notes = horari.notes
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 540)
        #endif
    }

    private func desar() {
        let origenNet = origen.trimmingCharacters(in: .whitespaces)
        let destiNet = desti.trimmingCharacters(in: .whitespaces)

        if let horari {
            horari.tipus = tipus
            horari.origen = origenNet
            horari.desti = destiNet
            horari.dataHora = dataHora
            horari.duracio = duracio
            horari.notes = notes
        } else {
            let nou = Horari(tipus: tipus, origen: origenNet, desti: destiNet,
                             dataHora: dataHora, duracio: duracio, notes: notes, viatge: viatge)
            nou.ordre = viatge.horarisLlista.count
            context.insert(nou)
        }
        dismiss()
    }
}
