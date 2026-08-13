import SwiftUI
import SwiftData

/// Equipatge del viatge: categories pròpies amb els seus elements
struct EquipatgeView: View {
    @Environment(\.modelContext) private var context
    @Query private var totsElsViatges: [Viatge]
    @Bindable var viatge: Viatge

    @State private var mostrarSelectorCategoria = false
    @State private var mostrarNovaCategoria = false
    @State private var categoriaPerEditar: CategoriaEquip?
    @State private var mostrarCopiar = false

    private var total: Int { viatge.equipatgeLlista.count }
    private var llestos: Int { viatge.equipatgeLlista.filter(\.empaquetat).count }

    var body: some View {
        List {
            if total > 0 {
                Section {
                    ProgressView(value: Double(llestos), total: Double(total)) {
                        Text("\(llestos) de \(total) llestos en total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .tint(.green)
                }
            }

            Section("Categories") {
                ForEach(viatge.categoriesLlista) { categoria in
                    filaCategoria(categoria)
                }
                .onDelete(perform: esborrar)
                .onMove(perform: moure)

                if viatge.categoriesLlista.isEmpty {
                    Text("Prem ＋ per afegir categories.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    mostrarSelectorCategoria = true
                } label: {
                    Label("Afegeix categories", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Equipatge")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Menu {
                    Button("Copia l'equipatge d'un altre viatge", systemImage: "square.on.square") {
                        mostrarCopiar = true
                    }
                    Button("Crea una categoria nova", systemImage: "plus") {
                        mostrarNovaCategoria = true
                    }
                } label: {
                    Label("Més opcions", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem {
                Button {
                    mostrarSelectorCategoria = true
                } label: {
                    Label("Afegeix categoria", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarSelectorCategoria) {
            SelectorCategoriaView(viatge: viatge)
        }
        .sheet(isPresented: $mostrarNovaCategoria) {
            CategoriaFormView(viatge: viatge)
        }
        .sheet(item: $categoriaPerEditar) { categoria in
            CategoriaFormView(viatge: viatge, categoria: categoria)
        }
        .sheet(isPresented: $mostrarCopiar) {
            CopiarEquipatgeView(desti: viatge, viatges: totsElsViatges)
        }
        .onAppear { inicialitzarCategories() }
    }

    // MARK: Files

    @ViewBuilder
    private func filaCategoria(_ categoria: CategoriaEquip) -> some View {
        let items = viatge.itemsEquipatge(de: categoria.nom)
        let fets = items.filter(\.empaquetat).count

        NavigationLink {
            CategoriaDetailView(viatge: viatge, categoria: categoria)
        } label: {
            HStack(spacing: 10) {
                IconaEmoji(emoji: categoria.emoji, mida: 30)
                Text(categoria.nom)
                    .font(.title3.weight(.semibold))
                Spacer()
                if !items.isEmpty {
                    Text("\(fets)/\(items.count)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Button {
                    categoriaPerEditar = categoria
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
            Button("Edita la categoria", systemImage: "pencil") { categoriaPerEditar = categoria }
            Button("Esborra la categoria", systemImage: "trash", role: .destructive) {
                esborrar(categoria)
            }
        }
    }

    // MARK: Accions

    /// Crea les categories suggerides el primer cop, i les que facin falta
    /// per als elements que ja existeixin.
    private func inicialitzarCategories() {
        var existents = Set(viatge.categoriesLlista.map(\.nom))
        var ordre = viatge.categoriesLlista.count

        for nom in Set(viatge.equipatgeLlista.map(\.categoria)) where !nom.isEmpty && !existents.contains(nom) {
            let emoji = CategoriaEquipatge(rawValue: nom)?.emoji ?? "📦"
            context.insert(CategoriaEquip(nom: nom, emoji: emoji, ordre: ordre, viatge: viatge))
            existents.insert(nom)
            ordre += 1
        }

        if !viatge.categoriesInicialitzades {
            for categoria in CategoriaEquipatge.allCases where !existents.contains(categoria.rawValue) {
                context.insert(CategoriaEquip(nom: categoria.rawValue, emoji: categoria.emoji,
                                              ordre: ordre, viatge: viatge))
                existents.insert(categoria.rawValue)
                ordre += 1
            }
            viatge.categoriesInicialitzades = true
        }
    }

    private func esborrar(_ categoria: CategoriaEquip) {
        for item in viatge.itemsEquipatge(de: categoria.nom) {
            context.delete(item)
        }
        context.delete(categoria)
    }

    private func esborrar(_ offsets: IndexSet) {
        let categories = viatge.categoriesLlista
        for index in offsets { esborrar(categories[index]) }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var categories = viatge.categoriesLlista
        categories.move(fromOffsets: origen, toOffset: desti)
        for (index, categoria) in categories.enumerated() { categoria.ordre = index }
    }
}

// MARK: - Elements d'una categoria

struct CategoriaDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge
    @Bindable var categoria: CategoriaEquip

    @State private var mostrarAfegir = false
    @State private var itemPerEditar: ItemEquipatge?

    private var items: [ItemEquipatge] { viatge.itemsEquipatge(de: categoria.nom) }
    private var fets: Int { items.filter(\.empaquetat).count }

    var body: some View {
        List {
            if !items.isEmpty {
                Section {
                    ProgressView(value: Double(fets), total: Double(items.count)) {
                        Text("\(fets) de \(items.count) llestos")
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
                            item.empaquetat.toggle()
                        } label: {
                            Image(systemName: item.empaquetat ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 26))
                                .foregroundStyle(item.empaquetat ? .green : .secondary)
                        }
                        .buttonStyle(.borderless)
                        Text(item.nom)
                            .font(.title3)
                            .strikethrough(item.empaquetat)
                            .foregroundStyle(item.empaquetat ? .secondary : .primary)
                        Spacer()
                        Button {
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
                        Button("Edita", systemImage: "pencil") { itemPerEditar = item }
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
        .navigationTitle("\(categoria.emoji) \(categoria.nom)")
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
            AfegirItemsView(viatge: viatge, categoria: categoria)
        }
        .sheet(item: $itemPerEditar) { item in
            ItemEquipatgeFormView(viatge: viatge, item: item)
        }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var llista = items
        llista.move(fromOffsets: origen, toOffset: desti)
        for (index, item) in llista.enumerated() { item.ordre = index }
    }
}

// MARK: - Afegir elements en bloc

struct AfegirItemsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var categoria: CategoriaEquip

    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 10) {
                        IconaEmoji(emoji: categoria.emoji, mida: 28)
                        Text(categoria.nom)
                            .font(.title3.weight(.semibold))
                    }
                }
                Section("Elements (un per línia)") {
                    TextField("Samarretes\nCarregador\nPassaport", text: $text, axis: .vertical)
                        .lineLimit(6...16)
                        .font(.body)
                }
                Section {
                    Text("Pots enganxar una llista sencera copiada d'una nota.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        var ordre = viatge.itemsEquipatge(de: categoria.nom).count
        for nom in liniesDeText(text) {
            context.insert(ItemEquipatge(nom: nom, categoria: categoria.nom, ordre: ordre, viatge: viatge))
            ordre += 1
        }
        dismiss()
    }
}

// MARK: - Editar un element (nom i categoria)

struct ItemEquipatgeFormView: View {
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    @Bindable var item: ItemEquipatge

    @State private var nom = ""
    @State private var categoria = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom") {
                    TextField("Nom de l'element", text: $nom)
                        .font(.title3)
                }
                Section("Categoria") {
                    ForEach(viatge.categoriesLlista) { c in
                        Button {
                            categoria = c.nom
                        } label: {
                            HStack(spacing: 10) {
                                IconaEmoji(emoji: c.emoji, mida: 26)
                                Text(c.nom)
                                    .font(.title3)
                                Spacer()
                                if c.nom == categoria {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Edita l'element")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") {
                        item.nom = nom.trimmingCharacters(in: .whitespaces)
                        if !categoria.isEmpty { item.categoria = categoria }
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .onAppear {
                nom = item.nom
                categoria = item.categoria
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }
}

// MARK: - Crear o editar una categoria

struct CategoriaFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var categoria: CategoriaEquip?

    @State private var nom = ""
    @State private var emoji = "📦"
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
                    TextField("Nom de la categoria", text: $nom)
                        .font(.title3)
                }
            }
            .navigationTitle(categoria == nil ? "Nova categoria" : "Edita la categoria")
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
                guard let categoria else { return }
                nom = categoria.nom
                emoji = categoria.emoji
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 340)
        #endif
    }

    private func desar() {
        let nomNet = nom.trimmingCharacters(in: .whitespaces)
        if let categoria {
            // Si canvia el nom, els elements han de seguir-lo
            if categoria.nom != nomNet {
                for item in viatge.itemsEquipatge(de: categoria.nom) {
                    item.categoria = nomNet
                }
            }
            categoria.nom = nomNet
            categoria.emoji = emoji
        } else {
            context.insert(CategoriaEquip(nom: nomNet, emoji: emoji,
                                          ordre: viatge.categoriesLlista.count, viatge: viatge))
        }
        dismiss()
    }
}

// MARK: - Selector de categories suggerides

struct SelectorCategoriaView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    @State private var mostrarNova = false

    private var pendents: [CategoriaEquipatge] {
        let existents = Set(viatge.categoriesLlista.map(\.nom))
        return CategoriaEquipatge.allCases.filter { !existents.contains($0.rawValue) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !pendents.isEmpty {
                    Section("Suggeriments") {
                        ForEach(pendents, id: \.rawValue) { categoria in
                            Button {
                                afegir(nom: categoria.rawValue, emoji: categoria.emoji)
                            } label: {
                                HStack(spacing: 10) {
                                    IconaEmoji(emoji: categoria.emoji, mida: 28)
                                    Text(categoria.rawValue).font(.title3)
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
                        Label("Crea una categoria nova", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Afegeix categories")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fet") { dismiss() }
                }
            }
            .sheet(isPresented: $mostrarNova) {
                CategoriaFormView(viatge: viatge)
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 460)
        #endif
    }

    private func afegir(nom: String, emoji: String) {
        context.insert(CategoriaEquip(nom: nom, emoji: emoji,
                                      ordre: viatge.categoriesLlista.count, viatge: viatge))
    }
}

// MARK: - Copiar l'equipatge d'un altre viatge

struct CopiarEquipatgeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var desti: Viatge
    var viatges: [Viatge]

    private var origens: [Viatge] {
        viatges.filter { $0.persistentModelID != desti.persistentModelID && !$0.equipatgeLlista.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                if origens.isEmpty {
                    Text("Cap altre viatge té llista d'equipatge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(origens) { viatge in
                    Button {
                        copiar(de: viatge)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Text(viatge.emoji).font(.system(size: 30))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viatge.nom.isEmpty ? viatge.destinacio : viatge.nom)
                                    .font(.title3.weight(.semibold))
                                Text("\(viatge.equipatgeLlista.count) elements")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Section {
                    Text("Es copien categories i elements sense marcar; s'ometen els que ja tens.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Copia l'equipatge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 460)
        #endif
    }

    private func copiar(de origen: Viatge) {
        var categoriesExistents = Set(desti.categoriesLlista.map(\.nom))
        var ordre = desti.categoriesLlista.count
        for categoria in origen.categoriesLlista where !categoriesExistents.contains(categoria.nom) {
            context.insert(CategoriaEquip(nom: categoria.nom, emoji: categoria.emoji,
                                          ordre: ordre, viatge: desti))
            categoriesExistents.insert(categoria.nom)
            ordre += 1
        }

        var existents = Set(desti.equipatgeLlista.map { "\($0.categoria)|\($0.nom.lowercased())" })
        for item in origen.equipatgeLlista {
            let clau = "\(item.categoria)|\(item.nom.lowercased())"
            guard !existents.contains(clau) else { continue }
            context.insert(ItemEquipatge(nom: item.nom, categoria: item.categoria,
                                         ordre: item.ordre, viatge: desti))
            existents.insert(clau)
        }
    }
}
