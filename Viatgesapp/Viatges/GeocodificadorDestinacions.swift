import Foundation
import CoreLocation

// MARK: - Tot el que sabem del destí d'un viatge
//
// El viatge només guarda un text lliure ("destinacio"). Per poder-hi mostrar
// un mapa, la primera vegada que s'obre la pantalla del viatge busquem les
// coordenades amb el geocodificador d'Apple i les desem al mateix viatge,
// perquè les properes vegades no calgui tornar-ho a fer.
//
// De pas, aprofitem la resposta del geocodificador (que sap si el lloc és
// vora mar, vora un llac, etc.) per triar un dibuix més encertat que no pas
// endevinar-ho només a partir del text que has escrit, i mirem si la
// Viquipèdia té una foto real del lloc per fer-la servir de fons de la
// targeta (si no en té, es queda el dibuix).

enum GeocodificadorDestinacions {

    /// Busca i desa les coordenades, el dibuix i la foto del viatge si
    /// encara no en té, o si el destí ha canviat des de l'última cerca (per
    /// exemple, si has precisat "Sant Antoni" a "Sant Antoni de Calonge").
    static func geocodifica(_ viatge: Viatge) async {
        let destinacio = viatge.destinacio.trimmingCharacters(in: .whitespacesAndNewlines)
        let nom = viatge.nom.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = destinacio.isEmpty ? nom : destinacio

        guard !text.isEmpty else {
            viatge.latitud = 0
            viatge.longitud = 0
            viatge.textGeocodificat = ""
            viatge.tipusEscenaPortada = ""
            viatge.geocodificacioIntentada = true
            viatge.fotoPortada = nil
            viatge.fotoPortadaIntentada = true
            return
        }

        // El destí ha canviat respecte l'última cerca: oblidem el que sabíem
        // perquè es torni a intentar amb el text nou
        if text != viatge.textGeocodificat {
            viatge.latitud = 0
            viatge.longitud = 0
            viatge.tipusEscenaPortada = ""
            viatge.geocodificacioIntentada = false
            viatge.fotoPortada = nil
            viatge.fotoPortadaIntentada = false
        }

        let calGeocodificar = !viatge.teCoordenades && !viatge.geocodificacioIntentada
        let calBuscarFoto = viatge.fotoPortada == nil && !viatge.fotoPortadaIntentada

        guard calGeocodificar || calBuscarFoto else { return }

        // Una cerca darrere l'altra (Apple i després Viquipèdia): és més
        // senzill i segur que fer-les alhora, i el cost és mínim
        if calGeocodificar {
            do {
                let llocs = try await CLGeocoder().geocodeAddressString(text)
                if let lloc = llocs.first {
                    if let coordenades = lloc.location?.coordinate {
                        viatge.latitud = coordenades.latitude
                        viatge.longitud = coordenades.longitude
                    }
                    viatge.tipusEscenaPortada = EstilViatge.escena(perPlacemark: lloc, textDesti: text).rawValue
                }
            } catch {
                // Sense connexió o destí no trobat: no ho tornem a provar amb
                // el mateix text, però es pot obrir Apple Maps a mà.
            }
            viatge.geocodificacioIntentada = true
        }

        if calBuscarFoto {
            viatge.fotoPortada = await Viquipedia.fotoPortada(de: text)
            viatge.fotoPortadaIntentada = true
        }

        viatge.textGeocodificat = text
    }
}
