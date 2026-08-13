import Foundation

// MARK: - Resum de tot un viatge, en text pla, per compartir
//
// No sabem si l'enviaràs per Mail, el desaràs a Notes o el compartiràs per
// Missatges, així que en comptes de triar-ho nosaltres generem un text net
// i el compartim amb el full de compartir del sistema (ShareLink), que ja
// ofereix totes aquestes opcions.

enum ResumViatge {

    static func text(_ viatge: Viatge) -> String {
        var linies: [String] = []

        linies.append("\(viatge.emoji) \(viatge.nom.isEmpty ? "Viatge" : viatge.nom)")
        if !viatge.destinacio.isEmpty { linies.append("📍 \(viatge.destinacio)") }
        linies.append("📅 \(viatge.dataInici.formatCatala(date: .long, time: .omitted)) – \(viatge.dataFi.formatCatala(date: .long, time: .omitted))")
        if !viatge.notes.isEmpty {
            linies.append("")
            linies.append(viatge.notes)
        }

        // Equipatge
        let categoriesAmbItems = viatge.categoriesLlista.filter { !viatge.itemsEquipatge(de: $0.nom).isEmpty }
        if !categoriesAmbItems.isEmpty {
            linies.append("")
            linies.append("— EQUIPATGE —")
            for categoria in categoriesAmbItems {
                linies.append("\(categoria.emoji) \(categoria.nom)")
                for item in viatge.itemsEquipatge(de: categoria.nom) {
                    linies.append("  \(item.empaquetat ? "☑" : "☐") \(item.nom)")
                }
            }
        }

        // Documentació
        let tipusAmbDocs = TipusDocument.allCases.filter { !viatge.documents(de: $0.rawValue).isEmpty }
        if !tipusAmbDocs.isEmpty {
            linies.append("")
            linies.append("— DOCUMENTACIÓ —")
            for tipus in tipusAmbDocs {
                linies.append("\(tipus.emoji) \(tipus.rawValue)")
                for document in viatge.documents(de: tipus.rawValue) {
                    linies.append("  • \(document.titol.isEmpty ? "Sense títol" : document.titol)")
                    if !document.notes.isEmpty { linies.append("    \(document.notes)") }
                }
            }
        }

        // Horaris
        if !viatge.horarisLlista.isEmpty {
            linies.append("")
            linies.append("— HORARIS —")
            for horari in viatge.horarisLlista {
                var linia = "\(horari.emojiTransport) "
                if !horari.origen.isEmpty || !horari.desti.isEmpty {
                    linia += "\(horari.origen) → \(horari.desti): "
                }
                linia += horari.dataHora.formatCatala(date: .abbreviated, time: .shortened)
                linies.append(linia)
                if !horari.notes.isEmpty { linies.append("  \(horari.notes)") }
            }
        }

        // Itinerari
        if !viatge.zonesOrdenades.isEmpty {
            linies.append("")
            linies.append("— ITINERARI —")
            for zona in viatge.zonesOrdenades {
                linies.append("📍 \(zona.nom)")
                for lloc in zona.llocsOrdenats {
                    linies.append("  • \(lloc.nom)")
                }
            }
        }

        // Bitàcora
        if !viatge.bitacoraPerDia.isEmpty {
            linies.append("")
            linies.append("— BITÀCORA —")
            for dia in viatge.bitacoraPerDia.reversed() {
                linies.append("\(dia.dia.formatCatala(date: .abbreviated, time: .omitted)):")
                for visita in dia.visites {
                    linies.append("  \(visita.emoji) \(visita.nom)")
                }
            }
        }

        // Altres
        if !viatge.seccionsAltresLlista.isEmpty {
            let seccionsAmbItems = viatge.seccionsAltresLlista.filter { !viatge.itemsAltres(de: $0.nom).isEmpty }
            if !seccionsAmbItems.isEmpty {
                linies.append("")
                linies.append("— \(viatge.nomApartatAltres.uppercased()) —")
                for seccio in seccionsAmbItems {
                    linies.append("\(seccio.emoji) \(seccio.nom)")
                    for item in viatge.itemsAltres(de: seccio.nom) {
                        linies.append("  \(item.fet ? "☑" : "☐") \(item.nom)")
                    }
                }
            }
        }

        return linies.joined(separator: "\n")
    }
}
