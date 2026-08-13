import SwiftUI
import SwiftData

/// Trajecte del viatge: zones (1 a N), cadascuna amb el seu itinerari de llocs d'interès
struct TrajecteView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge
    @State private var mostrarNovaZona = false
    @State private var nomNovaZona = ""
    @State private var zonaPerEditar: Zona?
    @State private var nomEditat = ""
    @State private var mostrarIconaBitacora = false

    var body: some View {
        List {
            Section("Bitàcora") {
                NavigationLink {
                    BitacoraView(viatge: viatge)
                } label: {
                    HStack(spacing: 10) {
                        IconaEmoji(emoji: viatge.emojiBitacora, mida: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bitàcora")
                                .font(.title3.weight(.semibold))
                            Text(resumBitacora)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            mostrarIconaBitacora = true
                        } label: {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                        .help("Tria la icona de la Bitàcora")
                    }
                    .padding(.vertical, 2)
                }
                .contextMenu {
                    Button("Tria la icona", systemImage: "face.smiling") {
                        mostrarIconaBitacora = true
                    }
                }
            }

            Section("Localitzacions Principals") {
                ForEach(viatge.zonesOrdenades) { zona in
                    NavigationLink {
                        ZonaDetailView(zona: zona)
                    } label: {
                        HStack(spacing: 10) {
                            IconaEmoji(emoji: "📍", mida: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(zona.nom)
                                    .font(.title3.weight(.semibold))
                                Text("\(zona.llocsLlista.count) llocs d'interès")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                nomEditat = zona.nom
                                zonaPerEditar = zona
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.borderless)
                            .help("Canvia el nom de la zona")
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            nomEditat = zona.nom
                            zonaPerEditar = zona
                        } label: {
                            Label("Edita", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button("Canvia el nom", systemImage: "pencil") {
                            nomEditat = zona.nom
                            zonaPerEditar = zona
                        }
                        Button("Duplica (amb els llocs)", systemImage: "square.on.square") {
                            duplicar(zona)
                        }
                        Button("Esborra la zona", systemImage: "trash", role: .destructive) {
                            context.delete(zona)
                        }
                    }
                }
                .onDelete(perform: esborrar)
                .onMove(perform: moure)
            }
        }
        .navigationTitle("Itinerari")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Button {
                    nomNovaZona = ""
                    mostrarNovaZona = true
                } label: {
                    Label("Nova localització", systemImage: "plus")
                }
            }
        }
        .alert("Canvia el nom de la zona", isPresented: Binding(
            get: { zonaPerEditar != nil },
            set: { if !$0 { zonaPerEditar = nil } }
        )) {
            TextField("Nom de la zona", text: $nomEditat)
            Button("Desa") {
                if !nomEditat.isEmpty {
                    zonaPerEditar?.nom = nomEditat
                }
                zonaPerEditar = nil
            }
            Button("Cancel·la", role: .cancel) { zonaPerEditar = nil }
        }
        .alert("Nova localització", isPresented: $mostrarNovaZona) {
            TextField("Nom (p. ex. Kyoto)", text: $nomNovaZona)
            Button("Afegeix") {
                let zona = Zona(nom: nomNovaZona, ordre: viatge.zonesLlista.count, viatge: viatge)
                context.insert(zona)
            }
            .disabled(nomNovaZona.isEmpty)
            Button("Cancel·la", role: .cancel) { }
        } message: {
            Text("Cada zona té el seu propi itinerari de llocs d'interès.")
        }
        .sheet(isPresented: $mostrarIconaBitacora) {
            EmojiPickerView(seleccio: $viatge.emojiBitacora)
        }
    }

    /// Resum de la bitàcora per a la fila de l'apartat
    private var resumBitacora: String {
        let visites = viatge.bitacoraLlista.count
        guard visites > 0 else { return "Llocs visitats, dia a dia" }
        let dies = viatge.bitacoraPerDia.count
        return "\(visites) \(visites == 1 ? "visita" : "visites") en \(dies) \(dies == 1 ? "dia" : "dies")"
    }

    private func esborrar(_ offsets: IndexSet) {
        let zones = viatge.zonesOrdenades
        for index in offsets { context.delete(zones[index]) }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var zones = viatge.zonesOrdenades
        zones.move(fromOffsets: origen, toOffset: desti)
        for (index, zona) in zones.enumerated() { zona.ordre = index }
    }

    /// Duplica una localització amb els seus llocs i enllaços (sense les fotos)
    private func duplicar(_ original: Zona) {
        let copia = Zona(nom: "\(original.nom) (còpia)", ordre: viatge.zonesLlista.count, viatge: viatge)
        context.insert(copia)
        for enllac in original.enllacosLlista {
            context.insert(EnllacZona(titol: enllac.titol, url: enllac.url, ordre: enllac.ordre, zona: copia))
        }
        for lloc in original.llocsOrdenats {
            let llocNou = LlocInteres(nom: lloc.nom, descripcio: lloc.descripcio,
                                      urlMaps: lloc.urlMaps, ordre: lloc.ordre, zona: copia)
            llocNou.fontDescripcio = lloc.fontDescripcio
            llocNou.urlMapsGoogle = lloc.urlMapsGoogle
            llocNou.cercaPersonalitzada = lloc.cercaPersonalitzada
            context.insert(llocNou)
            for enllac in lloc.enllacosLlista {
                context.insert(EnllacLloc(titol: enllac.titol, url: enllac.url, tipus: enllac.tipus, ordre: enllac.ordre, lloc: llocNou))
            }
        }
    }
}

/// Itinerari d'una zona: llista ordenada de llocs d'interès
struct ZonaDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var zona: Zona
    @State private var mostrarNouLloc = false
    @State private var llocPerEditar: LlocInteres?
    @State private var mostrarCanviNom = false
    @State private var nomEditat = ""
    @State private var mostrarNouEnllac = false
    @State private var enllacPerEditar: EnllacZona?

    var body: some View {
        List {
            Section("Rutes i enllaços (Wikiloc o semblants)") {
                ForEach(zona.enllacosLlista) { enllac in
                    HStack(spacing: 12) {
                        if let url = URL(string: enllac.url) {
                            Link(destination: url) {
                                HStack(spacing: 12) {
                                    if enllac.esWikiloc {
                                        IconaWikiloc(mida: 32)
                                    } else {
                                        Image(systemName: "link.circle.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.blue)
                                    }
                                    Text(enllac.titol.isEmpty ? enllac.url : enllac.titol)
                                        .font(.body)
                                        .lineLimit(1)
                                }
                            }
                        }
                        Spacer()
                        Button {
                            enllacPerEditar = enllac
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.borderless)
                    }
                    .contextMenu {
                        Button("Esborra l'enllaç", systemImage: "trash", role: .destructive) {
                            context.delete(enllac)
                        }
                    }
                }
                .onDelete { offsets in
                    let llista = zona.enllacosLlista
                    for index in offsets { context.delete(llista[index]) }
                }
                .onMove { origen, desti in
                    var llista = zona.enllacosLlista
                    llista.move(fromOffsets: origen, toOffset: desti)
                    for (index, enllac) in llista.enumerated() { enllac.ordre = index }
                }
                Button {
                    mostrarNouEnllac = true
                } label: {
                    Label("Afegeix una ruta (Wikiloc o semblant)", systemImage: "figure.hiking")
                }
            }

            Section("Itinerari · Llocs d'interès") {
                ForEach(pendents) { lloc in
                    filaLloc(lloc)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(pendents[index]) }
                }
                .onMove(perform: moure)
            }

            if !visitats.isEmpty {
                Section("Completat") {
                    ForEach(visitats) { lloc in
                        filaLloc(lloc)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(visitats[index]) }
                    }
                }
            }
        }
        .navigationTitle(zona.nom)
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
            ToolbarItem {
                Menu {
                    Button("Afegeix un enllaç de ruta (Wikiloc...)", systemImage: "figure.hiking") {
                        mostrarNouEnllac = true
                    }
                    Button("Canvia el nom", systemImage: "pencil") {
                        nomEditat = zona.nom
                        mostrarCanviNom = true
                    }
                } label: {
                    Label("Més opcions", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem {
                Button {
                    mostrarNouLloc = true
                } label: {
                    Label("Nou lloc", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarNouLloc) {
            LlocFormView(zona: zona)
        }
        .sheet(item: $llocPerEditar) { lloc in
            LlocFormView(zona: zona, lloc: lloc)
        }
        .sheet(isPresented: $mostrarNouEnllac) {
            EnllacZonaFormView(zona: zona)
        }
        .sheet(item: $enllacPerEditar) { enllac in
            EnllacZonaFormView(zona: zona, enllac: enllac)
        }
        .alert("Canvia el nom de la zona", isPresented: $mostrarCanviNom) {
            TextField("Nom de la zona", text: $nomEditat)
            Button("Desa") {
                if !nomEditat.isEmpty { zona.nom = nomEditat }
            }
            Button("Cancel·la", role: .cancel) { }
        }
    }

    private var pendents: [LlocInteres] { zona.llocsOrdenats.filter { !$0.visitat } }
    private var visitats: [LlocInteres] { zona.llocsOrdenats.filter { $0.visitat } }

    /// Fila d'un lloc amb botons de completat i edició
    @ViewBuilder
    private func filaLloc(_ lloc: LlocInteres) -> some View {
        NavigationLink {
            LlocDetailView(lloc: lloc)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle")
                    .font(.system(size: 26))
                    .foregroundStyle(lloc.visitat ? Color.green : Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(lloc.nom)
                        .font(.title3)
                        .strikethrough(lloc.visitat)
                    if !lloc.descripcio.isEmpty {
                        Text(lloc.descripcio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button {
                    lloc.visitat.toggle()
                } label: {
                    Image(systemName: lloc.visitat ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26))
                        .foregroundStyle(lloc.visitat ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                .help(lloc.visitat ? "Torna a pendents" : "Marca com a completat")
                Button {
                    llocPerEditar = lloc
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
                .help("Edita el lloc")
            }
            .padding(.vertical, 2)
        }
        .swipeActions(edge: .leading) {
            Button {
                llocPerEditar = lloc
            } label: {
                Label("Edita", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button(lloc.visitat ? "Torna a pendents" : "Marca com a completat",
                   systemImage: "checkmark.circle") {
                lloc.visitat.toggle()
            }
            Button("Edita", systemImage: "pencil") {
                llocPerEditar = lloc
            }
            Button("Registra la visita a la Bitàcora", systemImage: "book") {
                registrarALaBitacora(lloc)
            }
            Button("Duplica", systemImage: "square.on.square") {
                duplicar(lloc)
            }
            Button("Esborra el lloc", systemImage: "trash", role: .destructive) {
                context.delete(lloc)
            }
        }
    }

    private func moure(from origen: IndexSet, to desti: Int) {
        var llocs = pendents
        llocs.move(fromOffsets: origen, toOffset: desti)
        for (index, lloc) in llocs.enumerated() { lloc.ordre = index }
    }

    /// Passa un lloc de l'itinerari a la Bitàcora com a visita d'avui
    private func registrarALaBitacora(_ lloc: LlocInteres) {
        guard let viatge = zona.viatge else { return }
        let ara = Date()
        let quan = (ara >= viatge.dataInici && ara <= viatge.dataFi) ? ara : viatge.dataInici
        let visita = VisitaBitacora(
            nom: lloc.nom,
            adreca: zona.nom,
            urlMaps: lloc.urlAppleMaps?.absoluteString ?? "",
            dataVisita: quan,
            origen: VisitaBitacora.origenItinerari,
            viatge: viatge
        )
        context.insert(visita)
        lloc.visitat = true
    }

    /// Duplica un lloc amb els seus enllaços (sense les fotos)
    private func duplicar(_ original: LlocInteres) {
        let copia = LlocInteres(nom: "\(original.nom) (còpia)", descripcio: original.descripcio,
                                urlMaps: original.urlMaps, ordre: zona.llocsLlista.count, zona: zona)
        copia.fontDescripcio = original.fontDescripcio
        copia.urlMapsGoogle = original.urlMapsGoogle
        copia.cercaPersonalitzada = original.cercaPersonalitzada
        context.insert(copia)
        for enllac in original.enllacosLlista {
            context.insert(EnllacLloc(titol: enllac.titol, url: enllac.url, tipus: enllac.tipus, ordre: enllac.ordre, lloc: copia))
        }
        llocPerEditar = copia
    }
}

/// Formulari per afegir o editar un enllaç de ruta d'una localització
struct EnllacZonaFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var zona: Zona
    var enllac: EnllacZona?

    @State private var titol = ""
    @State private var url = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Títol") {
                    TextField("P. ex. Ruta pel centre, Pujada al castell...", text: $titol)
                        .font(.title3)
                }
                Section("Enllaç") {
                    TextField("https://ca.wikiloc.com/... o una altra app", text: $url)
                        .font(.body)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                }
            }
            .navigationTitle(enllac == nil ? "Nou enllaç de ruta" : "Edita l'enllaç")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { desar() }
                        .disabled(url.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .onAppear {
                if let enllac {
                    titol = enllac.titol
                    url = enllac.url
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 280)
        #endif
    }

    private func desar() {
        var urlNeta = url.trimmingCharacters(in: .whitespaces)
        if !urlNeta.isEmpty && !urlNeta.lowercased().hasPrefix("http") {
            urlNeta = "https://" + urlNeta
        }
        if let enllac {
            enllac.titol = titol
            enllac.url = urlNeta
        } else {
            let nou = EnllacZona(titol: titol, url: urlNeta, ordre: zona.enllacosLlista.count, zona: zona)
            context.insert(nou)
        }
        dismiss()
    }
}
