import SwiftUI
import SwiftData
import PhotosUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Bitàcora: llocs visitats, agrupats automàticament pel dia de la visita
struct BitacoraView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var faseEscena
    @Bindable var viatge: Viatge

    @State private var mostrarNovaVisita = false
    @State private var visitaPerEditar: VisitaBitacora?
    @State private var missatge: String?
    @State private var arxiuExportat: ArxiuExportat?
    /// Llocs compartits des d'Apple Maps que no cauen dins de cap viatge
    @State private var pendents: [LlocCompartit] = []

    /// Arxiu generat i a punt per compartir
    struct ArxiuExportat: Identifiable {
        let id = UUID()
        let url: URL
        let format: String
        let visites: Int
        let sensePosicio: Int
    }

    var body: some View {
        List {
            if !pendents.isEmpty {
                seccioPendents
            }

            if viatge.bitacoraLlista.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Cap visita encara", systemImage: "book.closed")
                    } description: {
                        Text("Comparteix un lloc des d'Apple Maps cap a Viatges, o prem ＋ per registrar-lo a mà. Cada visita es guarda al dia que la fas.")
                    }
                }
            }

            ForEach(viatge.bitacoraPerDia) { dia in
                Section {
                    ForEach(dia.visites) { visita in
                        filaVisita(visita)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(dia.visites[index]) }
                    }
                } header: {
                    capcaleraDia(dia)
                }
            }
        }
        .navigationTitle("Bitàcora")
        .toolbar {
            ToolbarItem {
                Menu {
                    Button("Enganxa un lloc d'Apple Maps", systemImage: "doc.on.clipboard") {
                        enganxarDelPortapapers()
                    }
                    Button("Comprova els llocs compartits", systemImage: "arrow.down.circle") {
                        let afegides = ImportadorBitacora.importarPendents(a: context)
                        let sensePosar = refrescarPendents()
                        if afegides > 0 {
                            missatge = "S'han afegit \(afegides) \(afegides == 1 ? "visita compartida" : "visites compartides")."
                        } else if sensePosar > 0 {
                            missatge = "Hi ha \(sensePosar) \(sensePosar == 1 ? "lloc compartit" : "llocs compartits") que no cauen dins de cap viatge. Els tens a dalt de tot de la Bitàcora."
                        } else if !BustiaBitacora.grupDisponible {
                            missatge = "El grup d'apps «\(BustiaBitacora.grup)» no està disponible, així que els llocs compartits des d'Apple Maps no poden arribar a l'app. Cal activar-lo a l'Xcode a les dues destinacions (Viatges i ViatgesShare)."
                        } else {
                            missatge = "No hi ha cap lloc compartit pendent."
                        }
                    }
                    Divider()
                    Button("Exporta a GPX (Wikiloc, Komoot...)", systemImage: "figure.hiking") {
                        exportar(format: "gpx")
                    }
                    Button("Exporta a KML (Google My Maps)", systemImage: "globe") {
                        exportar(format: "kml")
                    }
                } label: {
                    Label("Més opcions", systemImage: "ellipsis.circle")
                }
            }
            ToolbarItem {
                Button {
                    mostrarNovaVisita = true
                } label: {
                    Label("Nova visita", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarNovaVisita) {
            VisitaFormView(viatge: viatge)
        }
        .sheet(item: $visitaPerEditar) { visita in
            VisitaFormView(viatge: viatge, visita: visita)
        }
        .sheet(item: $arxiuExportat) { arxiu in
            fullaExportacio(arxiu)
        }
        .alert("Bitàcora", isPresented: Binding(
            get: { missatge != nil },
            set: { if !$0 { missatge = nil } }
        )) {
            Button("D'acord") { missatge = nil }
        } message: {
            Text(missatge ?? "")
        }
        .onAppear {
            ImportadorBitacora.importarPendents(a: context)
            refrescarPendents()
        }
        // En tornar d'Apple Maps, recollim el que s'acaba de compartir
        .onChange(of: faseEscena) { _, nova in
            guard nova == .active else { return }
            ImportadorBitacora.importarPendents(a: context)
            refrescarPendents()
        }
    }

    // MARK: Llocs compartits que no cauen dins de cap viatge

    @ViewBuilder
    private var seccioPendents: some View {
        Section {
            ForEach(pendents) { lloc in
                VStack(alignment: .leading, spacing: 6) {
                    Text(lloc.nom)
                        .font(.title3.weight(.semibold))
                    Text(lloc.data.formatCatala(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if !lloc.adreca.isEmpty {
                        Text(lloc.adreca)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    HStack(spacing: 12) {
                        Button("Afegeix a aquest viatge", systemImage: "plus.circle.fill") {
                            ImportadorBitacora.assignar(lloc, a: viatge, context: context)
                            refrescarPendents()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Descarta", systemImage: "trash") {
                            ImportadorBitacora.descartar(lloc)
                            refrescarPendents()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                    .font(.subheadline)
                    .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }
        } header: {
            Label("Compartits sense viatge", systemImage: "tray.and.arrow.down")
                .textCase(nil)
        } footer: {
            Text("Aquests llocs s'han compartit en dates que no cauen dins de cap viatge. Posa'ls on toqui o descarta'ls.")
        }
    }

    /// Torna quants n'han quedat pendents
    @discardableResult
    private func refrescarPendents() -> Int {
        let viatges = (try? context.fetch(FetchDescriptor<Viatge>())) ?? []
        let llista = ImportadorBitacora.pendentsSenseViatge(viatges)
        pendents = llista
        return llista.count
    }

    // MARK: Capçalera del dia

    @ViewBuilder
    private func capcaleraDia(_ dia: DiaBitacora) -> some View {
        HStack {
            if let numero = viatge.numeroDiaViatge(dia.dia) {
                Text("Dia \(numero) · \(dia.dia.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(localeCatala)))")
            } else {
                Text(dia.dia.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(localeCatala)))
            }
            Spacer()
            Text("\(dia.visites.count)")
        }
        .font(.subheadline.weight(.semibold))
        .textCase(nil)
    }

    // MARK: Fila d'una visita

    @ViewBuilder
    private func filaVisita(_ visita: VisitaBitacora) -> some View {
        HStack(spacing: 10) {
            IconaEmoji(emoji: visita.emoji, mida: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(visita.nom)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    Text(visita.dataVisita.formatCatala(date: .omitted, time: .shortened))
                    if visita.origen == VisitaBitacora.origenCompartit {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if !visita.adreca.isEmpty {
                    Text(visita.adreca)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if !visita.notes.isEmpty {
                    Text(visita.notes)
                        .font(.subheadline)
                        .lineLimit(2)
                }
            }
            Spacer()
            if let dades = visita.foto, let imatge = imatgeDesDades(dades) {
                imatge
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if let url = visita.urlAppleMaps {
                Link(destination: url) {
                    IconaAppleMaps(mida: 30)
                }
                .buttonStyle(.borderless)
                .help("Obre a Apple Maps")
            }
            if let url = visita.urlGoogleMaps {
                Link(destination: url) {
                    IconaGoogleMaps(mida: 30)
                }
                .buttonStyle(.borderless)
                .help("Obre a Google Maps")
            }
            ShareLink(item: visita.textPerCompartir) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .help("Comparteix aquesta visita")
            Button {
                visitaPerEditar = visita
            } label: {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading) {
            Button {
                visitaPerEditar = visita
            } label: {
                Label("Edita", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button("Edita", systemImage: "pencil") { visitaPerEditar = visita }
            if let url = visita.urlGoogleMaps {
                Link(destination: url) { Label("Obre a Google Maps", systemImage: "map") }
            }
            Button("Esborra la visita", systemImage: "trash", role: .destructive) {
                context.delete(visita)
            }
        }
    }

    // MARK: Exportació a GPX i KML

    private func exportar(format: String) {
        let recompte = ExportadorBitacora.recompte(viatge)
        guard recompte.exportables > 0 else {
            missatge = "Cap visita té posició al mapa. Comparteix els llocs des d'Apple Maps o enganxa'n l'enllaç perquè en quedin les coordenades."
            return
        }
        let contingut = format == "gpx"
            ? ExportadorBitacora.gpx(viatge)
            : ExportadorBitacora.kml(viatge)
        let nom = ExportadorBitacora.nomArxiu(viatge, extensio: format)

        guard let url = ExportadorBitacora.arxiu(contingut, nom: nom) else {
            missatge = "No s'ha pogut crear l'arxiu."
            return
        }
        arxiuExportat = ArxiuExportat(url: url, format: format.uppercased(),
                                      visites: recompte.exportables,
                                      sensePosicio: recompte.sensePosicio)
    }

    @ViewBuilder
    private func fullaExportacio(_ arxiu: ArxiuExportat) -> some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: arxiu.format == "GPX" ? "figure.hiking" : "globe")
                    .font(.system(size: 54))
                    .foregroundStyle(.blue)
                VStack(spacing: 6) {
                    Text("\(arxiu.visites) \(arxiu.visites == 1 ? "visita" : "visites") a l'arxiu \(arxiu.format)")
                        .font(.title3.weight(.semibold))
                    if arxiu.sensePosicio > 0 {
                        Text("\(arxiu.sensePosicio) \(arxiu.sensePosicio == 1 ? "visita s'ha quedat fora" : "visites s'han quedat fora") perquè no tenen posició al mapa.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Text(arxiu.format == "GPX"
                         ? "Puja'l a Wikiloc, Komoot o Garmin per muntar-hi el recorregut."
                         : "Importa'l a Google My Maps o obre'l amb Google Earth.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                ShareLink(item: arxiu.url) {
                    Label("Comparteix o desa l'arxiu", systemImage: "square.and.arrow.up")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(28)
            .navigationTitle("Exporta la Bitàcora")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fet") { arxiuExportat = nil }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
    }

    // MARK: Enganxar un enllaç copiat d'Apple Maps

    private func enganxarDelPortapapers() {
        #if os(iOS)
        let text = UIPasteboard.general.string ?? UIPasteboard.general.url?.absoluteString ?? ""
        #else
        let text = NSPasteboard.general.string(forType: .string) ?? ""
        #endif

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let lloc = LectorAppleMaps.llegir(text: text) else {
            missatge = "No hi ha cap enllaç de lloc al porta-retalls. A Apple Maps: Compartir → Copia."
            return
        }
        let visita = VisitaBitacora(
            nom: lloc.nom, adreca: lloc.adreca, urlMaps: lloc.url,
            latitud: lloc.latitud, longitud: lloc.longitud,
            dataVisita: Date(), origen: VisitaBitacora.origenCompartit, viatge: viatge
        )
        context.insert(visita)
        visitaPerEditar = visita
    }
}

// MARK: - Formulari d'una visita

struct VisitaFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var visita: VisitaBitacora?

    @State private var nom = ""
    @State private var emoji = "📍"
    @State private var dataVisita = Date()
    @State private var adreca = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var mostrarEmojis = false
    @State private var cercant = false
    @State private var missatgeViqui = ""
    @State private var fotoDades: Data?
    @State private var fotoSeleccionada: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Lloc visitat") {
                    HStack(spacing: 12) {
                        Button {
                            mostrarEmojis = true
                        } label: {
                            Text(emoji)
                                .font(.system(size: 34))
                        }
                        .buttonStyle(.borderless)
                        TextField("P. ex. Temple Kiyomizu-dera", text: $nom)
                            .font(.title3)
                    }
                }
                Section("Dia i hora de la visita") {
                    DatePicker("Quan hi has estat", selection: $dataVisita)
                        .font(.body)
                }
                Section("Adreça") {
                    TextField("Opcional", text: $adreca)
                }
                Section("Enllaç d'Apple Maps") {
                    TextField("https://maps.apple.com/...", text: $url)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif
                    Button("Llegeix l'enllaç i omple el nom", systemImage: "wand.and.stars") {
                        llegirEnllac()
                    }
                    .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Foto") {
                    if let dades = fotoDades, let imatge = imatgeDesDades(dades) {
                        imatge
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity)
                        Button("Treu la foto", systemImage: "trash", role: .destructive) {
                            fotoDades = nil
                            fotoSeleccionada = nil
                        }
                    }
                    PhotosPicker(selection: $fotoSeleccionada, matching: .images) {
                        Label(fotoDades == nil ? "Puja una foto del carret" : "Canvia la foto", systemImage: "photo.on.rectangle")
                    }
                }
                Section("Notes") {
                    TextField("Què hi has fet, què t'ha semblat...", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                    Button {
                        Task { await buscarAViqui() }
                    } label: {
                        HStack {
                            Label("Busca la descripció a la Viquipèdia", systemImage: "magnifyingglass")
                            if cercant {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty || cercant)
                    if !missatgeViqui.isEmpty {
                        Text(missatgeViqui)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // "Edita la visita" no cal: el formulari ja és prou clar sense títol
            .navigationTitle(visita == nil ? "Nova visita" : "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
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
            .onChange(of: fotoSeleccionada) { _, nova in
                guard let nova else { return }
                Task {
                    if let dades = try? await nova.loadTransferable(type: Data.self) {
                        fotoDades = dades
                    }
                }
            }
            .onAppear {
                guard let visita else {
                    dataVisita = dataInicialSuggerida
                    return
                }
                nom = visita.nom
                emoji = visita.emoji
                dataVisita = visita.dataVisita
                adreca = visita.adreca
                url = visita.urlMaps
                notes = visita.notes
                fotoDades = visita.foto
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    /// Si avui cau dins del viatge fem servir ara; si no, l'inici del viatge
    private var dataInicialSuggerida: Date {
        let ara = Date()
        if ara >= viatge.dataInici && ara <= viatge.dataFi { return ara }
        return viatge.dataInici
    }

    private func llegirEnllac() {
        guard let lloc = LectorAppleMaps.llegir(text: url) else { return }
        if nom.isEmpty { nom = lloc.nom }
        if adreca.isEmpty { adreca = lloc.adreca }
    }

    /// Omple les notes amb el resum de la Viquipèdia del lloc
    private func buscarAViqui() async {
        cercant = true
        missatgeViqui = "Cercant a la Viquipèdia…"
        if let resum = await Viquipedia.resum(de: nom) {
            notes = notes.isEmpty ? resum.text : notes + "\n\n" + resum.text
            missatgeViqui = "Descripció afegida a les notes."
        } else {
            missatgeViqui = "No s'ha trobat cap article per a aquest nom."
        }
        cercant = false
    }

    private func desar() {
        var urlNeta = url.trimmingCharacters(in: .whitespaces)
        if !urlNeta.isEmpty && !urlNeta.lowercased().hasPrefix("http") {
            urlNeta = "https://" + urlNeta
        }
        let lloc = LectorAppleMaps.llegir(text: urlNeta)

        if let visita {
            visita.nom = nom
            visita.emoji = emoji
            visita.dataVisita = dataVisita
            visita.adreca = adreca
            visita.urlMaps = urlNeta
            visita.notes = notes
            visita.foto = fotoDades
            if let lloc, lloc.latitud != 0 || lloc.longitud != 0 {
                visita.latitud = lloc.latitud
                visita.longitud = lloc.longitud
            }
        } else {
            let nova = VisitaBitacora(
                nom: nom, notes: notes, adreca: adreca, urlMaps: urlNeta,
                latitud: lloc?.latitud ?? 0, longitud: lloc?.longitud ?? 0,
                dataVisita: dataVisita, emoji: emoji, viatge: viatge
            )
            nova.foto = fotoDades
            context.insert(nova)
        }
        dismiss()
    }
}
