import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var faseEscena
    @Query(sort: \Viatge.dataInici) private var viatges: [Viatge]
    @State private var seleccio: Viatge?
    @State private var mostrarNou = false
    @State private var viatgePerEditar: Viatge?
    @State private var mostrarExportador = false
    @State private var mostrarImportador = false
    @State private var documentBackup = ArxiuBackup()
    @State private var missatgeBackup: String?

    /// Viatges pendents, ordenats per la data en què es faran
    private var propers: [Viatge] { viatges.filter { !$0.completat } }
    /// Viatges ja fets
    private var fets: [Viatge] { viatges.filter { $0.completat } }
    /// Anys amb viatges fets, del més recent al més antic
    private var anysFets: [Int] {
        Array(Set(fets.map { Calendar.current.component(.year, from: $0.dataInici) })).sorted(by: >)
    }
    /// Viatges fets d'un any concret
    private func fets(de any: Int) -> [Viatge] {
        fets.filter { Calendar.current.component(.year, from: $0.dataInici) == any }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $seleccio) {
                Section("Propers viatges") {
                    ForEach(propers) { viatge in
                        fila(viatge)
                    }
                    .onDelete { offsets in
                        for index in offsets { esborrar(propers[index]) }
                    }
                }
                if !fets.isEmpty {
                    Section("Fets") {
                        ForEach(anysFets, id: \.self) { any in
                            Text(String(any))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 2, trailing: 8))
                            let viatgesAny = fets(de: any)
                            ForEach(viatgesAny) { viatge in
                                filaCompacta(viatge)
                            }
                            .onDelete { offsets in
                                for index in offsets { esborrar(viatgesAny[index]) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Viatges")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                #endif
                ToolbarItem {
                    Menu {
                        Button("Exporta una còpia de seguretat", systemImage: "square.and.arrow.up") {
                            prepararExportacio()
                        }
                        Button("Importa una còpia de seguretat", systemImage: "square.and.arrow.down") {
                            mostrarImportador = true
                        }
                    } label: {
                        Label("Còpia de seguretat", systemImage: "externaldrive")
                    }
                }
                ToolbarItem {
                    Button {
                        mostrarNou = true
                    } label: {
                        Label("Nou viatge", systemImage: "plus")
                    }
                }
            }
            .fileExporter(isPresented: $mostrarExportador,
                          document: documentBackup,
                          contentType: .json,
                          defaultFilename: Backup.nomArxiu) { resultat in
                if case .success = resultat {
                    missatgeBackup = "Còpia de seguretat guardada correctament."
                }
            }
            .fileImporter(isPresented: $mostrarImportador,
                          allowedContentTypes: [.json]) { resultat in
                if case .success(let url) = resultat {
                    importar(de: url)
                }
            }
            .alert("Còpia de seguretat", isPresented: Binding(
                get: { missatgeBackup != nil },
                set: { if !$0 { missatgeBackup = nil } }
            )) {
                Button("D'acord") { }
            } message: {
                Text(missatgeBackup ?? "")
            }
            .overlay {
                if viatges.isEmpty {
                    ContentUnavailableView(
                        "Cap viatge",
                        systemImage: "airplane.departure",
                        description: Text("Prem + per planificar el teu primer viatge.")
                    )
                }
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            #endif
        } detail: {
            if let viatge = seleccio {
                NavigationStack {
                    ViatgeDetailView(viatge: viatge)
                }
            } else {
                ContentUnavailableView(
                    "Selecciona un viatge",
                    systemImage: "map",
                    description: Text("Tria un viatge de la llista o crea'n un de nou.")
                )
            }
        }
        .sheet(isPresented: $mostrarNou) {
            ViatgeFormView()
        }
        .sheet(item: $viatgePerEditar) { viatge in
            ViatgeFormView(viatge: viatge)
        }
        // Recull els llocs compartits des d'Apple Maps mentre l'app estava tancada
        .onAppear {
            ImportadorBitacora.importarPendents(a: context)
        }
        .onChange(of: faseEscena) { _, nova in
            if nova == .active {
                ImportadorBitacora.importarPendents(a: context)
            }
        }
    }

    /// Targeta d'un viatge: fons il·lustrat segons el destí, amb botons de
    /// fet i editar a sobre i un menú contextual
    @ViewBuilder
    private func fila(_ viatge: Viatge) -> some View {
        TargetaViatge(viatge: viatge)
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 6) {
                    botoRodo(icona: viatge.completat ? "checkmark.circle.fill" : "circle",
                             color: viatge.completat ? .green : .white,
                             ajuda: viatge.completat ? "Torna a propers" : "Marca com a fet") {
                        viatge.completat.toggle()
                        if seleccio == viatge { seleccio = nil }
                    }
                    botoRodo(icona: "pencil", color: .white, ajuda: "Edita el viatge") {
                        viatgePerEditar = viatge
                    }
                }
                .padding(8)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            .listRowSeparator(.hidden)
            .tag(viatge)
            .contextMenu {
                Button("Edita", systemImage: "pencil") { viatgePerEditar = viatge }
                Button("Duplica el viatge", systemImage: "square.on.square") { duplicar(viatge) }
                Button(viatge.completat ? "Torna a propers" : "Marca com a fet",
                       systemImage: "checkmark.circle") {
                    viatge.completat.toggle()
                }
                Button("Esborra el viatge", systemImage: "trash", role: .destructive) {
                    esborrar(viatge)
                }
            }
    }

    /// Botonet rodó i translúcid, per posar-lo a sobre d'una imatge de fons
    private func botoRodo(icona: String, color: Color, ajuda: String, accio: @escaping () -> Void) -> some View {
        Button(action: accio) {
            Image(systemName: icona)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(.black.opacity(0.35), in: Circle())
        }
        .buttonStyle(.borderless)
        .help(ajuda)
    }

    /// Fila reduïda per als viatges ja fets
    @ViewBuilder
    private func filaCompacta(_ viatge: Viatge) -> some View {
        HStack(spacing: 10) {
            Text(viatge.emoji)
                .font(.system(size: 20))
            Text(viatge.nom.isEmpty ? viatge.destinacio : viatge.nom)
                .font(.body)
                .strikethrough()
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("\(viatge.dataInici.formatted(.dateTime.day().month().locale(localeCatala))) – \(viatge.dataFi.formatted(.dateTime.day().month().locale(localeCatala)))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                viatge.completat = false
            } label: {
                Image(systemName: "arrow.uturn.backward.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Torna a propers")
        }
        .tag(viatge)
        .contextMenu {
            Button("Torna a propers", systemImage: "arrow.uturn.backward") {
                viatge.completat = false
            }
            Button("Duplica el viatge", systemImage: "square.on.square") { duplicar(viatge) }
            Button("Esborra el viatge", systemImage: "trash", role: .destructive) {
                esborrar(viatge)
            }
        }
    }

    private func esborrar(_ viatge: Viatge) {
        if seleccio == viatge { seleccio = nil }
        context.delete(viatge)
    }

    /// Duplica un viatge amb l'equipatge, les llistes de comprovació i el
    /// trajecte sencer (localitzacions, llocs i enllaços). No copia documents ni fotos.
    private func duplicar(_ original: Viatge) {
        let copia = Viatge(nom: original.nom.isEmpty ? "Còpia" : "\(original.nom) (còpia)",
                           destinacio: original.destinacio,
                           emoji: original.emoji,
                           dataInici: original.dataInici,
                           dataFi: original.dataFi,
                           notes: original.notes)
        copia.nomApartatAltres = original.nomApartatAltres
        copia.emojiBitacora = original.emojiBitacora
        copia.categoriesInicialitzades = original.categoriesInicialitzades
        context.insert(copia)

        for categoria in original.categoriesLlista {
            context.insert(CategoriaEquip(nom: categoria.nom, emoji: categoria.emoji,
                                          ordre: categoria.ordre, viatge: copia))
        }
        for item in original.equipatgeLlista {
            let nou = ItemEquipatge(nom: item.nom, categoria: item.categoria, ordre: item.ordre, viatge: copia)
            nou.empaquetat = false
            context.insert(nou)
        }
        for seccio in original.seccionsAltresLlista {
            context.insert(SeccioAltres(nom: seccio.nom, emoji: seccio.emoji,
                                        ordre: seccio.ordre, viatge: copia))
        }
        for item in original.altresLlista {
            let nou = ItemAltres(nom: item.nom, seccio: item.seccio, ordre: item.ordre, viatge: copia)
            nou.fet = false
            context.insert(nou)
        }
        for horari in original.horarisLlista {
            let nou = Horari(tipus: horari.tipus, origen: horari.origen, desti: horari.desti,
                             dataHora: horari.dataHora, duracio: horari.duracio,
                             notes: horari.notes, viatge: copia)
            nou.ordre = horari.ordre
            context.insert(nou)
        }
        for zona in original.zonesOrdenades {
            let zonaNova = Zona(nom: zona.nom, ordre: zona.ordre, viatge: copia)
            context.insert(zonaNova)
            for enllac in zona.enllacosLlista {
                context.insert(EnllacZona(titol: enllac.titol, url: enllac.url,
                                          ordre: enllac.ordre, zona: zonaNova))
            }
            for lloc in zona.llocsOrdenats {
                let llocNou = LlocInteres(nom: lloc.nom, descripcio: lloc.descripcio,
                                          urlMaps: lloc.urlMaps, ordre: lloc.ordre, zona: zonaNova)
                llocNou.fontDescripcio = lloc.fontDescripcio
                llocNou.urlMapsGoogle = lloc.urlMapsGoogle
                llocNou.cercaPersonalitzada = lloc.cercaPersonalitzada
                context.insert(llocNou)
                for enllac in lloc.enllacosLlista {
                    context.insert(EnllacLloc(titol: enllac.titol, url: enllac.url,
                                              tipus: enllac.tipus, ordre: enllac.ordre, lloc: llocNou))
                }
            }
        }
        viatgePerEditar = copia
    }

    // MARK: Còpia de seguretat

    private func prepararExportacio() {
        guard let dades = Backup.exportar(viatges) else {
            missatgeBackup = "No s'ha pogut preparar la còpia."
            return
        }
        documentBackup = ArxiuBackup(dades: dades)
        mostrarExportador = true
    }

    private func importar(de url: URL) {
        let calAturar = url.startAccessingSecurityScopedResource()
        defer { if calAturar { url.stopAccessingSecurityScopedResource() } }
        do {
            let dades = try Data(contentsOf: url)
            let quants = try Backup.importar(dades, a: context)
            missatgeBackup = "S'han importat \(quants) viatges."
        } catch {
            missatgeBackup = "No s'ha pogut llegir l'arxiu de còpia."
        }
    }
}

/// Targeta reduïda d'un viatge: fons il·lustrat del destí amb nom, destinació
/// i dates a sobre. La versió gran és la capçalera de `ViatgeDetailView`.
struct TargetaViatge: View {
    @Bindable var viatge: Viatge
    var alcada: CGFloat = 130

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PortadaViatgeView(viatge: viatge)

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)

            // El dibuix de fons ja identifica el viatge: no calen més icones aquí
            VStack(alignment: .leading, spacing: 3) {
                if !viatge.destinacio.isEmpty {
                    Text(viatge.destinacio)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(viatge.nom.isEmpty ? "Sense nom" : viatge.nom)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if !viatge.destinacio.isEmpty && !viatge.nom.isEmpty {
                    Text(viatge.nom)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                Label {
                    Text("\(viatge.dataInici.formatCatala(date: .abbreviated, time: .omitted)) – \(viatge.dataFi.formatCatala(date: .abbreviated, time: .omitted))")
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(height: alcada)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .listRowBackground(Color.clear)
    }
}
