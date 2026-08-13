import SwiftUI
import MapKit
import CoreLocation

/// Mapa petit, no interactiu, centrat al destí del viatge. En tocar-lo obre
/// Apple Maps. Mentre encara no tenim coordenades (o si no s'han trobat),
/// mostra un avís en comptes d'un mapa buit.
struct MapaDestiView: View {
    var viatge: Viatge
    var alcada: CGFloat = 150

    @Environment(\.openURL) private var openURL
    @State private var posicio: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if viatge.teCoordenades {
                Map(position: $posicio, interactionModes: []) {
                    Marker(nomDesti, systemImage: "mappin", coordinate: coordenades)
                        .tint(.red)
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .overlay(alignment: .bottomTrailing) {
                    Label("Maps", systemImage: "arrow.up.forward.app")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                        .padding(8)
                }
                .onAppear { centrar() }
                .onChange(of: viatge.latitud) { _, _ in centrar() }
                .onTapGesture { obrirMaps() }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Obre \(nomDesti) a Maps")
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.thinMaterial)
                    VStack(spacing: 6) {
                        if viatge.geocodificacioIntentada {
                            Image(systemName: "mappin.slash")
                                .foregroundStyle(.secondary)
                            Text("No s'ha trobat el mapa d'aquest destí")
                        } else {
                            ProgressView()
                            Text("Cercant el mapa…")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(height: alcada)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var nomDesti: String {
        viatge.destinacio.isEmpty ? viatge.nom : viatge.destinacio
    }

    private var coordenades: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: viatge.latitud, longitude: viatge.longitud)
    }

    private func centrar() {
        posicio = .region(
            MKCoordinateRegion(center: coordenades,
                               span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15))
        )
    }

    private func obrirMaps() {
        if let url = viatge.urlAppleMaps { openURL(url) }
    }
}
