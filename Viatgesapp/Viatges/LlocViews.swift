import SwiftUI
import SwiftData
import PhotosUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Detall d'un lloc d'interès

struct LlocDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var lloc: LlocInteres

    @State private var mostrarEdicio = false
    @State private var fotosSeleccionades: [PhotosPickerItem] = []

    var body: some View {
        List {
            seccioVisitat
            seccioDescripcio
            seccioMapes
            seccioEnllacos
            seccioFotos
        }
        .navigationTitle(lloc.nom)
        .toolbar {
            ToolbarItem {
                Button("Edita") { mostrarEdicio = true }
            }
        }
        .sheet(isPresented: $mostrarEdicio) {
            if let zona = lloc.zona {
                LlocFormView(zona: zona, lloc: lloc)
            }
        }
        .onChange(of: fotosSeleccionades) { _, noves in
            Task { await carregarFotos(noves) }
        }
    }

    // MARK: Seccions

    @ViewBuilder
    private var seccioVisitat: some View {
        Section {
            HStack {
                Text("Visitat")
                    .font(.title3)
                Spacer()
                Button {
                    lloc.visitat.toggle()
                } label: {
                    Image(systemName: lloc.visitat ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundStyle(lloc.visitat ? .green : .secondary)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var seccioDescripcio: some View {
        if !lloc.descripcio.isEmpty {
            Section("Descripció") {
                Text(lloc.descripcio)
                    .font(.body)
                if !lloc.fontDescripcio.isEmpty, let font = URL(string: lloc.fontDescripcio) {
                    Link(destination: font) {
                        Label("Font original de la informació", systemImage: "link")
                            .font(.subheadline)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var seccioMapes: some View {
        Section("Mapes") {
            if let url = lloc.urlAppleMaps {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        IconaAppleMaps(mida: 34)
                        Text("Obre a Apple Maps").font(.title3)
                    }
                }
            }
            if let url = lloc.urlGoogleMaps {
                Link(destination: url) {
                    HStack(spacing: 12) {
                        IconaGoogleMaps(mida: 34)
                        Text("Obre a Google Maps").font(.title3)
                    }
                }
            }
            ForEach(lloc.enllacosWikiloc) { enllac in
                filaWikiloc(enllac)
            }
        }
    }

    @ViewBuilder
    private func filaWikiloc(_ enllac: EnllacLloc) -> some View {
        if let url = URL(string: enllac.url) {
            Link(destination: url) {
                HStack(spacing: 12) {
                    IconaWikiloc(mida: 34)
                    Text(enllac.titol.isEmpty ? "Ruta de Wikiloc" : enllac.titol)
                        .font(.title3)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var seccioEnllacos: some View {
        Section("Enllaços addicionals (YouTube, webs...)") {
            ForEach(lloc.enllacosGenerals) { enllac in
                filaEnllac(enllac)
            }
            .onDelete { offsets in
                let llista = lloc.enllacosGenerals
                for index in offsets { context.delete(llista[index]) }
            }
            if lloc.enllacosGenerals.isEmpty {
                Text("Cap enllaç. Edita el lloc per afegir-ne.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func filaEnllac(_ enllac: EnllacLloc) -> some View {
        if let url = URL(string: enllac.url) {
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.blue)
                    Text(enllac.titol.isEmpty ? enllac.url : enllac.titol)
                        .font(.body)
                        .lineLimit(1)
                }
            }
            .contextMenu {
                Button("Esborra l'enllaç", systemImage: "trash", role: .destructive) {
                    context.delete(enllac)
                }
            }
        }
    }

    @ViewBuilder
    private var seccioFotos: some View {
        Section("Fotos personals") {
            PhotosPicker(selection: $fotosSeleccionades, matching: .images) {
                Label("Afegeix fotos", systemImage: "camera")
            }
            if !lloc.fotosLlista.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
                    ForEach(lloc.fotosLlista) { foto in
                        miniatura(foto)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func miniatura(_ foto: Foto) -> some View {
        ZStack(alignment: .topTrailing) {
            if let dades = foto.dades, let imatge = imatgeDe(dades) {
                imatge
                    .resizable()
                    .scaledToFill()
                    .frame(height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 96)
            }
            Button {
                context.delete(foto)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
            .offset(x: 6, y: -6)
        }
    }

    private func imatgeDe(_ dades: Data) -> Image? {
        #if os(macOS)
        guard let ns = NSImage(data: dades) else { return nil }
        return Image(nsImage: ns)
        #else
        guard let ui = UIImage(data: dades) else { return nil }
        return Image(uiImage: ui)
        #endif
    }

    private func carregarFotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let dades = try? await item.loadTransferable(type: Data.self) {
                context.insert(Foto(dades: dades, lloc: lloc))
            }
        }
        fotosSeleccionades = []
    }
}

// MARK: - Formulari d'un lloc d'interès

struct LlocFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var zona: Zona
    var lloc: LlocInteres?

    @State private var nom = ""
    @State private var descripcio = ""
    @State private var fontDescripcio = ""
    @State private var cercaPersonalitzada = ""
    @State private var urlMaps = ""
    @State private var urlMapsGoogle = ""
    @State private var enllacos: [EnllacNou] = []

    @State private var titolNou = ""
    @State private var urlNova = ""
    @State private var tipusNou = EnllacLloc.tipusGeneral
    @State private var cercant = false
    @State private var missatgeViqui = ""

    /// Enllaç pendent de desar (nou o ja existent)
    struct EnllacNou: Identifiable {
        var id = UUID()
        var titol: String
        var url: String
        var tipus: String
        var existent: EnllacLloc?
    }

    var body: some View {
        NavigationStack {
            Form {
                seccioNom
                seccioDescripcio
                seccioFont
                seccioMapes
                seccioEnllacos
            }
            .navigationTitle(lloc == nil ? "Nou lloc d'interès" : "Edita el lloc")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { desar() }
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .onAppear { carregar() }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 640)
        #endif
    }

    // MARK: Seccions del formulari

    @ViewBuilder
    private var seccioNom: some View {
        Section("Nom del lloc") {
            TextField("p. ex. Fushimi Inari", text: $nom)
                .font(.title3)
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

    @ViewBuilder
    private var seccioDescripcio: some View {
        Section("Descripció") {
            TextField("Què és, què s'hi pot veure...", text: $descripcio, axis: .vertical)
                .lineLimit(5...15)
        }
    }

    @ViewBuilder
    private var seccioFont: some View {
        Section("Enllaç de la font (opcional)") {
            campURL("https://...", text: $fontDescripcio)
        }
    }

    @ViewBuilder
    private var seccioMapes: some View {
        Section("Mapes") {
            TextField("Text de cerca dels mapes (opcional)", text: $cercaPersonalitzada)
            campURL("Enllaç Apple Maps (opcional)", text: $urlMaps)
            campURL("Enllaç Google Maps (opcional)", text: $urlMapsGoogle)
        }
    }

    @ViewBuilder
    private var seccioEnllacos: some View {
        Section("Enllaços (Wikiloc, YouTube, webs...)") {
            ForEach(enllacos) { enllac in
                HStack(spacing: 10) {
                    Image(systemName: enllac.tipus == EnllacLloc.tipusWikiloc ? "figure.hiking" : "link")
                        .foregroundStyle(.blue)
                    Text(enllac.titol.isEmpty ? enllac.url : enllac.titol)
                        .font(.body)
                        .lineLimit(1)
                }
            }
            .onDelete { offsets in
                enllacos.remove(atOffsets: offsets)
            }

            TextField("Títol", text: $titolNou)
            Picker("Tipus", selection: $tipusNou) {
                Text("Enllaç").tag(EnllacLloc.tipusGeneral)
                Text("Wikiloc").tag(EnllacLloc.tipusWikiloc)
            }
            .pickerStyle(.segmented)
            HStack {
                campURL("https://...", text: $urlNova)
                Button {
                    afegirEnllac()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.borderless)
                .disabled(urlNova.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// Camp de text preparat per escriure adreces web
    @ViewBuilder
    private func campURL(_ titol: String, text: Binding<String>) -> some View {
        TextField(titol, text: text)
            #if os(iOS)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            #endif
    }

    // MARK: Accions

    private func carregar() {
        guard let lloc else { return }
        nom = lloc.nom
        descripcio = lloc.descripcio
        fontDescripcio = lloc.fontDescripcio
        cercaPersonalitzada = lloc.cercaPersonalitzada
        urlMaps = lloc.urlMaps
        urlMapsGoogle = lloc.urlMapsGoogle
        enllacos = lloc.enllacosLlista.map {
            EnllacNou(titol: $0.titol, url: $0.url, tipus: $0.tipus, existent: $0)
        }
    }

    private func afegirEnllac() {
        var url = urlNova.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        if !url.lowercased().hasPrefix("http") { url = "https://" + url }
        enllacos.append(EnllacNou(titol: titolNou.trimmingCharacters(in: .whitespaces),
                                  url: url, tipus: tipusNou))
        titolNou = ""
        urlNova = ""
    }

    private func buscarAViqui() async {
        cercant = true
        missatgeViqui = "Cercant a la Viquipèdia…"
        if let resum = await Viquipedia.resum(de: nom) {
            descripcio = resum.text
            fontDescripcio = resum.font
            missatgeViqui = "Descripció trobada."
        } else {
            missatgeViqui = "No s'ha trobat cap article. Pots escriure-la a mà."
        }
        cercant = false
    }

    private func netejar(_ text: String) -> String {
        var net = text.trimmingCharacters(in: .whitespaces)
        if !net.isEmpty && !net.lowercased().hasPrefix("http") { net = "https://" + net }
        return net
    }

    private func desar() {
        let nomNet = nom.trimmingCharacters(in: .whitespaces)
        let desti: LlocInteres

        if let lloc {
            desti = lloc
            desti.nom = nomNet
            desti.descripcio = descripcio
            desti.fontDescripcio = netejar(fontDescripcio)
            desti.cercaPersonalitzada = cercaPersonalitzada.trimmingCharacters(in: .whitespaces)
            desti.urlMaps = netejar(urlMaps)
            desti.urlMapsGoogle = netejar(urlMapsGoogle)
            // Traiem els enllaços que l'usuari hagi esborrat
            let conservats = Set(enllacos.compactMap { $0.existent?.persistentModelID })
            for enllac in desti.enllacosLlista where !conservats.contains(enllac.persistentModelID) {
                context.delete(enllac)
            }
        } else {
            desti = LlocInteres(nom: nomNet, descripcio: descripcio,
                                urlMaps: netejar(urlMaps),
                                ordre: zona.llocsLlista.count, zona: zona)
            desti.fontDescripcio = netejar(fontDescripcio)
            desti.cercaPersonalitzada = cercaPersonalitzada.trimmingCharacters(in: .whitespaces)
            desti.urlMapsGoogle = netejar(urlMapsGoogle)
            context.insert(desti)
        }

        for (index, enllac) in enllacos.enumerated() {
            if let existent = enllac.existent {
                existent.titol = enllac.titol
                existent.url = enllac.url
                existent.tipus = enllac.tipus
                existent.ordre = index
            } else {
                context.insert(EnllacLloc(titol: enllac.titol, url: enllac.url,
                                          tipus: enllac.tipus, ordre: index, lloc: desti))
            }
        }
        dismiss()
    }
}
