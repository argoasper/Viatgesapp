import Foundation
import SwiftData

// MARK: - Bústia de llocs compartits des d'Apple Maps
//
// Com funciona:
//  1. A Apple Maps: lloc → Compartir → Bitàcora (Viatges).
//  2. L'extensió "ViatgesShare" desa el lloc en un arxiu JSON dins del grup d'apps.
//  3. Quan obres l'app, aquesta buida la bústia i crea les visites a la Bitàcora
//     del viatge que cobreix aquell dia.
//  4. Si cap viatge cobreix el dia, el lloc es queda a la bústia i l'app
//     l'ensenya a la Bitàcora perquè l'hi posis tu.

/// Un lloc compartit encara no processat per l'app
struct LlocCompartit: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var nom: String = ""
    var adreca: String = ""
    var url: String = ""
    var latitud: Double = 0
    var longitud: Double = 0
    var data: Date = Date()
}

/// Arxiu compartit entre l'app i l'extensió de compartir
enum BustiaBitacora {
    /// Identificador del grup d'apps (ha de coincidir amb el dels entitlements)
    static let grup = "group.com.cesc.viatges"
    private static let nomArxiu = "bitacora-pendents.json"

    /// Carpeta compartida amb l'extensió. Si és `nil`, el grup d'apps no està
    /// ben configurat i l'extensió no podrà fer arribar res a l'app.
    static var carpetaGrup: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grup)
    }

    /// Carpeta de reserva dins de l'app (només per a llocs enganxats a mà)
    static var carpetaLocal: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    /// Fals quan el grup d'apps no està disponible: llavors res del que
    /// comparteixis des d'Apple Maps no arribarà mai a l'app.
    static var grupDisponible: Bool { carpetaGrup != nil }

    static var carpeta: URL { carpetaGrup ?? carpetaLocal }

    /// Mirem els dos llocs: si el grup s'ha configurat més tard, no perdem el
    /// que hagués quedat desat a la carpeta de l'app.
    private static var arxius: [URL] {
        var llista: [URL] = []
        if let grup = carpetaGrup { llista.append(grup.appendingPathComponent(nomArxiu)) }
        llista.append(carpetaLocal.appendingPathComponent(nomArxiu))
        return llista
    }

    private static var descodificador: JSONDecoder {
        let d = JSONDecoder()
        // L'extensió escriu les dates amb ISO8601; tolerem també altres formats
        d.dateDecodingStrategy = .custom { decoder in
            let valor = try decoder.singleValueContainer()
            if let text = try? valor.decode(String.self) {
                let ambFraccions = ISO8601DateFormatter()
                ambFraccions.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let data = ambFraccions.date(from: text) { return data }
                if let data = ISO8601DateFormatter().date(from: text) { return data }
            }
            if let segons = try? valor.decode(Double.self) {
                return Date(timeIntervalSinceReferenceDate: segons)
            }
            return Date()
        }
        return d
    }

    /// Llegeix la llista pendent dels dos arxius (sense esborrar-la)
    static func llegir() -> [LlocCompartit] {
        var resultat: [LlocCompartit] = []
        var vistos = Set<String>()
        for arxiu in arxius {
            guard let dades = try? Data(contentsOf: arxiu),
                  let llista = try? descodificador.decode([LlocCompartit].self, from: dades)
            else { continue }
            for lloc in llista where !vistos.contains(lloc.id) {
                vistos.insert(lloc.id)
                resultat.append(lloc)
            }
        }
        return resultat.sorted { $0.data < $1.data }
    }

    /// Escriu la llista pendent (a la carpeta del grup si hi és) i deixa buida l'altra
    static func escriure(_ llista: [LlocCompartit]) {
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        guard let dades = try? codificador.encode(llista),
              let buit = try? codificador.encode([LlocCompartit]())
        else { return }

        let desti = carpeta.appendingPathComponent(nomArxiu)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        try? dades.write(to: desti, options: .atomic)

        for arxiu in arxius where arxiu != desti {
            if FileManager.default.fileExists(atPath: arxiu.path) {
                try? buit.write(to: arxiu, options: .atomic)
            }
        }
    }

    /// Afegeix un lloc a la bústia (ho fa l'extensió de compartir o el botó d'enganxar)
    static func afegir(_ lloc: LlocCompartit) {
        var llista = llegir()
        llista.append(lloc)
        escriure(llista)
    }

    /// Treu un lloc concret de la bústia
    static func treure(_ id: String) {
        escriure(llegir().filter { $0.id != id })
    }

    /// Torna els pendents i buida la bústia
    static func buidar() -> [LlocCompartit] {
        let llista = llegir()
        if !llista.isEmpty { escriure([]) }
        return llista
    }
}

// MARK: - Lectura d'enllaços d'Apple Maps

/// Treu el nom, l'adreça i les coordenades d'un enllaç compartit d'Apple Maps
enum LectorAppleMaps {

    /// Analitza un text compartit (pot portar títol i enllaç barrejats) i en fa un lloc
    static func llegir(text: String, urlDonada: URL? = nil, data: Date = Date()) -> LlocCompartit? {
        let net = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlDonada ?? primeraURL(dins: net)

        var lloc = LlocCompartit()
        lloc.data = data
        lloc.url = url?.absoluteString ?? ""

        if let url, let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var params: [String: String] = [:]
            for item in components.queryItems ?? [] {
                let valor = item.value ?? ""
                if !valor.isEmpty, params[item.name.lowercased()] == nil {
                    params[item.name.lowercased()] = valor
                }
            }

            lloc.nom = primerValor(params, ["name", "q", "daddr", "near"]) ?? ""
            lloc.adreca = primerValor(params, ["address", "addr"]) ?? ""

            if let coords = primerValor(params, ["coordinate", "ll", "sll", "center", "q", "daddr"], acceptantCoordenades: true),
               let (lat, lon) = coordenades(de: coords) {
                lloc.latitud = lat
                lloc.longitud = lon
            }
            // A vegades el nom arriba dins del fragment: .../place?...#name
            if lloc.nom.isEmpty, let fragment = components.fragment, !fragment.isEmpty {
                lloc.nom = fragment
            }
            // Google Maps: /maps/place/Nom+del+lloc/@41.4,2.17,15z
            if lloc.nom.isEmpty, let rang = components.path.range(of: "/place/") {
                let resta = components.path[rang.upperBound...]
                lloc.nom = String(resta.split(separator: "/").first ?? "")
            }
        }

        // Si l'enllaç no porta nom, agafem la primera línia del text compartit
        if lloc.nom.isEmpty {
            let liniaTitol = net
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty && !$0.lowercased().hasPrefix("http") }
            lloc.nom = liniaTitol ?? ""
        }
        if lloc.nom.isEmpty, !lloc.adreca.isEmpty { lloc.nom = lloc.adreca }
        if lloc.nom.isEmpty, lloc.latitud != 0 || lloc.longitud != 0 {
            lloc.nom = String(format: "Lloc a %.4f, %.4f", lloc.latitud, lloc.longitud)
        }

        lloc.nom = netejar(lloc.nom)
        lloc.adreca = netejar(lloc.adreca)

        guard !lloc.nom.isEmpty || !lloc.url.isEmpty else { return nil }
        if lloc.nom.isEmpty { lloc.nom = "Lloc compartit" }
        return lloc
    }

    /// Primera URL que apareix dins d'un text
    static func primeraURL(dins text: String) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let rang = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: rang)?.url
    }

    private static func primerValor(_ params: [String: String], _ claus: [String],
                                    acceptantCoordenades: Bool = false) -> String? {
        for clau in claus {
            if let valor = params[clau], !valor.trimmingCharacters(in: .whitespaces).isEmpty {
                // "q" pot portar coordenades en comptes de nom: llavors no serveix com a nom
                if !acceptantCoordenades, coordenades(de: valor) != nil { continue }
                return valor
            }
        }
        return nil
    }

    /// Converteix "41.4036,2.1744" en coordenades
    static func coordenades(de text: String) -> (Double, Double)? {
        let parts = text.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return (lat, lon)
    }

    /// Els valors de `queryItems` ja arriben descodificats: només desfem els "+"
    /// i, si encara hi queda percent-encoding, el desfem un cop.
    private static func netejar(_ text: String) -> String {
        let ambEspais = text.replacingOccurrences(of: "+", with: " ")
        if ambEspais.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) != nil {
            return (ambEspais.removingPercentEncoding ?? ambEspais)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ambEspais.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Traspàs dels llocs compartits a la Bitàcora

enum ImportadorBitacora {

    /// Buida la bústia i crea les visites al viatge que cobreix el dia de cada lloc.
    /// Els que no cauen dins de cap viatge es queden a la bústia (no es perden ni
    /// van a parar a un viatge que no toca).
    /// Retorna quantes visites ha afegit.
    @discardableResult
    static func importarPendents(a context: ModelContext) -> Int {
        let pendents = BustiaBitacora.llegir()
        guard !pendents.isEmpty else { return 0 }

        let viatges = (try? context.fetch(FetchDescriptor<Viatge>())) ?? []
        guard !viatges.isEmpty else { return 0 }   // els deixem a la bústia

        var restants: [LlocCompartit] = []
        var afegides = 0

        for pendent in pendents {
            guard let viatge = viatgeQueCobreix(pendent.data, entre: viatges) else {
                restants.append(pendent)
                continue
            }
            if !jaHiEs(pendent, a: viatge) {
                context.insert(visita(de: pendent, a: viatge))
                afegides += 1
            }
        }

        BustiaBitacora.escriure(restants)
        if afegides > 0 { try? context.save() }
        return afegides
    }

    /// Llocs compartits que encara no s'han pogut col·locar en cap viatge
    static func pendentsSenseViatge(_ viatges: [Viatge]) -> [LlocCompartit] {
        BustiaBitacora.llegir().filter { viatgeQueCobreix($0.data, entre: viatges) == nil }
    }

    /// Posa un lloc pendent al viatge que diguis i el treu de la bústia
    @discardableResult
    static func assignar(_ lloc: LlocCompartit, a viatge: Viatge, context: ModelContext) -> Bool {
        guard !jaHiEs(lloc, a: viatge) else {
            BustiaBitacora.treure(lloc.id)
            return false
        }
        context.insert(visita(de: lloc, a: viatge))
        try? context.save()
        BustiaBitacora.treure(lloc.id)
        return true
    }

    static func descartar(_ lloc: LlocCompartit) {
        BustiaBitacora.treure(lloc.id)
    }

    /// Viatge que té el dia dins del seu període (inici i fi inclosos)
    static func viatgeQueCobreix(_ data: Date, entre viatges: [Viatge]) -> Viatge? {
        let calendari = Calendar.current
        let dia = calendari.startOfDay(for: data)
        return viatges.first {
            calendari.startOfDay(for: $0.dataInici) <= dia && dia <= calendari.startOfDay(for: $0.dataFi)
        }
    }

    // MARK: Ajudes

    private static func visita(de lloc: LlocCompartit, a viatge: Viatge) -> VisitaBitacora {
        VisitaBitacora(
            nom: lloc.nom,
            adreca: lloc.adreca,
            urlMaps: lloc.url,
            latitud: lloc.latitud,
            longitud: lloc.longitud,
            dataVisita: lloc.data,
            origen: VisitaBitacora.origenCompartit,
            viatge: viatge
        )
    }

    /// Evita duplicats si el mateix lloc s'importa dues vegades
    private static func jaHiEs(_ lloc: LlocCompartit, a viatge: Viatge) -> Bool {
        let calendari = Calendar.current
        return viatge.bitacoraLlista.contains { visita in
            visita.nom == lloc.nom
                && calendari.isDate(visita.dataVisita, equalTo: lloc.data, toGranularity: .minute)
        }
    }
}
