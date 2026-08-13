import UIKit
import UniformTypeIdentifiers
import MapKit
import CoreLocation
import Contacts

// Extensió de compartir: rep un lloc des d'Apple Maps (o qualsevol enllaç)
// i el desa a la bústia de la Bitàcora dins del grup d'apps.
// L'app Viatges, en obrir-se, el recull i el posa al viatge que cobreix aquell dia.
//
// Aquest arxiu és independent a propòsit: no necessita cap altre fitxer de
// l'app, així no cal tocar la pertinença de fitxers a l'Xcode.
//
// Ordre de preferència per llegir el lloc, de més fiable a menys:
//   1. MKMapItem (com.apple.mapkit.map-item) — el que envia Apple Maps
//   2. vCard (public.vcard) — nom, adreça i coordenades
//   3. Enllaç maps.apple.com / google.com/maps
//   4. Text pla

final class ShareViewController: UIViewController {

    /// Ha de coincidir amb el grup d'apps de l'app principal
    private let grup = "group.com.cesc.viatges"
    private let nomArxiu = "bitacora-pendents.json"

    private let targeta = UIView()
    private let etiqueta = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        muntarInterficie()
        processarEntrada()
    }

    // MARK: Interfície (només un avís de confirmació)

    private func muntarInterficie() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.25)

        targeta.backgroundColor = .systemBackground
        targeta.layer.cornerRadius = 18
        targeta.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(targeta)

        etiqueta.text = "Desant a la Bitàcora…"
        etiqueta.font = .systemFont(ofSize: 18, weight: .semibold)
        etiqueta.textAlignment = .center
        etiqueta.numberOfLines = 0
        etiqueta.translatesAutoresizingMaskIntoConstraints = false
        targeta.addSubview(etiqueta)

        NSLayoutConstraint.activate([
            targeta.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            targeta.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            targeta.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            etiqueta.topAnchor.constraint(equalTo: targeta.topAnchor, constant: 24),
            etiqueta.bottomAnchor.constraint(equalTo: targeta.bottomAnchor, constant: -24),
            etiqueta.leadingAnchor.constraint(equalTo: targeta.leadingAnchor, constant: 24),
            etiqueta.trailingAnchor.constraint(equalTo: targeta.trailingAnchor, constant: -24),
        ])
    }

    private func acabar(_ missatge: String, error: Bool = false) {
        DispatchQueue.main.async {
            self.etiqueta.text = missatge
            self.etiqueta.textColor = error ? .systemRed : .label
            DispatchQueue.main.asyncAfter(deadline: .now() + (error ? 2.2 : 0.9)) {
                self.extensionContext?.completeRequest(returningItems: nil)
            }
        }
    }

    // MARK: Recollida dels adjunts
    //
    // Els `loadItem` tornen des de cues qualsevol, així que tota l'escriptura
    // passa per una cua sèrie pròpia. Abans es tocaven les variables des de
    // diversos fils alhora i el resultat era imprevisible.

    private let cuaDades = DispatchQueue(label: "viatges.share.dades")
    private var mapItem: MKMapItem?
    private var vcard: String?
    private var enllac: URL?
    private var textPla = ""

    private static let tipusMapItem = "com.apple.mapkit.map-item"

    private func processarEntrada() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let adjunts = items.flatMap { $0.attachments ?? [] }
        guard !adjunts.isEmpty else { return acabar("No s'ha rebut cap lloc", error: true) }

        // Títol que de vegades acompanya el que es comparteix
        textPla = items
            .compactMap { $0.attributedContentText?.string ?? $0.attributedTitle?.string }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""

        let tasques = DispatchGroup()

        for adjunt in adjunts {
            if adjunt.hasItemConformingToTypeIdentifier(Self.tipusMapItem) {
                tasques.enter()
                adjunt.loadItem(forTypeIdentifier: Self.tipusMapItem, options: nil) { [weak self] item, _ in
                    defer { tasques.leave() }
                    guard let self else { return }
                    var dades: Data?
                    if let d = item as? Data { dades = d }
                    else if let u = item as? URL { dades = try? Data(contentsOf: u) }
                    guard let dades,
                          let mapa = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MKMapItem.self, from: dades)
                    else { return }
                    self.cuaDades.sync { if self.mapItem == nil { self.mapItem = mapa } }
                }
            }

            if adjunt.hasItemConformingToTypeIdentifier(UTType.vCard.identifier) {
                tasques.enter()
                adjunt.loadItem(forTypeIdentifier: UTType.vCard.identifier, options: nil) { [weak self] item, _ in
                    defer { tasques.leave() }
                    guard let self else { return }
                    var text: String?
                    if let dades = item as? Data { text = String(data: dades, encoding: .utf8) }
                    else if let u = item as? URL, let dades = try? Data(contentsOf: u) {
                        text = String(data: dades, encoding: .utf8)
                    } else if let s = item as? String { text = s }
                    guard let text, text.uppercased().contains("BEGIN:VCARD") else { return }
                    self.cuaDades.sync { if self.vcard == nil { self.vcard = text } }
                }
            }

            if adjunt.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                tasques.enter()
                adjunt.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                    defer { tasques.leave() }
                    guard let self else { return }
                    var trobada: URL?
                    if let u = item as? URL { trobada = u }
                    else if let s = item as? String { trobada = URL(string: s) }
                    // Els adjunts de vCard també arriben com a URL de fitxer: no ens serveixen
                    guard let trobada, trobada.scheme?.hasPrefix("http") == true else { return }
                    self.cuaDades.sync { if self.enllac == nil { self.enllac = trobada } }
                }
            }

            if adjunt.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                tasques.enter()
                adjunt.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                    defer { tasques.leave() }
                    guard let self, let s = item as? String, !s.isEmpty else { return }
                    self.cuaDades.sync {
                        self.textPla = self.textPla.isEmpty ? s : self.textPla + "\n" + s
                    }
                }
            }
        }

        tasques.notify(queue: .main) { [weak self] in self?.finalitzar() }

        // Si algun `loadItem` no torna mai, no ens quedem penjats amb la rodeta
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.finalitzar() }
    }

    private var jaFinalitzat = false

    private func finalitzar() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !jaFinalitzat else { return }
        jaFinalitzat = true

        let (mapa, targetaVCard, url, text) = cuaDades.sync { (mapItem, vcard, enllac, textPla) }
        let urlFinal = url ?? Self.primeraURL(dins: text)

        guard let lloc = Self.llegirLloc(text: text, url: urlFinal, vcard: targetaVCard, mapItem: mapa) else {
            return acabar("No s'ha pogut llegir el lloc", error: true)
        }
        guard desar(lloc) else {
            return acabar("No s'ha pogut desar.\nRevisa el grup d'apps a l'Xcode.", error: true)
        }
        let nom = lloc["nom"] as? String ?? "Lloc"
        acabar("✓ \(nom)\nafegit a la Bitàcora")
    }

    // MARK: Desar a la bústia compartida

    /// Torna `false` si el grup d'apps no està disponible (abans fallava en silenci
    /// i l'extensió deia igualment que ho havia desat)
    @discardableResult
    private func desar(_ lloc: [String: Any]) -> Bool {
        guard let carpeta = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grup) else {
            return false
        }
        let arxiu = carpeta.appendingPathComponent(nomArxiu)

        var llista: [[String: Any]] = []
        if let dades = try? Data(contentsOf: arxiu),
           let existents = try? JSONSerialization.jsonObject(with: dades) as? [[String: Any]] {
            llista = existents
        }
        llista.append(lloc)

        guard let dades = try? JSONSerialization.data(withJSONObject: llista) else { return false }
        do {
            try FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
            try dades.write(to: arxiu, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: Lectura del lloc

    /// Diccionari amb les mateixes claus que `LlocCompartit` de l'app
    static func llegirLloc(text: String, url: URL?, vcard: String? = nil, mapItem: MKMapItem? = nil) -> [String: Any]? {
        var nom = ""
        var adreca = ""
        var latitud = 0.0
        var longitud = 0.0

        // 1. La fitxa de mapa d'Apple Maps: la font més completa
        if let mapItem {
            nom = mapItem.name ?? ""
            let coord = mapItem.placemark.coordinate
            if CLLocationCoordinate2DIsValid(coord), coord.latitude != 0 || coord.longitude != 0 {
                latitud = coord.latitude
                longitud = coord.longitude
            }
            if let postal = mapItem.placemark.postalAddress {
                adreca = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress)
                    .replacingOccurrences(of: "\n", with: ", ")
            }
        }

        // 2. La targeta (vCard) que adjunta Apple Maps
        if let vcard, let fitxa = llegirVCard(vcard) {
            if nom.isEmpty { nom = fitxa.nom }
            if adreca.isEmpty { adreca = fitxa.adreca }
            if latitud == 0 && longitud == 0 { latitud = fitxa.latitud; longitud = fitxa.longitud }
        }

        // 3. L'enllaç
        if let url, let comp = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var params: [String: String] = [:]
            for item in comp.queryItems ?? [] where !(item.value ?? "").isEmpty {
                let clau = item.name.lowercased()
                if params[clau] == nil { params[clau] = item.value }
            }
            if nom.isEmpty {
                for clau in ["name", "q", "daddr", "near"] {
                    if let v = params[clau], coordenades(de: v) == nil { nom = v; break }
                }
            }
            if adreca.isEmpty { adreca = params["address"] ?? params["addr"] ?? "" }
            if latitud == 0 && longitud == 0 {
                for clau in ["coordinate", "ll", "sll", "center", "q", "daddr"] {
                    if let v = params[clau], let c = coordenades(de: v) { latitud = c.0; longitud = c.1; break }
                }
            }
            if nom.isEmpty, let fragment = comp.fragment, !fragment.isEmpty { nom = descodificarConsulta(fragment) }
            // Google Maps: /maps/place/Nom+del+lloc/@41.4,2.17,15z
            if nom.isEmpty, let rang = comp.path.range(of: "/place/") {
                let resta = comp.path[rang.upperBound...]
                nom = descodificarConsulta(String(resta.split(separator: "/").first ?? ""))
            }
        }

        // 4. El text compartit
        if nom.isEmpty {
            nom = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty && !$0.lowercased().hasPrefix("http") } ?? ""
        }
        if nom.isEmpty, !adreca.isEmpty { nom = adreca }
        if nom.isEmpty, latitud != 0 || longitud != 0 {
            nom = String(format: "Lloc a %.4f, %.4f", latitud, longitud)
        }

        nom = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        adreca = adreca.trimmingCharacters(in: .whitespacesAndNewlines)

        // Sense res de res no val la pena desar-ho
        if nom.isEmpty && adreca.isEmpty && url == nil && latitud == 0 && longitud == 0 { return nil }

        let format = ISO8601DateFormatter()
        return [
            "id": UUID().uuidString,
            "nom": nom.isEmpty ? "Lloc compartit" : nom,
            "adreca": adreca,
            "url": url?.absoluteString ?? "",
            "latitud": latitud,
            "longitud": longitud,
            "data": format.string(from: Date()),
        ]
    }

    // MARK: Lectura de la targeta (vCard) que adjunta Apple Maps

    struct FitxaLloc {
        var nom = ""
        var adreca = ""
        var latitud = 0.0
        var longitud = 0.0
    }

    /// Treu nom, adreça i coordenades d'una vCard.
    /// Apple Maps hi posa: FN (nom), item1.ADR (adreça) i item1.GEO (coordenades).
    static func llegirVCard(_ text: String) -> FitxaLloc? {
        guard text.uppercased().contains("BEGIN:VCARD") else { return nil }
        var fitxa = FitxaLloc()

        // Les vCards parteixen les línies llargues; les que comencen amb espai continuen l'anterior
        var linies: [String] = []
        for linia in text.components(separatedBy: .newlines) {
            let net = linia.replacingOccurrences(of: "\r", with: "")
            if (net.hasPrefix(" ") || net.hasPrefix("\t")), !linies.isEmpty {
                linies[linies.count - 1] += net.trimmingCharacters(in: .whitespaces)
            } else {
                linies.append(net)
            }
        }

        for linia in linies {
            guard let separador = linia.firstIndex(of: ":") else { continue }
            let capcalera = String(linia[linia.startIndex..<separador])
            let valor = String(linia[linia.index(after: separador)...])
            // Treiem el prefix "item1." i els paràmetres després de ";"
            let clau = capcalera
                .components(separatedBy: ".").last?
                .components(separatedBy: ";").first?
                .uppercased() ?? ""

            switch clau {
            case "FN" where fitxa.nom.isEmpty:
                fitxa.nom = desescapar(valor)
            case "N" where fitxa.nom.isEmpty:
                // Format "cognoms;nom;;;" — agafem la primera part que tingui text
                fitxa.nom = valor.components(separatedBy: ";")
                    .map { desescapar($0) }
                    .first { !$0.isEmpty } ?? ""
            case "ADR" where fitxa.adreca.isEmpty:
                // ";;carrer;ciutat;província;codi postal;país"
                let parts = valor.components(separatedBy: ";")
                    .map { desescapar($0) }
                    .filter { !$0.isEmpty }
                fitxa.adreca = parts.joined(separator: ", ")
            case "GEO" where fitxa.latitud == 0 && fitxa.longitud == 0:
                // "41.4036;2.1744" (vCard 3) o "geo:41.4036,2.1744" (vCard 4)
                let net = valor.replacingOccurrences(of: "geo:", with: "")
                    .replacingOccurrences(of: ";", with: ",")
                if let c = coordenades(de: net) { fitxa.latitud = c.0; fitxa.longitud = c.1 }
            case "URL" where fitxa.adreca.isEmpty:
                break
            default:
                break
            }
        }

        if fitxa.nom.isEmpty && fitxa.adreca.isEmpty && fitxa.latitud == 0 { return nil }
        return fitxa
    }

    /// Les vCards escapen comes, punts i comes i salts de línia
    private static func desescapar(_ text: String) -> String {
        text.replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func primeraURL(dins text: String) -> URL? {
        guard !text.isEmpty,
              let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        else { return nil }
        let rang = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.firstMatch(in: text, options: [], range: rang)?.url
    }

    static func coordenades(de text: String) -> (Double, Double)? {
        let parts = text.split(separator: ",")
        guard parts.count == 2,
              let lat = Double(parts[0].trimmingCharacters(in: .whitespaces)),
              let lon = Double(parts[1].trimmingCharacters(in: .whitespaces)),
              lat >= -90, lat <= 90, lon >= -180, lon <= 180 else { return nil }
        return (lat, lon)
    }

    /// Els valors que venen de `queryItems` ja arriben descodificats: només cal
    /// desfer els "+" i, si de cas, un percent-encoding que hi quedi.
    /// (Abans es tornava a descodificar sempre i els noms amb "%" o "+" es feien malbé.)
    static func descodificarConsulta(_ text: String) -> String {
        let ambEspais = text.replacingOccurrences(of: "+", with: " ")
        if ambEspais.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) != nil {
            return (ambEspais.removingPercentEncoding ?? ambEspais)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ambEspais.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
