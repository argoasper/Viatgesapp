import SwiftUI
import CoreLocation
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Fons il·lustrat de cada viatge
//
// L'app no té cap servei de fotos d'internet connectat, així que en comptes
// d'una foto real dibuixem una escena de capvespre. Perquè no totes surtin
// tallades pel mateix patró, hi ha diversos "tipus" d'escena (platja,
// muntanya, ciutat, desert, natura) amb la seva pròpia composició de formes;
// es tria segons paraules del destí i, quan el tenim, segons el que el
// geocodificador sap realment del lloc (si és vora mar, per exemple). Els
// colors surten d'un hash del text, així que el mateix destí sempre dona el
// mateix resultat, sense connexió ni permisos.

enum TipusEscena: String, CaseIterable {
    case platja, muntanya, ciutat, desert, natura, generica
}

/// Paleta i composició calculades a partir del text del destí
struct EstilViatge {
    private let matis: Double        // 0...1, "color d'identitat" del destí
    private let despl: CGFloat       // -0.3...0.3, on cau la resplendor
    let tipusEscena: TipusEscena
    let punts: [PuntDecoratiu]
    /// Valors aleatoris (0...1) amb llavor fixa, perquè cada escena hi
    /// dibuixi les seves formes (edificis, pics, arbres...) sempre igual
    /// per a un mateix destí
    let valors: [Double]

    /// `escenaResolta` és el tipus que ja hem esbrinat amb el geocodificador
    /// (mar, llac...); si encara no el tenim, es fa una estimació ràpida a
    /// partir només del text del destí.
    init(destinacio: String, nom: String, escenaResolta: String = "") {
        let text = EstilViatge.textBase(destinacio: destinacio, nom: nom)
        let hash = EstilViatge.hashEstable(text)
        self.matis = Double(hash % 360) / 360
        self.despl = CGFloat(Double((hash / 360) % 100) / 100 - 0.5) * 0.6
        self.tipusEscena = TipusEscena(rawValue: escenaResolta) ?? EstilViatge.tipus(per: text)

        var generador = SeedableGenerator(seed: UInt64(hash))
        self.punts = (0..<7).map { _ in
            PuntDecoratiu(
                x: Double.random(in: 0.06...0.94, using: &generador),
                y: Double.random(in: 0.05...0.38, using: &generador),
                mida: Double.random(in: 2...4.5, using: &generador)
            )
        }
        self.valors = (0..<16).map { _ in Double.random(in: 0...1, using: &generador) }
    }

    /// Degradat de cel de capvespre: fosc a dalt, càlid al mig, fosc a baix
    var colorsCel: [Color] {
        [
            Color(hue: matisCel, saturation: 0.45, brightness: 0.30),
            Color(hue: matis, saturation: 0.60, brightness: 0.80),
            Color(hue: matis, saturation: 0.55, brightness: 0.32),
        ]
    }

    var colorResplendor: Color {
        Color(hue: matis, saturation: 0.30, brightness: 0.97)
    }

    var colorSilueta: Color {
        Color(hue: matis, saturation: 0.5, brightness: 0.22)
    }

    var desplacamentResplendor: CGFloat { despl }

    /// A quina alçada (fracció de l'alt, 0 = dalt) cau el sol/lluna, segons l'escena
    var alcadaResplendor: CGFloat {
        switch tipusEscena {
        case .platja: 0.5
        case .desert: 0.3
        case .muntanya: 0.22
        case .ciutat: 0.15
        case .natura: 0.2
        case .generica: 0.18
        }
    }

    private var matisCel: Double {
        (matis + 0.5).truncatingRemainder(dividingBy: 1)
    }

    private static func textBase(destinacio: String, nom: String) -> String {
        let d = destinacio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !d.isEmpty { return d }
        let n = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "viatge" : n
    }

    /// Hash estable entre execucions (String.hashValue de Swift varia cada cop que s'obre l'app)
    private static func hashEstable(_ text: String) -> Int {
        var hash: UInt64 = 5381
        for byte in text.lowercased().utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return Int(hash % 100_000)
    }

    /// Tipus d'escena segons paraules clau del destí (català, castellà, anglès);
    /// per defecte, una ciutat
    private static func tipus(per text: String) -> TipusEscena {
        let t = text.lowercased()
        let platja = ["platja", "playa", "beach", "costa", "litoral", "carib", "illa ", "island", "cala"]
        let muntanya = ["muntanya", "montaña", "mountain", "alps", "alpes", "pirineus", "pirineos", "neu", "nieve", "snow", "esquí", "esqui", "ski"]
        let desert = ["desert", "desierto", "sàhara", "sahara"]
        let natura = ["bosc", "bosque", "forest", "selva", "jungle", "amazon", "parc natural", "parc nacional", "parque nacional"]

        if platja.contains(where: { t.contains($0) }) { return .platja }
        if muntanya.contains(where: { t.contains($0) }) { return .muntanya }
        if desert.contains(where: { t.contains($0) }) { return .desert }
        if natura.contains(where: { t.contains($0) }) { return .natura }
        if t.isEmpty { return .generica }
        return .ciutat
    }

    /// Tipus d'escena a partir del que el geocodificador sap realment del
    /// lloc, no només del text que has escrit. Per exemple "Sant Antoni de
    /// Calonge" no conté cap paraula de platja, però el geocodificador sap
    /// que és vora mar i li posem l'escena de platja igualment.
    static func escena(perPlacemark lloc: CLPlacemark, textDesti: String) -> TipusEscena {
        let perText = tipus(per: textDesti)
        if perText != .ciutat { return perText }

        if lloc.ocean != nil || lloc.inlandWater != nil { return .platja }
        if let arees = lloc.areasOfInterest {
            for area in arees {
                let t = tipus(per: area)
                if t != .ciutat { return t }
            }
        }
        return perText
    }
}

/// Un puntet decoratiu (estrella) al cel, en coordenades relatives (0...1)
struct PuntDecoratiu: Hashable {
    var x: Double
    var y: Double
    var mida: Double
}

/// Generador d'aleatorietat amb llavor fixa, perquè les formes surtin
/// sempre al mateix lloc per a un mateix destí
struct SeedableGenerator: RandomNumberGenerator {
    private var estat: UInt64
    init(seed: UInt64) { estat = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        estat ^= estat << 13
        estat ^= estat >> 7
        estat ^= estat << 17
        return estat
    }
}

/// Vista del fons il·lustrat: es fa servir tant a la targeta petita de la
/// llista com a la capçalera gran de la pantalla del viatge
struct PortadaViatgeView: View {
    var viatge: Viatge

    private var estil: EstilViatge {
        EstilViatge(destinacio: viatge.destinacio, nom: viatge.nom, escenaResolta: viatge.tipusEscenaPortada)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let dades = viatge.fotoPortada, let imatge = Self.imatge(de: dades) {
                    imatge
                        .resizable()
                        .scaledToFill()
                } else {
                    let e = estil
                    LinearGradient(colors: e.colorsCel, startPoint: .top, endPoint: .bottom)

                    Circle()
                        .fill(e.colorResplendor)
                        .frame(width: geo.size.height * 1.15, height: geo.size.height * 1.15)
                        .blur(radius: geo.size.height * 0.18)
                        .opacity(0.85)
                        .offset(x: geo.size.width * e.desplacamentResplendor,
                                y: geo.size.height * (e.alcadaResplendor - 0.5))

                    ForEach(e.punts, id: \.self) { p in
                        Circle()
                            .fill(.white.opacity(0.55))
                            .frame(width: p.mida, height: p.mida)
                            .position(x: geo.size.width * p.x, y: geo.size.height * p.y)
                    }

                    EscenaSilueta(estil: e, mida: geo.size)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    /// Fotos reals de la Viquipèdia, guardades com a `Data`; cal decodificar-les
    /// diferent a iOS (UIImage) que al Mac (NSImage)
    private static func imatge(de dades: Data) -> Image? {
        #if os(iOS)
        guard let imatge = UIImage(data: dades) else { return nil }
        return Image(uiImage: imatge)
        #else
        guard let imatge = NSImage(data: dades) else { return nil }
        return Image(nsImage: imatge)
        #endif
    }
}

// MARK: - Siluetes de cada tipus d'escena

private struct EscenaSilueta: View {
    let estil: EstilViatge
    let mida: CGSize

    var body: some View {
        switch estil.tipusEscena {
        case .platja: EscenaPlatja(estil: estil, mida: mida)
        case .muntanya: EscenaMuntanya(estil: estil, mida: mida)
        case .ciutat: EscenaCiutat(estil: estil, mida: mida)
        case .desert: EscenaDesert(estil: estil, mida: mida)
        case .natura: EscenaNatura(estil: estil, mida: mida)
        case .generica: EscenaGenerica(estil: estil, mida: mida)
        }
    }
}

/// Perfil de ciutat: edificis d'alçades diferents arran de terra
private struct EscenaCiutat: View {
    let estil: EstilViatge
    let mida: CGSize
    private let nEdificis = 7

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<nEdificis, id: \.self) { i in
                let alt = 0.26 + estil.valors[i % estil.valors.count] * 0.44
                Rectangle()
                    .fill(estil.colorSilueta.opacity(0.88))
                    .frame(height: mida.height * alt)
            }
        }
        .frame(width: mida.width, height: mida.height, alignment: .bottom)
    }
}

/// Serralada: pics irregulars arran de terra
private struct EscenaMuntanya: View {
    let estil: EstilViatge
    let mida: CGSize
    private let nPunts = 6

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: mida.height))
            for i in 0...nPunts {
                let x = mida.width * CGFloat(i) / CGFloat(nPunts)
                let esAlaVora = i == 0 || i == nPunts
                let jitter = estil.valors[i % estil.valors.count]
                let y = esAlaVora ? mida.height : mida.height * (0.28 + jitter * 0.4)
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: mida.width, y: mida.height))
            path.closeSubpath()
        }
        .fill(estil.colorSilueta.opacity(0.88))
    }
}

/// Platja: horitzó, mar amb un parell d'onades suaus
private struct EscenaPlatja: View {
    let estil: EstilViatge
    let mida: CGSize

    var body: some View {
        let horitzo = mida.height * 0.64
        ZStack {
            Rectangle()
                .fill(estil.colorSilueta.opacity(0.5))
                .frame(width: mida.width, height: max(0, mida.height - horitzo))
                .position(x: mida.width / 2, y: horitzo + (mida.height - horitzo) / 2)

            ForEach(0..<2, id: \.self) { i in
                let y = horitzo + (mida.height - horitzo) * (CGFloat(i) + 1) / 3
                let corba = CGFloat(estil.valors[(i + 5) % estil.valors.count] - 0.5) * 12
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addQuadCurve(to: CGPoint(x: mida.width, y: y),
                                      control: CGPoint(x: mida.width / 2, y: y + corba))
                }
                .stroke(Color.white.opacity(0.28), lineWidth: 1.5)
            }
        }
        .frame(width: mida.width, height: mida.height)
    }
}

/// Desert: dunes arrodonides en dues capes
private struct EscenaDesert: View {
    let estil: EstilViatge
    let mida: CGSize

    var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<2, id: \.self) { i in
                let base = mida.height * (0.8 - CGFloat(i) * 0.16)
                let amplitud = 16 + CGFloat(estil.valors[(i + 8) % estil.valors.count]) * 16
                Path { path in
                    path.move(to: CGPoint(x: 0, y: mida.height))
                    path.addLine(to: CGPoint(x: 0, y: base))
                    path.addQuadCurve(to: CGPoint(x: mida.width, y: base),
                                      control: CGPoint(x: mida.width / 2, y: base - amplitud))
                    path.addLine(to: CGPoint(x: mida.width, y: mida.height))
                    path.closeSubpath()
                }
                .fill(estil.colorSilueta.opacity(0.5 + Double(i) * 0.3))
            }
        }
        .frame(width: mida.width, height: mida.height, alignment: .bottom)
    }
}

/// Natura: una filera d'arbrets de mides diferents
private struct EscenaNatura: View {
    let estil: EstilViatge
    let mida: CGSize
    private let nArbres = 11

    var body: some View {
        ZStack {
            ForEach(0..<nArbres, id: \.self) { i in
                let v = estil.valors[i % estil.valors.count]
                let alt = mida.height * (0.18 + v * 0.16)
                let ample = alt * 0.7
                let jitter = CGFloat(estil.valors[(i + 4) % estil.valors.count] - 0.5)
                let x = mida.width * (CGFloat(i) + 0.5) / CGFloat(nArbres) + jitter * (mida.width / CGFloat(nArbres) * 0.5)
                TriangleShape()
                    .fill(estil.colorSilueta.opacity(0.85))
                    .frame(width: ample, height: alt)
                    .position(x: x, y: mida.height - alt / 2)
            }
        }
        .frame(width: mida.width, height: mida.height)
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Escena genèrica (destí encara sense definir): una ruta de vol de puntets
private struct EscenaGenerica: View {
    let estil: EstilViatge
    let mida: CGSize

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: mida.width * 0.12, y: mida.height * 0.82))
                path.addQuadCurve(to: CGPoint(x: mida.width * 0.85, y: mida.height * 0.4),
                                  control: CGPoint(x: mida.width * 0.55, y: mida.height * 0.95))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            .foregroundStyle(.white.opacity(0.5))

            Image(systemName: "airplane")
                .font(.system(size: max(10, mida.height * 0.16)))
                .foregroundStyle(.white.opacity(0.55))
                .rotationEffect(.degrees(40))
                .position(x: mida.width * 0.85, y: mida.height * 0.4)
        }
        .frame(width: mida.width, height: mida.height)
    }
}
