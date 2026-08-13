import SwiftUI
import SwiftData

/// Apartat personalitzable (per defecte "Altres") amb llistes de comprovació
struct AltresView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge

    @State private var mostrarSelectorSeccio = false
    @State private var mostrarNovaSeccio = false
    @State private var seccioPerEditar: SeccioAltres?
    @State private var mostrarCanviNom = false
    @State private var nomApartat = ""

    var body: some View {
        List {
            Section("Llistes de comprovació") {
                ForEach(viatge.seccionsAltresLlista) { seccio in
                    filaSeccio(seccio)
                }
                .onDelete(perform: esborrar)
                .onMove(perform: moure)

                if viatge.seccionsAltresLlista.isEmpty {
                    Text("Prem ＋ per afegir llistes com Coses Casa o Varis.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    mostrarSelectorSeccio = true
                } label: {
                    Label("Afegeix llistes", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(viatge.nomApartatAltres)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Menu {
                    Button("Canvia el nom de l'apartat", systemImage: "pencil") {
                        nomApartat = viatge.nomApartatAltres
                        mostrarCanviNom = true
                    }
                    Button("Crea una llista nova", systemImage: "plus") {
                        mostrarNovaSeccio = true
                    }
                } label: {
                    Label("Més opcions", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem {
                Button {
                    mostrarSelectorSeccio = true
                } label: {
                    Label("Afegeix llista", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarSelectorSeccio) {
            SelectorSeccioView(viatge: viatge)
        }
        .sheet(isPresented: $mostrarNovaSeccio) {
            SeccioFormView(viatge: viatge)
        }
        .sheet(item: $seccioPerEditar) { seccio in
            SeccioFormView(viatge: viatge, seccio: seccio)
        }
        .alert("Canvia el nom de l'apartat", isPresented: $mostrarCanviNom) {
            TextField("Nom de l'apartat", text: $nomApartat)
            Button("Desa") {
                let net = nomApartat.trimmingCharacters(in: .whitespaces)
                if !net.isEmpty { viatge.nomApartatAltres = net }
            }
            Button("Cancel·la", role: .cancel) { }
        }
    }

    @ViewBuilder
    private func filaSeccio(_ seccio: SeccioAltres) -> some View {
        let items = viatge.itemsAltres(de: seccio.nom)
        let fets = items.filter(\.fet).count

        NavigationLink {
            SeccioDetailView(viatge: viatge, seccio: seccio)
        } label: {
            HStack(spacing: 10) {
                IconaEmoji(emoji: seccio.emoji, mida: 30)
                Text(seccio.nom)
                    .font(.title3.weight(.semibold))
                Spacer()
                if !items.isEmpty {
                    Text("\(fets)/\(items.count)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Button {
                    seccioPerEditar = seccio
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }
            .padding(.vertical, 2)
        }
        .contextMenu {
            Button("Edita la llista", systemImage: "pencil") { seccioPerEditar = seccio }
            Button("Esborra la llista", systemImage: "trash", role: .destructive) {
                esborrar(seccio)
            }
        }
    }

    private func esborrar(_ seccio: SeccioAltres) {
        for item in viatge.itemsAltres(de: seccio.nom) { context.delete(item) }
        context.delete(seccio)
    }

    private func esborrar(_ offsets: IndexSet) {
        let seccions = viatge.seccionsAltresLlista
        for index in offsets { esborrar(seccions[index]) }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var seccions = viatge.seccionsAltresLlista
        seccions.move(fromOffsets: origen, toOffset: desti)
        for (index, seccio) in seccions.enumerated() { seccio.ordre = index }
    }
}

// MARK: - Elements d'una llista

struct SeccioDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge
    @Bindable var seccio: SeccioAltres

    @State private var mostrarAfegir = false
    @State private var itemPerEditar: ItemAltres?
    @State private var textEditat = ""

    private var items: [ItemAltres] { viatge.itemsAltres(de: seccio.nom) }
    private var fets: Int { items.filter(\.fet).count }

    var body: some View {
        List {
            if !items.isEmpty {
                Section {
                    ProgressView(value: Double(fets), total: Double(items.count)) {
                        Text("\(fets) de \(items.count) fets")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .tint(.green)
                }
            }

            Section {
                ForEach(items) { item in
                    HStack(spacing: 10) {
                        Button {
                            item.fet.toggle()
                        } label: {
                            Image(systemName: item.fet ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 26))
                                .foregroundStyle(item.fet ? .green : .secondary)
                        }
                        .buttonStyle(.borderless)
                        Text(item.nom)
                            .font(.title3)
                            .strikethrough(item.fet)
                            .foregroundStyle(item.fet ? .secondary : .primary)
                        Spacer()
                        Button {
                            textEditat = item.nom
                            itemPerEditar = item
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                    .contextMenu {
                        Button("Edita", systemImage: "pencil") {
                            textEditat = item.nom
                            itemPerEditar = item
                        }
                        Button("Esborra", systemImage: "trash", role: .destructive) {
                            context.delete(item)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(items[index]) }
                }
                .onMove(perform: moure)

                if items.isEmpty {
                    Text("Cap element. Prem ＋.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("\(seccio.emoji) \(seccio.nom)")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Button {
                    mostrarAfegir = true
                } label: {
                    Label("Afegeix elements", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarAfegir) {
            AfegirAltresView(viatge: viatge, seccio: seccio)
        }
        .alert("Edita l'element", isPresented: Binding(
            get: { itemPerEditar != nil },
            set: { if !$0 { itemPerEditar = nil } }
        )) {
            TextField("Text", text: $textEditat)
            Button("Desa") {
                let net = textEditat.trimmingCharacters(in: .whitespaces)
                if !net.isEmpty { itemPerEditar?.nom = net }
                itemPerEditar = nil
            }
            Button("Cancel·la", role: .cancel) { itemPerEditar = nil }
        }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var llista = items
        llista.move(fromOffsets: origen, toOffset: desti)
        for (index, item) in llista.enumerated() { item.ordre = index }
    }
}

// MARK: - Afegir elements en bloc

struct AfegirAltresView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var seccio: SeccioAltres

    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        IconaEmoji(emoji: seccio.emoji, mida: 28)
                        Text(seccio.nom)
                            .font(.title3.weight(.semibold))
                    }
                }
                Section("Elements (un per línia)") {
                    TextField("Escriu-los, un per línia", text: $text, axis: .vertical)
                        .lineLimit(6...16)
                        .font(.body)
                }
            }
            .navigationTitle("Afegeix elements")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Afegeix") { desar() }
                        .disabled(liniesDeText(text).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 460)
        #endif
    }

    private func desar() {
        var ordre = viatge.itemsAltres(de: seccio.nom).count
        for nom in liniesDeText(text) {
            context.insert(ItemAltres(nom: nom, seccio: seccio.nom, ordre: ordre, viatge: viatge))
            ordre += 1
        }
        dismiss()
    }
}

// MARK: - Crear o editar una llista

struct SeccioFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var seccio: SeccioAltres?

    @State private var nom = ""
    @State private var emoji = "📝"
    @State private var mostrarEmojis = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Icona") {
                    Button {
                        mostrarEmojis = true
                    } label: {
                        HStack(spacing: 14) {
                            Text(emoji).font(.system(size: 40))
                            Text("Tria una icona").font(.title3)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section("Nom") {
                    TextField("Nom de la llista", text: $nom)
                        .font(.title3)
                }
            }
            .navigationTitle(seccio == nil ? "Nova llista" : "Edita la llista")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { desar() }
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .sheet(isPresented: $mostrarEmojis) {
                EmojiPickerView(seleccio: $emoji)
            }
            .onAppear {
                guard let seccio else { return }
                nom = seccio.nom
                emoji = seccio.emoji
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 340)
        #endif
    }

    private func desar() {
        let nomNet = nom.trimmingCharacters(in: .whitespaces)
        if let seccio {
            if seccio.nom != nomNet {
                for item in viatge.itemsAltres(de: seccio.nom) { item.seccio = nomNet }
            }
            seccio.nom = nomNet
            seccio.emoji = emoji
        } else {
            context.insert(SeccioAltres(nom: nomNet, emoji: emoji,
                                        ordre: viatge.seccionsAltresLlista.count, viatge: viatge))
        }
        dismiss()
    }
}

// MARK: - Selector de llistes suggerides

struct SelectorSeccioView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    @State private var mostrarNova = false

    private var pendents: [SeccioSuggerida] {
        let existents = Set(viatge.seccionsAltresLlista.map(\.nom))
        return SeccioSuggerida.allCases.filter { !existents.contains($0.rawValue) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !pendents.isEmpty {
                    Section("Suggeriments") {
                        ForEach(pendents, id: \.rawValue) { seccio in
                            Button {
                                context.insert(SeccioAltres(nom: seccio.rawValue, emoji: seccio.emoji,
                                                            ordre: viatge.seccionsAltresLlista.count,
                                                            viatge: viatge))
                            } label: {
                                HStack(spacing: 10) {
                                    IconaEmoji(emoji: seccio.emoji, mida: 28)
                                    Text(seccio.rawValue).font(.title3)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Button {
                        mostrarNova = true
                    } label: {
                        Label("Crea una llista nova", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Afegeix llistes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fet") { dismiss() }
                }
            }
            .sheet(isPresented: $mostrarNova) {
                SeccioFormView(viatge: viatge)
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }
}
