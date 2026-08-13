import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Document JSON per exportar/importar còpies de seguretat
struct ArxiuBackup: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var dades: Data

    init(dades: Data = Data()) {
        self.dades = dades
    }

    init(configuration: ReadConfiguration) throws {
        dades = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: dades)
    }
}

/// Exporta i importa totes les dades (viatges, equipatge, documents, zones,
/// llocs, fitxers adjunts i fotos) en un arxiu JSON independent de l'app.
enum Backup {

    struct BViatge: Codable {
        var nom: String
        var destinacio: String
        var notes: String
        var dataInici: Date
        var dataFi: Date
        var equipatge: [BItem]
        var documents: [BDocument]
        var zones: [BZona]
        // Camps nous (opcionals per poder llegir còpies antigues)
        var emoji: String?
        var nomApartatAltres: String?
        var horaris: [BHorari]?
        var altres: [BAltres]?
        var categories: [BCategoria]?
        var completat: Bool?
        var seccionsAltres: [BCategoria]?
        var emojiBitacora: String?
        var bitacora: [BVisita]?
    }
    struct BVisita: Codable {
        var nom: String
        var notes: String
        var adreca: String
        var urlMaps: String
        var latitud: Double
        var longitud: Double
        var dataVisita: Date
        var emoji: String
        var origen: String?
    }
    struct BCategoria: Codable {
        var nom: String
        var emoji: String
        var ordre: Int
    }
    struct BHorari: Codable {
        var tipus: String
        var origen: String
        var desti: String
        var dataHora: Date
        var duracio: String
        var notes: String
        var completat: Bool?
        var ordre: Int?
    }
    struct BAltres: Codable {
        var nom: String
        var fet: Bool
        var seccio: String?
        var ordre: Int?
    }
    struct BEnllac: Codable {
        var titol: String
        var url: String
        var ordre: Int
        var tipus: String?
    }
    struct BItem: Codable {
        var nom: String
        var categoria: String
        var empaquetat: Bool
        var ordre: Int?
    }
    struct BDocument: Codable {
        var titol: String
        var tipus: String
        var notes: String
        var nomFitxer: String
        var data: Date
        var dades: Data?
        var fitxers: [BFitxer]?
        var ordre: Int?
    }
    struct BFitxer: Codable {
        var nom: String
        var dades: Data?
    }
    struct BZona: Codable {
        var nom: String
        var ordre: Int
        var llocs: [BLloc]
        var enllacos: [BEnllac]?
    }
    struct BLloc: Codable {
        var nom: String
        var descripcio: String
        var urlMaps: String
        var ordre: Int
        var visitat: Bool
        var fotos: [Data]
        // Camps nous (opcionals per poder llegir còpies antigues)
        var fontDescripcio: String?
        var urlMapsGoogle: String?
        var cercaPersonalitzada: String?
        var enllacos: [BEnllac]?
    }

    /// Converteix tots els viatges en dades JSON
    static func exportar(_ viatges: [Viatge]) -> Data? {
        let llista = viatges.map { v in
            BViatge(
                nom: v.nom,
                destinacio: v.destinacio,
                notes: v.notes,
                dataInici: v.dataInici,
                dataFi: v.dataFi,
                equipatge: v.equipatgeLlista.map {
                    BItem(nom: $0.nom, categoria: $0.categoria, empaquetat: $0.empaquetat, ordre: $0.ordre)
                },
                documents: v.documentsLlista.map { d in
                    BDocument(titol: d.titol, tipus: d.tipus, notes: d.notes,
                              nomFitxer: d.nomFitxer, data: d.data, dades: d.dades,
                              fitxers: d.fitxersLlista.map {
                                  BFitxer(nom: $0.nomFitxer, dades: $0.dades)
                              },
                              ordre: d.ordre)
                },
                zones: v.zonesOrdenades.map { z in
                    BZona(nom: z.nom, ordre: z.ordre, llocs: z.llocsOrdenats.map { l in
                        BLloc(nom: l.nom, descripcio: l.descripcio, urlMaps: l.urlMaps,
                              ordre: l.ordre, visitat: l.visitat,
                              fotos: l.fotosLlista.compactMap(\.dades),
                              fontDescripcio: l.fontDescripcio,
                              urlMapsGoogle: l.urlMapsGoogle,
                              cercaPersonalitzada: l.cercaPersonalitzada,
                              enllacos: l.enllacosLlista.map {
                                  BEnllac(titol: $0.titol, url: $0.url, ordre: $0.ordre, tipus: $0.tipus)
                              })
                    }, enllacos: z.enllacosLlista.map {
                        BEnllac(titol: $0.titol, url: $0.url, ordre: $0.ordre, tipus: nil)
                    })
                },
                emoji: v.emoji,
                nomApartatAltres: v.nomApartatAltres,
                horaris: v.horarisLlista.map {
                    BHorari(tipus: $0.tipus, origen: $0.origen, desti: $0.desti,
                            dataHora: $0.dataHora, duracio: $0.duracio, notes: $0.notes,
                            completat: $0.completat, ordre: $0.ordre)
                },
                altres: v.altresLlista.map {
                    BAltres(nom: $0.nom, fet: $0.fet, seccio: $0.seccio, ordre: $0.ordre)
                },
                categories: v.categoriesLlista.map {
                    BCategoria(nom: $0.nom, emoji: $0.emoji, ordre: $0.ordre)
                },
                completat: v.completat,
                seccionsAltres: v.seccionsAltresLlista.map {
                    BCategoria(nom: $0.nom, emoji: $0.emoji, ordre: $0.ordre)
                },
                emojiBitacora: v.emojiBitacora,
                bitacora: v.bitacoraLlista.map {
                    BVisita(nom: $0.nom, notes: $0.notes, adreca: $0.adreca, urlMaps: $0.urlMaps,
                            latitud: $0.latitud, longitud: $0.longitud, dataVisita: $0.dataVisita,
                            emoji: $0.emoji, origen: $0.origen)
                }
            )
        }
        let codificador = JSONEncoder()
        codificador.dateEncodingStrategy = .iso8601
        return try? codificador.encode(llista)
    }

    /// Llegeix un arxiu JSON i recrea els viatges. Retorna quants n'ha importat.
    @discardableResult
    static func importar(_ dades: Data, a context: ModelContext) throws -> Int {
        let descodificador = JSONDecoder()
        descodificador.dateDecodingStrategy = .iso8601
        let llista = try descodificador.decode([BViatge].self, from: dades)

        for b in llista {
            let viatge = Viatge(nom: b.nom, destinacio: b.destinacio,
                                emoji: b.emoji ?? "✈️",
                                dataInici: b.dataInici, dataFi: b.dataFi, notes: b.notes)
            viatge.nomApartatAltres = b.nomApartatAltres ?? "Altres"
            viatge.completat = b.completat ?? false
            viatge.emojiBitacora = b.emojiBitacora ?? "📖"
            context.insert(viatge)

            for visita in b.bitacora ?? [] {
                context.insert(VisitaBitacora(
                    nom: visita.nom, notes: visita.notes, adreca: visita.adreca,
                    urlMaps: visita.urlMaps, latitud: visita.latitud, longitud: visita.longitud,
                    dataVisita: visita.dataVisita, emoji: visita.emoji,
                    origen: visita.origen ?? VisitaBitacora.origenManual, viatge: viatge
                ))
            }

            for h in b.horaris ?? [] {
                let horari = Horari(tipus: h.tipus, origen: h.origen, desti: h.desti,
                                    dataHora: h.dataHora, duracio: h.duracio,
                                    notes: h.notes, viatge: viatge)
                horari.completat = h.completat ?? false
                horari.ordre = h.ordre ?? 0
                context.insert(horari)
            }
            for s in b.seccionsAltres ?? [] {
                context.insert(SeccioAltres(nom: s.nom, emoji: s.emoji, ordre: s.ordre, viatge: viatge))
            }
            for a in b.altres ?? [] {
                let item = ItemAltres(nom: a.nom, seccio: a.seccio ?? "", ordre: a.ordre ?? 0, viatge: viatge)
                item.fet = a.fet
                context.insert(item)
            }

            let categoriesImportades = b.categories ?? []
            viatge.categoriesInicialitzades = !categoriesImportades.isEmpty
            for c in categoriesImportades {
                context.insert(CategoriaEquip(nom: c.nom, emoji: c.emoji, ordre: c.ordre, viatge: viatge))
            }
            for i in b.equipatge {
                let item = ItemEquipatge(nom: i.nom, categoria: i.categoria, ordre: i.ordre ?? 0, viatge: viatge)
                item.empaquetat = i.empaquetat
                context.insert(item)
            }
            for d in b.documents {
                let doc = DocumentViatge(titol: d.titol, tipus: d.tipus, notes: d.notes,
                                         data: d.data, viatge: viatge)
                doc.ordre = d.ordre ?? 0
                context.insert(doc)
                var ordre = 0
                for f in d.fitxers ?? [] {
                    context.insert(FitxerDocument(nomFitxer: f.nom, dades: f.dades, ordre: ordre, document: doc))
                    ordre += 1
                }
                // Còpies antigues: el fitxer únic passa a la llista
                if let dadesAntigues = d.dades {
                    context.insert(FitxerDocument(nomFitxer: d.nomFitxer.isEmpty ? "fitxer" : d.nomFitxer,
                                                  dades: dadesAntigues, ordre: ordre, document: doc))
                }
            }
            for z in b.zones {
                let zona = Zona(nom: z.nom, ordre: z.ordre, viatge: viatge)
                context.insert(zona)
                for e in z.enllacos ?? [] {
                    context.insert(EnllacZona(titol: e.titol, url: e.url, ordre: e.ordre, zona: zona))
                }
                for l in z.llocs {
                    let lloc = LlocInteres(nom: l.nom, descripcio: l.descripcio,
                                           urlMaps: l.urlMaps, ordre: l.ordre, zona: zona)
                    lloc.visitat = l.visitat
                    lloc.fontDescripcio = l.fontDescripcio ?? ""
                    lloc.urlMapsGoogle = l.urlMapsGoogle ?? ""
                    lloc.cercaPersonalitzada = l.cercaPersonalitzada ?? ""
                    context.insert(lloc)
                    for f in l.fotos {
                        context.insert(Foto(dades: f, lloc: lloc))
                    }
                    for e in l.enllacos ?? [] {
                        context.insert(EnllacLloc(titol: e.titol, url: e.url, tipus: e.tipus ?? EnllacLloc.tipusGeneral, ordre: e.ordre, lloc: lloc))
                    }
                }
            }
        }
        return llista.count
    }

    /// Nom fix de l'arxiu de còpia (l'extensió .json l'afegeix el selector en desar).
    /// La data ja hi surt sola al Finder, no cal repetir-la al nom.
    static var nomArxiu: String { "Viatges_App_backup" }
}
