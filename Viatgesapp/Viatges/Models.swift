import Foundation
import SwiftData

// MARK: - Viatge (node principal de l'esquema)

@Model
final class Viatge {
    var nom: String = ""
    var destinacio: String = ""
    var emoji: String = "✈️"
    var dataInici: Date = Date()
    var dataFi: Date = Date()
    var notes: String = ""
    var nomApartatAltres: String = "Altres"
    var completat: Bool = false
    var categoriesInicialitzades: Bool = false
    var creatEl: Date = Date()
    /// Icona de l'apartat Bitàcora (la pots canviar des de l'Itinerari)
    var emojiBitacora: String = "📖"
    /// Coordenades del destí, calculades la primera vegada que s'obre el viatge
    var latitud: Double = 0
    var longitud: Double = 0
    /// Perquè no torni a cercar-les si ja ho hem provat i no s'han trobat
    var geocodificacioIntentada: Bool = false
    /// Text exacte que es va fer servir per trobar les coordenades actuals;
    /// si el destí canvia, ho notem comparant amb aquest camp i les tornem a cercar
    var textGeocodificat: String = ""
    /// Tipus d'escena del dibuix de la targeta (platja, muntanya, ciutat...),
    /// resolt a partir del que hi ha realment al destí (mar, llac...) quan es
    /// geocodifica. Es fa servir només si no hi ha foto real (vegeu més avall).
    var tipusEscenaPortada: String = ""
    /// Foto real del destí, baixada de la Viquipèdia la primera vegada que
    /// s'obre el viatge. Si no en troba cap, es queda buida i la targeta
    /// mostra el dibuix il·lustrat com a reserva.
    @Attribute(.externalStorage) var fotoPortada: Data?
    /// Perquè no torni a intentar baixar la foto si ja ho hem provat i no n'hi havia
    var fotoPortadaIntentada: Bool = false

    // MARK: Apartats visibles
    //
    // Els 5 apartats (Equipatge, Documentació, Horaris, Itinerari, Altres)
    // hi són tots per defecte; es poden amagar en un viatge concret si no
    // et fan falta (p. ex. treure "Itinerari" en una escapada curta).
    var apartatEquipatgeVisible: Bool = true
    var apartatDocumentacioVisible: Bool = true
    var apartatHorarisVisible: Bool = true
    var apartatItinerariVisible: Bool = true
    var apartatAltresVisible: Bool = true

    @Relationship(deleteRule: .cascade, inverse: \ItemEquipatge.viatge)
    var equipatge: [ItemEquipatge]? = []

    @Relationship(deleteRule: .cascade, inverse: \DocumentViatge.viatge)
    var documents: [DocumentViatge]? = []

    @Relationship(deleteRule: .cascade, inverse: \Zona.viatge)
    var zones: [Zona]? = []

    @Relationship(deleteRule: .cascade, inverse: \Horari.viatge)
    var horaris: [Horari]? = []

    @Relationship(deleteRule: .cascade, inverse: \ItemAltres.viatge)
    var altres: [ItemAltres]? = []

    @Relationship(deleteRule: .cascade, inverse: \CategoriaEquip.viatge)
    var categoriesEquip: [CategoriaEquip]? = []

    @Relationship(deleteRule: .cascade, inverse: \SeccioAltres.viatge)
    var seccionsAltres: [SeccioAltres]? = []

    @Relationship(deleteRule: .cascade, inverse: \VisitaBitacora.viatge)
    var bitacora: [VisitaBitacora]? = []

    init(nom: String = "", destinacio: String = "", emoji: String = "✈️", dataInici: Date = Date(), dataFi: Date = Date(), notes: String = "") {
        self.nom = nom
        self.destinacio = destinacio
        self.emoji = emoji
        self.dataInici = dataInici
        self.dataFi = dataFi
        self.notes = notes
        self.creatEl = Date()
    }

    var equipatgeLlista: [ItemEquipatge] { equipatge ?? [] }
    var documentsLlista: [DocumentViatge] { documents ?? [] }
    var zonesLlista: [Zona] { zones ?? [] }
    var zonesOrdenades: [Zona] { zonesLlista.sorted { $0.ordre < $1.ordre } }
    var horarisLlista: [Horari] { (horaris ?? []).sorted { ($0.ordre, $0.dataHora) < ($1.ordre, $1.dataHora) } }
    var altresLlista: [ItemAltres] { altres ?? [] }
    var categoriesLlista: [CategoriaEquip] { (categoriesEquip ?? []).sorted { $0.ordre < $1.ordre } }
    var seccionsAltresLlista: [SeccioAltres] { (seccionsAltres ?? []).sorted { $0.ordre < $1.ordre } }

    // MARK: Bitàcora

    /// Totes les visites registrades, de la més recent a la més antiga
    var bitacoraLlista: [VisitaBitacora] {
        (bitacora ?? []).sorted { $0.dataVisita > $1.dataVisita }
    }

    /// Visites agrupades pel dia de la visita (dia més recent primer).
    /// Dins de cada dia, les visites van en ordre cronològic.
    var bitacoraPerDia: [DiaBitacora] {
        let calendari = Calendar.current
        let grups = Dictionary(grouping: bitacoraLlista) { calendari.startOfDay(for: $0.dataVisita) }
        return grups
            .map { DiaBitacora(dia: $0.key, visites: $0.value.sorted { $0.dataVisita < $1.dataVisita }) }
            .sorted { $0.dia > $1.dia }
    }

    /// Número de dia dins del viatge (1, 2, 3...) o nil si la visita cau fora de les dates
    func numeroDiaViatge(_ dia: Date) -> Int? {
        let calendari = Calendar.current
        let inici = calendari.startOfDay(for: dataInici)
        let fi = calendari.startOfDay(for: dataFi)
        let d = calendari.startOfDay(for: dia)
        guard d >= inici, d <= fi,
              let diferencia = calendari.dateComponents([.day], from: inici, to: d).day else { return nil }
        return diferencia + 1
    }

    /// Elements de l'apartat Altres d'una secció concreta, ordenats
    func itemsAltres(de seccio: String) -> [ItemAltres] {
        altresLlista
            .filter { $0.seccio == seccio }
            .sorted { $0.ordre < $1.ordre }
    }

    /// Documents d'un tipus concret, ordenats (primer per l'ordre manual, després per data)
    func documents(de tipus: String) -> [DocumentViatge] {
        documentsLlista
            .filter { $0.tipus == tipus }
            .sorted { ($0.ordre, $0.data) < ($1.ordre, $1.data) }
    }

    /// Elements d'una categoria concreta, ordenats
    func itemsEquipatge(de nomCategoria: String) -> [ItemEquipatge] {
        equipatgeLlista
            .filter { $0.categoria == nomCategoria }
            .sorted { $0.ordre < $1.ordre }
    }

    // MARK: Mapa del destí

    var teCoordenades: Bool { latitud != 0 || longitud != 0 }

    private var destiPerCercar: String {
        destinacio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nom.trimmingCharacters(in: .whitespacesAndNewlines)
            : destinacio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Enllaç per obrir el destí a Apple Maps
    var urlAppleMaps: URL? {
        let consulta = destiPerCercar.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? destiPerCercar
        if teCoordenades {
            return URL(string: "https://maps.apple.com/?ll=\(latitud),\(longitud)&q=\(consulta)")
        }
        guard !consulta.isEmpty else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(consulta)")
    }
}

/// Categoria d'equipatge pròpia de cada viatge (només surten les que afegeixes)
@Model
final class CategoriaEquip {
    var nom: String = ""
    var emoji: String = "📦"
    var ordre: Int = 0
    var viatge: Viatge?

    init(nom: String = "", emoji: String = "📦", ordre: Int = 0, viatge: Viatge? = nil) {
        self.nom = nom
        self.emoji = emoji
        self.ordre = ordre
        self.viatge = viatge
    }
}

// MARK: - Equipatge

/// Categories que l'app proposa quan crees un viatge
enum CategoriaEquipatge: String, CaseIterable {
    case roba = "Roba"
    case tecnologia = "Tecnologia"
    case medicaments = "Medicaments"
    case documents = "Documents"
    case menjar = "Menjar"
    case higiene = "Higiene"
    case esports = "Esports"
    case feina = "Feina"

    var emoji: String {
        switch self {
        case .roba: "👕"
        case .tecnologia: "💻"
        case .medicaments: "💊"
        case .documents: "📄"
        case .menjar: "🍫"
        case .higiene: "🧴"
        case .esports: "⚽️"
        case .feina: "💼"
        }
    }
}

@Model
final class ItemEquipatge {
    var nom: String = ""
    var categoria: String = CategoriaEquipatge.roba.rawValue
    var empaquetat: Bool = false
    var ordre: Int = 0
    var viatge: Viatge?

    init(nom: String = "", categoria: String = CategoriaEquipatge.roba.rawValue, ordre: Int = 0, viatge: Viatge? = nil) {
        self.nom = nom
        self.categoria = categoria
        self.ordre = ordre
        self.viatge = viatge
    }
}

// MARK: - Documentació (Bitllets / Allotjament / Entrades)

enum TipusDocument: String, CaseIterable {
    case transport = "Bitllets de transport"
    case allotjament = "Allotjament"
    case entrades = "Entrades"
    case altres = "Altres"

    var emoji: String {
        switch self {
        case .transport: "✈️"
        case .allotjament: "🛏️"
        case .entrades: "🎟️"
        case .altres: "📄"
        }
    }
}

@Model
final class DocumentViatge {
    var titol: String = ""
    var tipus: String = TipusDocument.transport.rawValue
    var notes: String = ""
    var data: Date = Date()
    var ordre: Int = 0
    var nomFitxer: String = ""
    @Attribute(.externalStorage) var dades: Data?
    var viatge: Viatge?

    @Relationship(deleteRule: .cascade, inverse: \FitxerDocument.document)
    var fitxers: [FitxerDocument]? = []

    init(titol: String = "", tipus: String = TipusDocument.transport.rawValue, notes: String = "", data: Date = Date(), nomFitxer: String = "", dades: Data? = nil, viatge: Viatge? = nil) {
        self.titol = titol
        self.tipus = tipus
        self.notes = notes
        self.data = data
        self.nomFitxer = nomFitxer
        self.dades = dades
        self.viatge = viatge
    }

    var fitxersLlista: [FitxerDocument] { (fitxers ?? []).sorted { $0.ordre < $1.ordre } }

    /// Dades per a la miniatura de la llista (primer fitxer, o el camp antic)
    var miniaturaDades: Data? { fitxersLlista.first?.dades ?? dades }

    /// Nombre total de fitxers adjunts
    var nombreFitxers: Int { fitxersLlista.count + (dades != nil ? 1 : 0) }
}

/// Fitxer adjunt d'un document (PDF o imatge); un document en pot tenir diversos
@Model
final class FitxerDocument {
    var nomFitxer: String = ""
    @Attribute(.externalStorage) var dades: Data?
    var ordre: Int = 0
    var creatEl: Date = Date()
    var document: DocumentViatge?

    init(nomFitxer: String = "", dades: Data? = nil, ordre: Int = 0, document: DocumentViatge? = nil) {
        self.nomFitxer = nomFitxer
        self.dades = dades
        self.ordre = ordre
        self.creatEl = Date()
        self.document = document
    }
}

// MARK: - Horaris (avió / tren / vaixell)

enum TipusTransport: String, CaseIterable {
    case avio = "Avió"
    case tren = "Tren"
    case vaixell = "Vaixell"
    case cotxe = "Cotxe"
    case autobus = "Autobús"

    var emoji: String {
        switch self {
        case .avio: "✈️"
        case .tren: "🚆"
        case .vaixell: "🚢"
        case .cotxe: "🚗"
        case .autobus: "🚌"
        }
    }
}

@Model
final class Horari {
    var tipus: String = TipusTransport.avio.rawValue
    var origen: String = ""
    var desti: String = ""
    var dataHora: Date = Date()
    var duracio: String = ""
    var notes: String = ""
    var completat: Bool = false
    var ordre: Int = 0
    var viatge: Viatge?

    init(tipus: String = TipusTransport.avio.rawValue, origen: String = "", desti: String = "", dataHora: Date = Date(), duracio: String = "", notes: String = "", viatge: Viatge? = nil) {
        self.tipus = tipus
        self.origen = origen
        self.desti = desti
        self.dataHora = dataHora
        self.duracio = duracio
        self.notes = notes
        self.viatge = viatge
    }

    var emojiTransport: String {
        TipusTransport(rawValue: tipus)?.emoji ?? "🎫"
    }
}

// MARK: - Apartat "Altres" (personalitzable)

@Model
final class ItemAltres {
    var nom: String = ""
    var fet: Bool = false
    var seccio: String = ""
    var ordre: Int = 0
    var viatge: Viatge?

    init(nom: String = "", seccio: String = "", ordre: Int = 0, viatge: Viatge? = nil) {
        self.nom = nom
        self.seccio = seccio
        self.ordre = ordre
        self.viatge = viatge
    }
}

/// Subllista de l'apartat Altres (Coses Casa, Varis... o les que creïs)
@Model
final class SeccioAltres {
    var nom: String = ""
    var emoji: String = "📝"
    var ordre: Int = 0
    var viatge: Viatge?

    init(nom: String = "", emoji: String = "📝", ordre: Int = 0, viatge: Viatge? = nil) {
        self.nom = nom
        self.emoji = emoji
        self.ordre = ordre
        self.viatge = viatge
    }
}

/// Llistes que l'app proposa dins de l'apartat Altres
enum SeccioSuggerida: String, CaseIterable {
    case cosesCasa = "Coses Casa"
    case varis = "Varis"
    case compres = "Compres"
    case notes = "Notes"

    var emoji: String {
        switch self {
        case .cosesCasa: "🏠"
        case .varis: "📦"
        case .compres: "🛍️"
        case .notes: "📝"
        }
    }
}

// MARK: - Itinerari: Localitzacions Principals (1 a N) → Llocs d'interès

@Model
final class Zona {
    var nom: String = ""
    var ordre: Int = 0
    var viatge: Viatge?

    @Relationship(deleteRule: .cascade, inverse: \LlocInteres.zona)
    var llocs: [LlocInteres]? = []

    @Relationship(deleteRule: .cascade, inverse: \EnllacZona.zona)
    var enllacos: [EnllacZona]? = []

    init(nom: String = "", ordre: Int = 0, viatge: Viatge? = nil) {
        self.nom = nom
        self.ordre = ordre
        self.viatge = viatge
    }

    var llocsLlista: [LlocInteres] { llocs ?? [] }
    var llocsOrdenats: [LlocInteres] { llocsLlista.sorted { $0.ordre < $1.ordre } }
    var enllacosLlista: [EnllacZona] { (enllacos ?? []).sorted { $0.ordre < $1.ordre } }
}

/// Enllaços de rutes d'una localització (Wikiloc, AllTrails, altres apps...)
@Model
final class EnllacZona {
    var titol: String = ""
    var url: String = ""
    var ordre: Int = 0
    var zona: Zona?

    init(titol: String = "", url: String = "", ordre: Int = 0, zona: Zona? = nil) {
        self.titol = titol
        self.url = url
        self.ordre = ordre
        self.zona = zona
    }

    var esWikiloc: Bool { url.lowercased().contains("wikiloc") }
}

@Model
final class LlocInteres {
    var nom: String = ""
    var descripcio: String = ""
    var fontDescripcio: String = ""
    var urlMaps: String = ""
    var urlMapsGoogle: String = ""
    var cercaPersonalitzada: String = ""
    var ordre: Int = 0
    var visitat: Bool = false
    var zona: Zona?

    @Relationship(deleteRule: .cascade, inverse: \Foto.lloc)
    var fotos: [Foto]? = []

    @Relationship(deleteRule: .cascade, inverse: \EnllacLloc.lloc)
    var enllacos: [EnllacLloc]? = []

    init(nom: String = "", descripcio: String = "", urlMaps: String = "", ordre: Int = 0, zona: Zona? = nil) {
        self.nom = nom
        self.descripcio = descripcio
        self.urlMaps = urlMaps
        self.ordre = ordre
        self.zona = zona
    }

    var fotosLlista: [Foto] { (fotos ?? []).sorted { $0.creadaEl < $1.creadaEl } }
    var enllacosLlista: [EnllacLloc] { (enllacos ?? []).sorted { $0.ordre < $1.ordre } }
    /// Enllaços generals (YouTube, webs...) — exclou els de Wikiloc
    var enllacosGenerals: [EnllacLloc] { enllacosLlista.filter { $0.tipus != EnllacLloc.tipusWikiloc } }
    /// Rutes de Wikiloc
    var enllacosWikiloc: [EnllacLloc] { enllacosLlista.filter { $0.tipus == EnllacLloc.tipusWikiloc } }

    /// Text de cerca per als mapes: el personalitzat si n'hi ha, si no el nom + localització
    var textCerca: String {
        if !cercaPersonalitzada.isEmpty { return cercaPersonalitzada }
        if let zona, !zona.nom.isEmpty { return "\(nom), \(zona.nom)" }
        return nom
    }

    private var consultaCodificada: String {
        textCerca.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? nom
    }

    /// Enllaç a Apple Maps (personalitzat si l'usuari n'ha enganxat un; si no, generat)
    var urlAppleMaps: URL? {
        if !urlMaps.isEmpty { return URL(string: urlMaps) }
        return URL(string: "https://maps.apple.com/?q=\(consultaCodificada)")
    }

    /// Enllaç a Google Maps (personalitzat si l'usuari n'ha enganxat un; si no, generat)
    var urlGoogleMaps: URL? {
        if !urlMapsGoogle.isEmpty { return URL(string: urlMapsGoogle) }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(consultaCodificada)")
    }
}

/// Enllaços addicionals d'un lloc d'interès (web oficial, YouTube, Wikiloc...)
@Model
final class EnllacLloc {
    static let tipusGeneral = "general"
    static let tipusWikiloc = "wikiloc"

    var titol: String = ""
    var url: String = ""
    var tipus: String = "general"
    var ordre: Int = 0
    var lloc: LlocInteres?

    init(titol: String = "", url: String = "", tipus: String = EnllacLloc.tipusGeneral, ordre: Int = 0, lloc: LlocInteres? = nil) {
        self.titol = titol
        self.url = url
        self.tipus = tipus
        self.ordre = ordre
        self.lloc = lloc
    }
}

// MARK: - Bitàcora: registre de llocs visitats, agrupats per dia

/// Un dia de la bitàcora amb les visites que s'hi han fet
struct DiaBitacora: Identifiable {
    var dia: Date
    var visites: [VisitaBitacora]
    var id: Date { dia }
}

/// Un lloc visitat: es registra manualment o arriba compartit des d'Apple Maps
@Model
final class VisitaBitacora {
    static let origenManual = "manual"
    static let origenCompartit = "compartit"
    static let origenItinerari = "itinerari"

    var nom: String = ""
    var notes: String = ""
    var adreca: String = ""
    /// Enllaç original (normalment d'Apple Maps)
    var urlMaps: String = ""
    var latitud: Double = 0
    var longitud: Double = 0
    /// Data i hora de la visita: determina a quin dia es classifica
    var dataVisita: Date = Date()
    var emoji: String = "📍"
    var origen: String = VisitaBitacora.origenManual
    var creadaEl: Date = Date()
    /// Foto personal de la visita, pujada des del carret
    @Attribute(.externalStorage) var foto: Data?
    var viatge: Viatge?

    init(nom: String = "", notes: String = "", adreca: String = "", urlMaps: String = "",
         latitud: Double = 0, longitud: Double = 0, dataVisita: Date = Date(),
         emoji: String = "📍", origen: String = VisitaBitacora.origenManual, viatge: Viatge? = nil) {
        self.nom = nom
        self.notes = notes
        self.adreca = adreca
        self.urlMaps = urlMaps
        self.latitud = latitud
        self.longitud = longitud
        self.dataVisita = dataVisita
        self.emoji = emoji
        self.origen = origen
        self.creadaEl = Date()
        self.viatge = viatge
    }

    var teCoordenades: Bool { latitud != 0 || longitud != 0 }

    private var consultaCodificada: String {
        nom.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? nom
    }

    /// Enllaç per tornar a obrir el lloc a Apple Maps
    var urlAppleMaps: URL? {
        if !urlMaps.isEmpty { return URL(string: urlMaps) }
        if teCoordenades { return URL(string: "https://maps.apple.com/?ll=\(latitud),\(longitud)&q=\(consultaCodificada)") }
        return URL(string: "https://maps.apple.com/?q=\(consultaCodificada)")
    }

    /// Enllaç equivalent a Google Maps
    var urlGoogleMaps: URL? {
        if teCoordenades { return URL(string: "https://www.google.com/maps/search/?api=1&query=\(latitud),\(longitud)") }
        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(consultaCodificada)")
    }

    /// Text per compartir la visita amb algú altre
    var textPerCompartir: String {
        var parts = ["\(emoji) \(nom)"]
        if !adreca.isEmpty { parts.append(adreca) }
        parts.append(dataVisita.formatCatala(date: .long, time: .shortened))
        if !notes.isEmpty { parts.append(notes) }
        if let url = urlAppleMaps { parts.append(url.absoluteString) }
        return parts.joined(separator: "\n")
    }
}

@Model
final class Foto {
    @Attribute(.externalStorage) var dades: Data?
    var creadaEl: Date = Date()
    var lloc: LlocInteres?

    init(dades: Data? = nil, lloc: LlocInteres? = nil) {
        self.dades = dades
        self.creadaEl = Date()
        self.lloc = lloc
    }
}
