import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#else
import AppKit
#endif

@main
struct ViatgesApp: App {
    @State private var mostrarPortada = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .dynamicTypeSize(.xLarge) // lletra més gran a tota l'app
                    // Calendaris i selectors de data en català, encara que el
                    // mòbil estigui en un altre idioma
                    .environment(\.locale, localeCatala)

                if mostrarPortada {
                    PortadaView {
                        amagarPortada()
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .onAppear {
                // La portada es mostra 2,5 segons i s'esvaeix sola
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    amagarPortada()
                }
            }
        }
        .modelContainer(for: Viatge.self)
    }

    private func amagarPortada() {
        guard mostrarPortada else { return }
        withAnimation(.easeOut(duration: 0.7)) {
            mostrarPortada = false
        }
    }
}

/// Primera pàgina que es veu en obrir l'app (un toc la salta)
struct PortadaView: View {
    var enTocar: () -> Void

    /// La imatge de portada és opcional: si no hi és, ensenyem una portada senzilla
    private var teImatge: Bool {
        #if os(iOS)
        UIImage(named: "PrimeraPagina") != nil
        #else
        NSImage(named: "PrimeraPagina") != nil
        #endif
    }

    var body: some View {
        GeometryReader { geometria in
            if teImatge {
                Image("PrimeraPagina")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometria.size.width, height: geometria.size.height)
                    .clipped()
            } else {
                VStack(spacing: 16) {
                    Text("✈️").font(.system(size: 90))
                    Text("Viatges").font(.largeTitle.bold())
                }
                .frame(width: geometria.size.width, height: geometria.size.height)
            }
        }
        .ignoresSafeArea()
        .background(Color(red: 0.98, green: 0.94, blue: 0.95))
        .contentShape(Rectangle())
        .onTapGesture {
            enTocar()
        }
    }
}
