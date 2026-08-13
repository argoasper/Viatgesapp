import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Documentació del viatge: bitllets, allotjament, entrades i altres
struct DocumentacioView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge

    @State private var mostrarNou = false
    @State private var documentPerEditar: DocumentViatge?

    var body: some View {
        List {
            ForEach(TipusDocument.allCases, id: \.rawValue) { tipus in
                let documents = viatge.documents(de: tipus.rawValue)
                if !documents.isEmpty {
                    Section("\(tipus.emoji) \(tipus.rawValue)") {
                        ForEach(documents) { document in
                            filaDocument(document)
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(documents[index]) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Documentació")
        .overlay {
            if viatge.documentsLlista.isEmpty {
                ContentUnavailableView(
                    "Cap document",
                    systemImage: "folder",
                    description: Text("Prem ＋ per afegir bitllets, allotjament o entrades.")
                )
            }
        }
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
                    Label("Nou document", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $mostrarNou) {
            DocumentFormView(viatge: viatge)
        }
        .sheet(item: $documentPerEditar) { document in
            DocumentFormView(viatge: viatge, document: document)
        }
    }

    @ViewBuilder
    private func filaDocument(_ document: DocumentViatge) -> some View {
        NavigationLink {
            DocumentDetailView(viatge: viatge, document: document)
        } label: {
            HStack(spacing: 12) {
                MiniaturaFitxer(dades: document.miniaturaDades, mida: 52)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(document.titol)
                            .font(.title3.weight(.semibold))
                        if document.nombreFitxers > 0 {
                            Text("📎 \(document.nombreFitxers)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(document.data.formatCatala(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    documentPerEditar = document
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
            Button("Edita", systemImage: "pencil") { documentPerEditar = document }
            Button("Esborra el document", systemImage: "trash", role: .destructive) {
                context.delete(document)
            }
        }
    }
}

// MARK: - Detall d'un document

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge
    @Bindable var document: DocumentViatge

    @State private var mostrarEdicio = false
    @State private var fitxerObert: FitxerDocument?

    var body: some View {
        List {
            Section {
                LabeledContent("Tipus", value: document.tipus)
                LabeledContent("Data", value: document.data.formatCatala(date: .long, time: .omitted))
            }

            if !document.notes.isEmpty {
                Section("Notes") {
                    Text(document.notes)
                        .font(.body)
                }
            }

            if !document.fitxersLlista.isEmpty {
                Section("Fitxers adjunts") {
                    ForEach(document.fitxersLlista) { fitxer in
                        Button {
                            obrir(fitxer)
                        } label: {
                            HStack(spacing: 12) {
                                MiniaturaFitxer(dades: fitxer.dades, mida: 60)
                                Text(fitxer.nomFitxer.isEmpty ? "Fitxer" : fitxer.nomFitxer)
                                    .font(.body)
                                    .lineLimit(2)
                                Spacer()
                                Image(systemName: "arrow.up.forward.app")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        let llista = document.fitxersLlista
                        for index in offsets { context.delete(llista[index]) }
                    }
                }
            }
        }
        .navigationTitle(document.titol)
        .toolbar {
            ToolbarItem {
                Button("Edita") { mostrarEdicio = true }
            }
        }
        .sheet(isPresented: $mostrarEdicio) {
            DocumentFormView(viatge: viatge, document: document)
        }
    }

    /// Desa el fitxer a una carpeta temporal i el mostra amb l'app del sistema
    private func obrir(_ fitxer: FitxerDocument) {
        guard let dades = fitxer.dades else { return }
        let nom = fitxer.nomFitxer.isEmpty ? "fitxer" : fitxer.nomFitxer
        let desti = FileManager.default.temporaryDirectory.appendingPathComponent(nom)
        do {
            try dades.write(to: desti, options: .atomic)
            #if os(macOS)
            NSWorkspace.shared.open(desti)
            #else
            UIApplication.shared.open(desti)
            #endif
        } catch {
            // Si no es pot escriure, no fem res: el fitxer segueix guardat a l'app
        }
    }
}

// MARK: - Miniatura d'un fitxer adjunt

struct MiniaturaFitxer: View {
    var dades: Data?
    var mida: CGFloat = 52

    var body: some View {
        Group {
            if let dades, let imatge = imatgeDe(dades) {
                imatge
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.gray.opacity(0.15)
                    Image(systemName: esPDF ? "doc.richtext" : "doc")
                        .font(.system(size: mida * 0.45))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: mida, height: mida)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var esPDF: Bool {
        guard let dades, dades.count > 4 else { return false }
        return dades.prefix(4).elementsEqual([0x25, 0x50, 0x44, 0x46]) // %PDF
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
}

// MARK: - Formulari d'un document

struct DocumentFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var viatge: Viatge
    var document: DocumentViatge?

    @State private var titol = ""
    @State private var tipus = TipusDocument.transport.rawValue
    @State private var data = Date()
    @State private var notes = ""
    @State private var fitxers: [FitxerNou] = []
    @State private var mostrarSelectorFitxers = false

    /// Fitxer pendent de desar (nou o ja existent)
    struct FitxerNou: Identifiable {
        var id = UUID()
        var nom: String
        var dades: Data?
        var existent: FitxerDocument?
    }

    var body: some View {
        NavigationStack {
            Form {
                seccioTitol
                seccioTipus
                seccioData
                seccioFitxers
                seccioNotes
            }
            .navigationTitle(document == nil ? "Nou document" : "Edita el document")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desa") { desar() }
                        .disabled(titol.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
            .fileImporter(isPresented: $mostrarSelectorFitxers,
                          allowedContentTypes: [.pdf, .image],
                          allowsMultipleSelection: true) { resultat in
                if case .success(let urls) = resultat {
                    afegir(urls)
                }
            }
            .onAppear { carregar() }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 600)
        #endif
    }

    // MARK: Seccions del formulari

    @ViewBuilder
    private var seccioTitol: some View {
        Section("Títol") {
            TextField("p. ex. Vol BCN → Tòquio", text: $titol)
                .font(.title3)
        }
    }

    @ViewBuilder
    private var seccioTipus: some View {
        Section("Tipus") {
            Picker("Tipus", selection: $tipus) {
                ForEach(TipusDocument.allCases, id: \.rawValue) { t in
                    Text("\(t.emoji) \(t.rawValue)").tag(t.rawValue)
                }
            }
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private var seccioData: some View {
        Section("Data") {
            DatePicker("Data", selection: $data, displayedComponents: .date)
        }
    }

    @ViewBuilder
    private var seccioFitxers: some View {
        Section("Fitxers adjunts (PDF o imatges)") {
            ForEach(fitxers) { fitxer in
                HStack(spacing: 12) {
                    MiniaturaFitxer(dades: fitxer.dades, mida: 46)
                    Text(fitxer.nom)
                        .font(.subheadline)
                        .lineLimit(2)
                    Spacer()
                }
            }
            .onDelete { offsets in
                fitxers.remove(atOffsets: offsets)
            }
            Button {
                mostrarSelectorFitxers = true
            } label: {
                Label("Afegeix fitxers", systemImage: "paperclip")
            }
        }
    }

    @ViewBuilder
    private var seccioNotes: some View {
        Section("Notes") {
            TextField("Localitzador, horaris, adreça...", text: $notes, axis: .vertical)
                .lineLimit(3...10)
        }
    }

    // MARK: Accions

    private func carregar() {
        guard let document else {
            data = viatge.dataInici
            return
        }
        titol = document.titol
        tipus = document.tipus
        data = document.data
        notes = document.notes
        fitxers = document.fitxersLlista.map {
            FitxerNou(nom: $0.nomFitxer.isEmpty ? "Fitxer" : $0.nomFitxer, dades: $0.dades, existent: $0)
        }
        // Còpies antigues amb un únic fitxer al propi document
        if let dadesAntigues = document.dades {
            fitxers.append(FitxerNou(nom: document.nomFitxer.isEmpty ? "fitxer" : document.nomFitxer,
                                     dades: dadesAntigues, existent: nil))
        }
    }

    private func afegir(_ urls: [URL]) {
        for url in urls {
            let calAturar = url.startAccessingSecurityScopedResource()
            defer { if calAturar { url.stopAccessingSecurityScopedResource() } }
            if let dades = try? Data(contentsOf: url) {
                fitxers.append(FitxerNou(nom: url.lastPathComponent, dades: dades))
            }
        }
    }

    private func desar() {
        let titolNet = titol.trimmingCharacters(in: .whitespaces)
        let doc: DocumentViatge

        if let document {
            doc = document
            doc.titol = titolNet
            doc.tipus = tipus
            doc.data = data
            doc.notes = notes
            // Esborrem els adjunts que l'usuari hagi tret
            let conservats = Set(fitxers.compactMap { $0.existent?.persistentModelID })
            for fitxer in doc.fitxersLlista where !conservats.contains(fitxer.persistentModelID) {
                context.delete(fitxer)
            }
            doc.dades = nil
            doc.nomFitxer = ""
        } else {
            doc = DocumentViatge(titol: titolNet, tipus: tipus, notes: notes, data: data, viatge: viatge)
            doc.ordre = viatge.documentsLlista.count
            context.insert(doc)
        }

        // Afegim els fitxers nous i reordenem
        for (index, fitxer) in fitxers.enumerated() {
            if let existent = fitxer.existent {
                existent.ordre = index
            } else {
                context.insert(FitxerDocument(nomFitxer: fitxer.nom, dades: fitxer.dades,
                                              ordre: index, document: doc))
            }
        }
        dismiss()
    }
}
