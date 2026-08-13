import SwiftUI

/// Icona emoji gran i en color (per a apartats, categories i files)
struct IconaEmoji: View {
    let emoji: String
    var mida: CGFloat = 30

    var body: some View {
        Text(emoji)
            .font(.system(size: mida))
            .frame(width: mida + 8, height: mida + 8)
    }
}

/// Icona estil Apple Maps (dibuixada amb els colors originals de l'app)
struct IconaAppleMaps: View {
    var mida: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mida * 0.22)
                .fill(Color(red: 0.96, green: 0.95, blue: 0.90))
            // parc verd
            Circle()
                .fill(Color(red: 0.66, green: 0.86, blue: 0.50))
                .frame(width: mida * 0.85, height: mida * 0.85)
                .offset(x: -mida * 0.32, y: mida * 0.38)
            // aigua blava
            Circle()
                .fill(Color(red: 0.58, green: 0.80, blue: 0.98))
                .frame(width: mida * 0.75, height: mida * 0.75)
                .offset(x: mida * 0.38, y: -mida * 0.36)
            // carretera groga
            Capsule()
                .fill(Color(red: 0.99, green: 0.79, blue: 0.28))
                .frame(width: mida * 0.14, height: mida * 1.5)
                .rotationEffect(.degrees(38))
            // carretera blanca
            Capsule()
                .fill(.white)
                .frame(width: mida * 0.11, height: mida * 1.5)
                .rotationEffect(.degrees(-32))
                .offset(x: -mida * 0.14)
            // fletxa de navegació
            Image(systemName: "location.north.fill")
                .font(.system(size: mida * 0.34, weight: .bold))
                .foregroundStyle(Color(red: 0.0, green: 0.45, blue: 0.95))
                .shadow(color: .white, radius: 1)
        }
        .frame(width: mida, height: mida)
        .clipShape(RoundedRectangle(cornerRadius: mida * 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: mida * 0.22)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

/// Icona estil Google Maps (dibuixada amb els colors originals de l'app)
struct IconaGoogleMaps: View {
    var mida: CGFloat = 38

    var body: some View {
        ZStack {
            // quatre zones de color del mapa
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color(red: 0.26, green: 0.52, blue: 0.96) // blau
                    Color(red: 0.22, green: 0.66, blue: 0.34) // verd
                }
                HStack(spacing: 0) {
                    Color(red: 0.98, green: 0.75, blue: 0.03) // groc
                    Color(red: 0.91, green: 0.93, blue: 0.94) // gris clar
                }
            }
            // carretera blanca diagonal
            Capsule()
                .fill(.white)
                .frame(width: mida * 0.13, height: mida * 1.6)
                .rotationEffect(.degrees(45))
            // pin vermell característic
            Image(systemName: "mappin")
                .font(.system(size: mida * 0.55, weight: .bold))
                .foregroundStyle(Color(red: 0.92, green: 0.26, blue: 0.21))
                .shadow(color: .white.opacity(0.9), radius: 1)
        }
        .frame(width: mida, height: mida)
        .clipShape(RoundedRectangle(cornerRadius: mida * 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: mida * 0.22)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

/// Icona estil Wikiloc (verd amb camí i punt de ruta)
struct IconaWikiloc: View {
    var mida: CGFloat = 38

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: mida * 0.22)
                .fill(Color(red: 0.29, green: 0.64, blue: 0.24))
            // camí de la ruta
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: mida * 0.11, height: mida * 0.62)
                .rotationEffect(.degrees(35))
                .offset(x: -mida * 0.12, y: mida * 0.14)
            Capsule()
                .fill(.white.opacity(0.9))
                .frame(width: mida * 0.11, height: mida * 0.4)
                .rotationEffect(.degrees(-30))
                .offset(x: mida * 0.14, y: -mida * 0.05)
            // punt de destinació
            Image(systemName: "mappin")
                .font(.system(size: mida * 0.42, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: mida * 0.2, y: -mida * 0.24)
        }
        .frame(width: mida, height: mida)
        .clipShape(RoundedRectangle(cornerRadius: mida * 0.22))
        .overlay(
            RoundedRectangle(cornerRadius: mida * 0.22)
                .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
        )
    }
}

#Preview {
    HStack(spacing: 20) {
        IconaEmoji(emoji: "🧳", mida: 34)
        IconaAppleMaps()
        IconaGoogleMaps()
        IconaWikiloc()
    }
    .padding()
}
