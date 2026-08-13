import SwiftUI
import SwiftData

/// Pantalla principal d'un viatge: capçalera gran amb el fons il·lustrat del
/// destí, un mapa petit i els apartats a sota
struct ViatgeDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var viatge: Viatge
    @State private var mostrarEdicio = false

    private var empaquetats: Int {
        viatge.equipatgeLlista.filter(\.empaquetat).count
    }

    /// Durada del viatge en dies (mínim 1)
    private var diesViatge: Int {
        let calendari = Calendar.current
        let inici = calendari.startOfDay(for: viatge.dataInici)
        let fi = calendari.startOfDay(for: viatge.dataFi)
        let dies = calendari.dateComponents([.day], from: inici, to: fi).day ?? 0
        return max(1, dies + 1)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                capçalera
                if !viatge.notes.isEmpty {
                    notesTarget
                }
                MapaDestiView(viatge: viatge, alcada: 160)
                    .padding(.horizontal, 16)
                apartats
            }
            .padding(.bottom, 24)
        }
        .navigationTitle(viatge.nom)
        .toolbar {
            ToolbarItem {
                ShareLink(
                    item: ResumViatge.text(viatge),
                    subject: Text(viatge.nom.isEmpty ? "Viatge" : viatge.nom),
                    message: Text("Resum del viatge")
                ) {
                    Label("Comparteix el viatge", systemImage: "square.and.arrow.up")
                }
                .help("Comparteix totes les dades del viatge (Mail, Notes, Missatges...)")
            }
            ToolbarItem {
                Button("Edita") { mostrarEdicio = true }
            }
        }
        .sheet(isPresented: $mostrarEdicio) {
            ViatgeFormView(viatge: viatge)
        }
        // Es torna a executar si canvia el destí (o el nom, quan no hi ha destí)
        .task(id: "\(viatge.destinacio)|\(viatge.nom)") {
            await GeocodificadorDestinacions.geocodifica(viatge)
            try? context.save()
        }
    }

    // MARK: Capçalera

    private var capçalera: some View {
        ZStack(alignment: .bottomLeading) {
            PortadaViatgeView(viatge: viatge)

            LinearGradient(colors: [.clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 8) {
                Text(viatge.emoji)
                    .font(.system(size: 28))
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.25), in: Circle())

                Text(viatge.nom.isEmpty ? "Sense nom" : viatge.nom)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                HStack(spacing: 10) {
                    if !viatge.destinacio.isEmpty {
                        Label(viatge.destinacio, systemImage: "mappin.and.ellipse")
                    }
                    Label {
                        Text("\(viatge.dataInici.formatCatala(date: .abbreviated, time: .omitted)) – \(viatge.dataFi.formatCatala(date: .abbreviated, time: .omitted))")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

                Text("\(diesViatge) \(diesViatge == 1 ? "dia" : "dies")")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.22), in: Capsule())
            }
            .padding(14)
        }
        .frame(height: 190)
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 24,
                                   bottomTrailingRadius: 24, topTrailingRadius: 0,
                                   style: .continuous)
        )
    }

    // MARK: Notes

    private var notesTarget: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Notes", systemImage: "note.text")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(viatge.notes)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16)
    }

    // MARK: Apartats
    //
    // Es defineixen com a llista perquè es puguin amagar: si no fas servir
    // l'Itinerari en una escapada curta, per exemple, el pots treure de la
    // vista sense perdre'n les dades (es queda "amagat" a sota, a punt de
    // tornar-hi quan vulguis).

    private var definicionsApartats: [DefinicioApartat] {
        [
            DefinicioApartat(
                id: "equipatge", emoji: "🧳", titol: "Equipatge",
                valor: viatge.equipatgeLlista.isEmpty ? nil : "\(empaquetats)/\(viatge.equipatgeLlista.count)",
                visible: viatge.apartatEquipatgeVisible,
                amaga: { viatge.apartatEquipatgeVisible = false },
                mostra: { viatge.apartatEquipatgeVisible = true },
                destinacio: { AnyView(EquipatgeView(viatge: viatge)) }
            ),
            DefinicioApartat(
                id: "documentacio", emoji: "🗂️", titol: "Documentació",
                valor: viatge.documentsLlista.isEmpty ? nil : "\(viatge.documentsLlista.count)",
                visible: viatge.apartatDocumentacioVisible,
                amaga: { viatge.apartatDocumentacioVisible = false },
                mostra: { viatge.apartatDocumentacioVisible = true },
                destinacio: { AnyView(DocumentacioView(viatge: viatge)) }
            ),
            DefinicioApartat(
                id: "horaris", emoji: "🕒", titol: "Horaris",
                valor: viatge.horarisLlista.isEmpty ? nil : "\(viatge.horarisLlista.count)",
                visible: viatge.apartatHorarisVisible,
                amaga: { viatge.apartatHorarisVisible = false },
                mostra: { viatge.apartatHorarisVisible = true },
                destinacio: { AnyView(HorarisView(viatge: viatge)) }
            ),
            DefinicioApartat(
                id: "itinerari", emoji: "🗺️", titol: "Itinerari",
                valor: viatge.zonesLlista.isEmpty ? nil : "\(viatge.zonesLlista.count)",
                visible: viatge.apartatItinerariVisible,
                amaga: { viatge.apartatItinerariVisible = false },
                mostra: { viatge.apartatItinerariVisible = true },
                destinacio: { AnyView(TrajecteView(viatge: viatge)) }
            ),
            DefinicioApartat(
                id: "altres", emoji: "📝", titol: viatge.nomApartatAltres,
                valor: viatge.altresLlista.isEmpty ? nil : "\(viatge.altresLlista.count)",
                visible: viatge.apartatAltresVisible,
                amaga: { viatge.apartatAltresVisible = false },
                mostra: { viatge.apartatAltresVisible = true },
                destinacio: { AnyView(AltresView(viatge: viatge)) }
            ),
        ]
    }

    private var apartats: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(definicionsApartats.filter(\.visible)) { def in
                NavigationLink {
                    def.destinacio()
                } label: {
                    filaApartat(emoji: def.emoji, titol: def.titol, valor: def.valor)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Amaga aquest apartat", systemImage: "eye.slash") { def.amaga() }
                }
            }

            let amagats = definicionsApartats.filter { !$0.visible }
            if !amagats.isEmpty {
                apartatsAmagats(amagats)
            }
        }
        .padding(.horizontal, 16)
    }

    private func filaApartat(emoji: String, titol: String, valor: String?) -> some View {
        HStack(spacing: 12) {
            IconaEmoji(emoji: emoji, mida: 34)
            Text(titol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            if let valor {
                Text(valor)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Franja amb els apartats que has amagat, per tornar-los a mostrar amb un toc
    private func apartatsAmagats(_ amagats: [DefinicioApartat]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amagats")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            ForEach(amagats) { def in
                Button {
                    def.mostra()
                } label: {
                    HStack(spacing: 8) {
                        Text(def.emoji)
                        Text("Mostra \(def.titol)")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Un apartat de la pantalla del viatge, amb el que cal per mostrar-lo,
/// amagar-lo o tornar-lo a mostrar
private struct DefinicioApartat: Identifiable {
    let id: String
    let emoji: String
    let titol: String
    let valor: String?
    let visible: Bool
    let amaga: () -> Void
    let mostra: () -> Void
    let destinacio: () -> AnyView
}
