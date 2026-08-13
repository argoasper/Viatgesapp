import Foundation

// MARK: - Exportació de la Bitàcora a GPX i KML
//
// GPX  → Wikiloc, Komoot, Garmin i la majoria d'apps d'excursionisme.
// KML  → Google My Maps i Google Earth.
//
// Cada visita amb coordenades surt com a punt, i les visites de cada dia
// s'uneixen en un recorregut per ordre d'hora.

enum ExportadorBitacora {

    /// Visites d'un viatge que tenen coordenades, agrupades per dia
    private static func diesAmbCoordenades(_ viatge: Viatge) -> [DiaBitacora] {
        viatge.bitacoraPerDia
            .map { DiaBitacora(dia: $0.dia, visites: $0.visites.filter(\.teCoordenades)) }
            .filter { !$0.visites.isEmpty }
            .sorted { $0.dia < $1.dia }
    }

    /// Quantes visites es podran exportar i quantes es quedaran fora
    static func recompte(_ viatge: Viatge) -> (exportables: Int, sensePosicio: Int) {
        let totes = viatge.bitacoraLlista
        let amb = totes.filter(\.teCoordenades).count
        return (amb, totes.count - amb)
    }

    // MARK: GPX

    static func gpx(_ viatge: Viatge) -> String {
        let dies = diesAmbCoordenades(viatge)
        let formatData = ISO8601DateFormatter()
        var linies: [String] = []

        linies.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Viatges" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escapar(nomViatge(viatge)))</name>
            <time>\(formatData.string(from: Date()))</time>
          </metadata>
        """)

        // Punts
        for dia in dies {
            for visita in dia.visites {
                linies.append("""
                  <wpt lat="\(visita.latitud)" lon="\(visita.longitud)">
                    <time>\(formatData.string(from: visita.dataVisita))</time>
                    <name>\(escapar(visita.nom))</name>
                    <desc>\(escapar(descripcio(de: visita, viatge: viatge)))</desc>
                  </wpt>
                """)
            }
        }

        // Un recorregut per dia
        for dia in dies where dia.visites.count > 1 {
            linies.append("""
              <trk>
                <name>\(escapar(nomDia(dia.dia, viatge: viatge)))</name>
                <trkseg>
            """)
            for visita in dia.visites {
                linies.append("""
                      <trkpt lat="\(visita.latitud)" lon="\(visita.longitud)">
                        <time>\(formatData.string(from: visita.dataVisita))</time>
                        <name>\(escapar(visita.nom))</name>
                      </trkpt>
                """)
            }
            linies.append("""
                </trkseg>
              </trk>
            """)
        }

        linies.append("</gpx>")
        return linies.joined(separator: "\n")
    }

    // MARK: KML

    static func kml(_ viatge: Viatge) -> String {
        let dies = diesAmbCoordenades(viatge)
        var linies: [String] = []

        linies.append("""
        <?xml version="1.0" encoding="UTF-8"?>
        <kml xmlns="http://www.opengis.net/kml/2.2">
          <Document>
            <name>\(escapar(nomViatge(viatge)))</name>
            <Style id="visita">
              <IconStyle><Icon><href>http://maps.google.com/mapfiles/kml/paddle/red-circle.png</href></Icon></IconStyle>
            </Style>
            <Style id="recorregut">
              <LineStyle><color>ff0088ff</color><width>4</width></LineStyle>
            </Style>
        """)

        for dia in dies {
            linies.append("""
                <Folder>
                  <name>\(escapar(nomDia(dia.dia, viatge: viatge)))</name>
            """)

            for visita in dia.visites {
                linies.append("""
                      <Placemark>
                        <name>\(escapar(visita.nom))</name>
                        <description>\(escapar(descripcio(de: visita, viatge: viatge)))</description>
                        <styleUrl>#visita</styleUrl>
                        <Point><coordinates>\(visita.longitud),\(visita.latitud),0</coordinates></Point>
                      </Placemark>
                """)
            }

            if dia.visites.count > 1 {
                let punts = dia.visites
                    .map { "\($0.longitud),\($0.latitud),0" }
                    .joined(separator: " ")
                linies.append("""
                      <Placemark>
                        <name>Recorregut</name>
                        <styleUrl>#recorregut</styleUrl>
                        <LineString>
                          <tessellate>1</tessellate>
                          <coordinates>\(punts)</coordinates>
                        </LineString>
                      </Placemark>
                """)
            }

            linies.append("    </Folder>")
        }

        linies.append("""
          </Document>
        </kml>
        """)
        return linies.joined(separator: "\n")
    }

    // MARK: Arxius

    /// Desa el contingut a un arxiu temporal i en torna l'adreça, a punt per compartir
    static func arxiu(_ contingut: String, nom: String) -> URL? {
        let carpeta = FileManager.default.temporaryDirectory
            .appendingPathComponent("Bitacora", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        let desti = carpeta.appendingPathComponent(nom)
        do {
            try contingut.write(to: desti, atomically: true, encoding: .utf8)
            return desti
        } catch {
            return nil
        }
    }

    /// Nom d'arxiu net, sense barres ni accents problemàtics
    static func nomArxiu(_ viatge: Viatge, extensio: String) -> String {
        let base = nomViatge(viatge)
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd"
        return "Bitacora-\(base.isEmpty ? "Viatge" : base)-\(format.string(from: Date())).\(extensio)"
    }

    // MARK: Text

    private static func nomViatge(_ viatge: Viatge) -> String {
        if !viatge.nom.isEmpty { return viatge.nom }
        if !viatge.destinacio.isEmpty { return viatge.destinacio }
        return "Viatge"
    }

    private static func nomDia(_ dia: Date, viatge: Viatge) -> String {
        let data = dia.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(localeCatala))
        if let numero = viatge.numeroDiaViatge(dia) { return "Dia \(numero) · \(data)" }
        return data
    }

    private static func descripcio(de visita: VisitaBitacora, viatge: Viatge) -> String {
        var parts: [String] = []
        parts.append(visita.dataVisita.formatCatala(date: .long, time: .shortened))
        if let numero = viatge.numeroDiaViatge(visita.dataVisita) { parts.append("Dia \(numero) del viatge") }
        if !visita.adreca.isEmpty { parts.append(visita.adreca) }
        if !visita.notes.isEmpty { parts.append(visita.notes) }
        if !visita.urlMaps.isEmpty { parts.append(visita.urlMaps) }
        return parts.joined(separator: "\n")
    }

    /// Escapa els caràcters que no poden anar dins d'un XML
    private static func escapar(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
