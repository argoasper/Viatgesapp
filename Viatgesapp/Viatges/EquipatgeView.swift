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
    @State private var mostrarDesarPlantilla = false
    @State private var mostrarFusionarPlantilla = false
    @State private var mostrarRestablirPlantilla = false
    @State private var mostrarPlantilla = false

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
                    Divider()
                    Button("Torna a afegir els elements de la plantilla", systemImage: "arrow.down.doc") {
                        aplicarPlantilla()
                    }
                    Button("Desa aquesta llista com a plantilla", systemImage: "square.and.arrow.down") {
                        mostrarDesarPlantilla = true
                    }
                    Button("Afegeix els elements nous a la plantilla", systemImage: "plus.square.on.square") {
                        mostrarFusionarPlantilla = true
                    }
                    Button("Mira la plantilla per defecte", systemImage: "list.bullet.rectangle") {
                        mostrarPlantilla = true
                    }
                    Button("Restableix la plantilla original", systemImage: "arrow.counterclockwise", role: .destructive) {
                        mostrarRestablirPlantilla = true
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
        .sheet(isPresented: $mostrarPlantilla) {
            PlantillaEquipatgeView()
        }
        .alert("Desa aquesta llista com a plantilla?", isPresented: $mostrarDesarPlantilla) {
            Button("Cancel·la", role: .cancel) { }
            Button("Desa") { PlantillaEquipatge.shared.desar(des: viatge) }
        } message: {
            Text("La plantilla per defecte passarà a ser exactament les categories i els elements d'aquest viatge. Els viatges nous en partiran.")
        }
        .alert("Afegeix els elements nous a la plantilla?", isPresented: $mostrarFusionarPlantilla) {
            Button("Cancel·la", role: .cancel) { }
            Button("Afegeix") { PlantillaEquipatge.shared.fusionar(amb: viatge) }
        } message: {
            Text("S'afegiran a la plantilla les categories i els elements d'aquest viatge que encara no hi siguin. No se'n treu res.")
        }
        .alert("Restableix la plantilla original?", isPresented: $mostrarRestablirPlantilla) {
            Button("Cancel·la", role: .cancel) { }
            Button("Restableix", role: .destructive) { PlantillaEquipatge.shared.restablir() }
        } message: {
            Text("La plantilla tornarà a la llista inicial i perdràs els canvis que hi hagis desat.")
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

    /// Crea, el primer cop, les categories i els elements de la plantilla
    /// per defecte, i les categories que facin falta per als elements que ja
    /// existeixin.
    private func inicialitzarCategories() {
        let plantilla = PlantillaEquipatge.shared
        var existents = Set(viatge.categoriesLlista.map(\.nom))
        var ordre = viatge.categoriesLlista.count

        for nom in Set(viatge.equipatgeLlista.map(\.categoria)) where !nom.isEmpty && !existents.contains(nom) {
            context.insert(CategoriaEquip(nom: nom, emoji: plantilla.emoji(per: nom), ordre: ordre, viatge: viatge))
            existents.insert(nom)
            ordre += 1
        }

        if !viatge.categoriesInicialitzades {
            for categoria in plantilla.categories where !existents.contains(categoria.nom) {
                context.insert(CategoriaEquip(nom: categoria.nom, emoji: categoria.emoji,
                                              ordre: ordre, viatge: viatge))
                existents.insert(categoria.nom)
                ordre += 1
                afegirItems(categoria.items, a: categoria.nom)
            }
            viatge.categoriesInicialitzades = true
        }
    }

    /// Torna a portar al viatge tot el que hi ha a la plantilla (categories i
    /// elements), sense duplicar el que ja hi és ni tocar el que hi has afegit.
    private func aplicarPlantilla() {
        var existents = Set(viatge.categoriesLlista.map(\.nom))
        var ordre = viatge.categoriesLlista.count
        for categoria in PlantillaEquipatge.shared.categories {
            if !existents.contains(categoria.nom) {
                context.insert(CategoriaEquip(nom: categoria.nom, emoji: categoria.emoji,
                                              ordre: ordre, viatge: viatge))
                existents.insert(categoria.nom)
                ordre += 1
            }
            afegirItems(categoria.items, a: categoria.nom)
        }
    }

    /// Afegeix elements a una categoria del viatge, ometent els repetits.
    private func afegirItems(_ noms: [String], a nomCategoria: String) {
        let actuals = viatge.itemsEquipatge(de: nomCategoria)
        var existents = Set(actuals.map { $0.nom.lowercased() })
        var ordre = actuals.count
        for nom in noms where !existents.contains(nom.lowercased()) {
            context.insert(ItemEquipatge(nom: nom, categoria: nomCategoria, ordre: ordre, viatge: viatge))
            existents.insert(nom.lowercased())
            ordre += 1
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

    private var pendents: [CategoriaPlantilla] {
        let existents = Set(viatge.categoriesLlista.map(\.nom))
        return PlantillaEquipatge.shared.categories.filter { !existents.contains($0.nom) }
    }

    var body: some View {
        NavigationStack {
            List {
                if !pendents.isEmpty {
                    Section("Suggeriments") {
                        ForEach(pendents) { categoria in
                            Button {
                                afegir(categoria)
                            } label: {
                                HStack(spacing: 10) {
                                    IconaEmoji(emoji: categoria.emoji, mida: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(categoria.nom).font(.title3)
                                        if !categoria.items.isEmpty {
                                            Text("\(categoria.items.count) elements de la plantilla")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
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

    private func afegir(_ categoria: CategoriaPlantilla) {
        context.insert(CategoriaEquip(nom: categoria.nom, emoji: categoria.emoji,
                                      ordre: viatge.categoriesLlista.count, viatge: viatge))
        let actuals = viatge.itemsEquipatge(de: categoria.nom)
        var existents = Set(actuals.map { $0.nom.lowercased() })
        var ordre = actuals.count
        for nom in categoria.items where !existents.contains(nom.lowercased()) {
            context.insert(ItemEquipatge(nom: nom, categoria: categoria.nom, ordre: ordre, viatge: viatge))
            existents.insert(nom.lowercased())
            ordre += 1
        }
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


// MARK: - Consulta de la plantilla per defecte

struct PlantillaEquipatgeView: View {
    @Environment(\.dismiss) private var dismiss

    private var plantilla = PlantillaEquipatge.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Cada viatge nou parteix d'aquesta llista. Al viatge en pots esborrar el que no necessitis: la plantilla no es toca fins que la desis des del menú d'Equipatge.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(plantilla.categories) { categoria in
                    Section {
                        ForEach(categoria.items, id: \.self) { item in
                            Text(item).font(.body)
                        }
                        if categoria.items.isEmpty {
                            Text("Cap element")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            Text(categoria.emoji)
                            Text(categoria.nom)
                        }
                    }
                }
            }
            .navigationTitle("Plantilla per defecte")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fet") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 520)
        #endif
    }
}
