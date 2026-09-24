import Foundation
import SwiftUI

// MARK: - Plantilla d'equipatge per defecte
//
// Cada viatge nou parteix d'aquesta plantilla: categories amb els seus
// elements ja posats. Després pots esborrar del viatge els que no vulguis
// sense tocar la plantilla, i quan una llista et convenci pots desar-la
// com a nova plantilla per defecte.

struct CategoriaPlantilla: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var nom: String
    var emoji: String
    var items: [String]

    init(id: UUID = UUID(), nom: String, emoji: String, items: [String]) {
        self.id = id
        self.nom = nom
        self.emoji = emoji
        self.items = items
    }
}

@Observable
final class PlantillaEquipatge {
    static let shared = PlantillaEquipatge()

    private static let clau = "plantillaEquipatge"

    private(set) var categories: [CategoriaPlantilla]

    private init() {
        categories = Self.llegirDelDisc() ?? Self.original
    }

    // MARK: Persistència

    private static func llegirDelDisc() -> [CategoriaPlantilla]? {
        guard let dades = UserDefaults.standard.data(forKey: clau),
              let llista = try? JSONDecoder().decode([CategoriaPlantilla].self, from: dades),
              !llista.isEmpty else { return nil }
        return llista
    }

    private func desarADisc() {
        guard let dades = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(dades, forKey: Self.clau)
    }

    // MARK: Consultes

    func categoria(nom: String) -> CategoriaPlantilla? {
        categories.first { $0.nom.caseInsensitiveCompare(nom) == .orderedSame }
    }

    func emoji(per nom: String) -> String {
        categoria(nom: nom)?.emoji ?? "📦"
    }

    var totalItems: Int { categories.reduce(0) { $0 + $1.items.count } }

    // MARK: Modificacions

    /// Substitueix la plantilla per l'equipatge d'un viatge concret.
    func desar(des viatge: Viatge) {
        categories = viatge.categoriesLlista.map { categoria in
            CategoriaPlantilla(nom: categoria.nom,
                               emoji: categoria.emoji,
                               items: viatge.itemsEquipatge(de: categoria.nom).map(\.nom))
        }
        desarADisc()
    }

    /// Afegeix a la plantilla les categories i elements d'un viatge que
    /// encara no hi siguin, sense treure'n res.
    func fusionar(amb viatge: Viatge) {
        for categoria in viatge.categoriesLlista {
            let noms = viatge.itemsEquipatge(de: categoria.nom).map(\.nom)
            if let index = categories.firstIndex(where: { $0.nom.caseInsensitiveCompare(categoria.nom) == .orderedSame }) {
                var existents = Set(categories[index].items.map { $0.lowercased() })
                for nom in noms where !existents.contains(nom.lowercased()) {
                    categories[index].items.append(nom)
                    existents.insert(nom.lowercased())
                }
            } else {
                categories.append(CategoriaPlantilla(nom: categoria.nom, emoji: categoria.emoji, items: noms))
            }
        }
        desarADisc()
    }

    func restablir() {
        categories = Self.original
        UserDefaults.standard.removeObject(forKey: Self.clau)
    }

    // MARK: Plantilla de fàbrica

    static let original: [CategoriaPlantilla] = [
        CategoriaPlantilla(nom: "Revisar a Casa", emoji: "🏠", items: [
            "Aigua",
            "Basura",
            "Candau de Terrassa",
            "Gas",
            "Parar grup d'endolls de dalt i abaix",
            "Apagar Mac mini",
            "Alfombra de fora",
            "Posar llum a la cuina",
            "Posar tapa dutxa i tancar taps",
            "Toldo",
            "Càmera",
            "Regar plantes"
        ]),
        CategoriaPlantilla(nom: "Tecnologia", emoji: "💻", items: [
            "Llapis",
            "iPad",
            "Chubasquero",
            "Trípode",
            "Endoll triple",
            "Airpods pro",
            "Corretja watch",
            "Airpods max",
            "Carregadors",
            "Disc dur pel·lícules",
            "Papers impressos",
            "Passaports",
            "iPhone vell",
            "Bateria iPhone",
            "Altaveu Bose",
            "Teclat Mac",
            "Hub",
            "Magic Mouse",
            "HDMI",
            "Kindle"
        ]),
        CategoriaPlantilla(nom: "Medicaments", emoji: "💊", items: [
            "Ibuprofeno",
            "Antibiòtic",
            "Fortasec",
            "Paracetamol",
            "Flumicil",
            "Pectox",
            "Mounjaro"
        ]),
        CategoriaPlantilla(nom: "Higiene", emoji: "🧴", items: [
            "Afeitadora",
            "Renta dents",
            "Colònia",
            "Desodorant",
            "Pasta dents"
        ]),
        CategoriaPlantilla(nom: "Esports", emoji: "⚽️", items: [
            "Protector rellotge",
            "Carregador bici",
            "Dipòsit aigua - i motxilla",
            "Maillot i samarreta",
            "Casc",
            "Manxa automàtica",
            "Guants",
            "Ulleres bici",
            "Claus bateria",
            "Bateria",
            "Bambes corre",
            "Adaptadors airpods"
        ]),
        CategoriaPlantilla(nom: "Roba", emoji: "👕", items: [
            "Tovallola platja",
            "Bossa platja",
            "Cadira platja",
            "Crema solar",
            "Pantalons estar per casa",
            "Bermudes",
            "Samarretes",
            "Calçotets",
            "Mitjons",
            "Sabates sense cordons",
            "Sabates normals",
            "Bambes on cloud",
            "Pantalon llarg",
            "Camisa",
            "Banyador"
        ]),
        CategoriaPlantilla(nom: "Menjar", emoji: "🍫", items: [
            "Menjar Ocell",
            "Coses de la nevera",
            "Pastilles renta",
            "Sobrassada"
        ])
    ]
}
