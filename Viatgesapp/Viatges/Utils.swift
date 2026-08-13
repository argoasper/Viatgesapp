import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Dates sempre en català
//
// `.formatted(date:time:)` fa servir l'idioma del dispositiu per defecte; si
// el mòbil està en anglès, les dates sortien en anglès. Amb aquest ajudant
// sempre surten en català, independentment de l'idioma del dispositiu.

let localeCatala = Locale(identifier: "ca_ES")

extension Date {
    /// Com `.formatted(date:time:)` però sempre en català
    func formatCatala(date estilData: Date.FormatStyle.DateStyle = .omitted,
                       time estilHora: Date.FormatStyle.TimeStyle = .omitted) -> String {
        formatted(Date.FormatStyle(date: estilData, time: estilHora, locale: localeCatala))
    }
}

// MARK: - Imatges

/// Decodifica les dades d'una foto (JPEG/PNG) a una `Image` de SwiftUI, tant a iOS com al Mac
func imatgeDesDades(_ dades: Data) -> Image? {
    #if os(iOS)
    guard let imatge = UIImage(data: dades) else { return nil }
    return Image(uiImage: imatge)
    #else
    guard let imatge = NSImage(data: dades) else { return nil }
    return Image(nsImage: imatge)
    #endif
}

// MARK: - Viquipèdia: descripció automàtica d'un lloc d'interès
//
// Prova, per aquest ordre: article en català amb el nom exacte, cerca en català,
// cerca en anglès i el seu equivalent en català, i finalment castellà.

struct ResumViqui {
    var text: String
    var font: String
}

enum Viquipedia {

    /// Busca un resum del lloc. Torna nil si no troba cap article.
    static func resum(de nom: String) async -> ResumViqui? {
        let net = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !net.isEmpty else { return nil }

        if let r = await resumDirecte(idioma: "ca", titol: net) { return r }

        if let titolCa = await cercarTitol(idioma: "ca", consulta: net),
           let r = await resumDirecte(idioma: "ca", titol: titolCa) { return r }

        if let titolEn = await cercarTitol(idioma: "en", consulta: net) {
            if let equivalent = await titolEnCatala(titolAngles: titolEn),
               let r = await resumDirecte(idioma: "ca", titol: equivalent) { return r }
            if let r = await resumDirecte(idioma: "en", titol: titolEn) { return r }
        }

        return await resumDirecte(idioma: "es", titol: net)
    }

    /// Baixa una foto representativa del lloc (la imatge de capçalera del seu
    /// article a la Viquipèdia), a mida reduïda. Torna nil si no en té.
    static func fotoPortada(de nom: String) async -> Data? {
        guard let url = await fotoURL(de: nom) else { return nil }
        return await descarregar(url)
    }

    private static func fotoURL(de nom: String) async -> URL? {
        let net = nom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !net.isEmpty else { return nil }

        if let u = await fotoURLDirecta(idioma: "ca", titol: net) { return u }

        if let titolCa = await cercarTitol(idioma: "ca", consulta: net),
           let u = await fotoURLDirecta(idioma: "ca", titol: titolCa) { return u }

        if let titolEn = await cercarTitol(idioma: "en", consulta: net) {
            if let equivalent = await titolEnCatala(titolAngles: titolEn),
               let u = await fotoURLDirecta(idioma: "ca", titol: equivalent) { return u }
            if let u = await fotoURLDirecta(idioma: "en", titol: titolEn) { return u }
        }

        return await fotoURLDirecta(idioma: "es", titol: net)
    }

    // MARK: Peticions

    private static func descarregar(_ url: URL) async -> Data? {
        do {
            let (dades, resposta) = try await URLSession.shared.data(from: url)
            if let http = resposta as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
            return dades
        } catch {
            return nil
        }
    }

    private static func json(_ adreca: String) async -> [String: Any]? {
        guard let url = URL(string: adreca) else { return nil }
        do {
            let (dades, resposta) = try await URLSession.shared.data(from: url)
            if let http = resposta as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
            return try JSONSerialization.jsonObject(with: dades) as? [String: Any]
        } catch {
            return nil
        }
    }

    private static func codificar(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? text
    }

    /// Resum directe d'un article pel títol
    private static func resumDirecte(idioma: String, titol: String) async -> ResumViqui? {
        let t = codificar(titol)
        guard let j = await json("https://\(idioma).wikipedia.org/api/rest_v1/page/summary/\(t)"),
              let extracte = j["extract"] as? String, !extracte.isEmpty else { return nil }

        var font = "https://\(idioma).wikipedia.org/wiki/\(t)"
        if let urls = j["content_urls"] as? [String: Any],
           let desktop = urls["desktop"] as? [String: Any],
           let pagina = desktop["page"] as? String {
            font = pagina
        }
        return ResumViqui(text: extracte, font: font)
    }

    /// Enllaç a la imatge de l'article (la miniatura, més lleugera que l'original)
    private static func fotoURLDirecta(idioma: String, titol: String) async -> URL? {
        let t = codificar(titol)
        guard let j = await json("https://\(idioma).wikipedia.org/api/rest_v1/page/summary/\(t)") else { return nil }
        if let miniatura = j["thumbnail"] as? [String: Any],
           let font = miniatura["source"] as? String, let url = URL(string: font) {
            return url
        }
        if let original = j["originalimage"] as? [String: Any],
           let font = original["source"] as? String, let url = URL(string: font) {
            return url
        }
        return nil
    }

    /// Primer resultat de cerca d'un idioma
    private static func cercarTitol(idioma: String, consulta: String) async -> String? {
        let q = consulta.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? consulta
        let adreca = "https://\(idioma).wikipedia.org/w/api.php?action=query&list=search&srsearch=\(q)&srlimit=1&format=json&origin=*"
        guard let j = await json(adreca),
              let query = j["query"] as? [String: Any],
              let resultats = query["search"] as? [[String: Any]],
              let primer = resultats.first,
              let titol = primer["title"] as? String else { return nil }
        return titol
    }

    /// Equivalent en català d'un article anglès
    private static func titolEnCatala(titolAngles: String) async -> String? {
        let t = titolAngles.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? titolAngles
        let adreca = "https://en.wikipedia.org/w/api.php?action=query&titles=\(t)&prop=langlinks&lllang=ca&lllimit=1&format=json&origin=*"
        guard let j = await json(adreca),
              let query = j["query"] as? [String: Any],
              let pagines = query["pages"] as? [String: Any] else { return nil }

        for (_, valor) in pagines {
            if let pagina = valor as? [String: Any],
               let enllacos = pagina["langlinks"] as? [[String: Any]],
               let primer = enllacos.first,
               let titol = primer["*"] as? String {
                return titol
            }
        }
        return nil
    }
}

// MARK: - Ajudes generals

extension String {
    /// Talla el text per fer-lo servir en llistes
    func escurcat(_ maxim: Int) -> String {
        count <= maxim ? self : String(prefix(maxim)) + "…"
    }
}

/// Converteix un text de diverses línies en una llista d'elements nets
/// (treu vinyetes, espais i línies buides)
func liniesDeText(_ text: String) -> [String] {
    text.components(separatedBy: .newlines)
        .map { linia in
            var net = linia.trimmingCharacters(in: .whitespaces)
            while let primer = net.first, "-•*·◦▪".contains(primer) {
                net.removeFirst()
                net = net.trimmingCharacters(in: .whitespaces)
            }
            return net
        }
        .filter { !$0.isEmpty }
}
