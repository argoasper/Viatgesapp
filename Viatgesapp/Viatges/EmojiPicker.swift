import SwiftUI

/// Selector d'emojis amb cercador (en català)
struct EmojiPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var seleccio: String
    @State private var cerca = ""

    // Emoji + paraules clau per buscar
    private static let emojis: [(String, String)] = [
        ("✈️", "avio vol volar aeroport viatge"),
        ("🛫", "avio sortida enlairar"),
        ("🚆", "tren ferrocarril estacio"),
        ("🚄", "tren alta velocitat ave"),
        ("🚇", "metro subterrani"),
        ("🚌", "autobus bus"),
        ("🚗", "cotxe carretera conduir"),
        ("🚢", "vaixell creuer barco mar"),
        ("⛴️", "ferri vaixell barco"),
        ("⛵️", "veler barca vela mar"),
        ("🚠", "telecabina telefèric muntanya"),
        ("🏍️", "moto motocicleta"),
        ("🚲", "bicicleta bici pedalar"),
        ("🏝️", "illa platja tropical paradis"),
        ("🏖️", "platja sorra mar vacances"),
        ("🌊", "mar ona onada oceà"),
        ("⛰️", "muntanya excursio"),
        ("🏔️", "muntanya neu cim"),
        ("🗻", "fuji japo muntanya volca"),
        ("🌋", "volca lava"),
        ("🏕️", "acampada tenda camping natura"),
        ("⛺️", "tenda acampada camping"),
        ("🌲", "bosc arbre pi natura"),
        ("🌴", "palmera tropical platja"),
        ("🌵", "cactus desert"),
        ("🏜️", "desert dunes sorra"),
        ("🌅", "sortida sol alba platja"),
        ("🌄", "sortida sol muntanya alba"),
        ("🌇", "posta sol ciutat capvespre"),
        ("🏙️", "ciutat gratacels urbà"),
        ("🌆", "ciutat capvespre"),
        ("🗼", "torre eiffel paris tokyo"),
        ("🗽", "estatua llibertat nova york"),
        ("🏰", "castell palau disney"),
        ("🏯", "castell japones japo"),
        ("⛩️", "torii japo temple santuari"),
        ("🕌", "mesquita turquia marroc"),
        ("⛪️", "esglesia catedral"),
        ("🏛️", "museu grecia roma temple monument"),
        ("🕍", "sinagoga"),
        ("🗿", "moai pasqua estatua"),
        ("🌉", "pont nit san francisco"),
        ("🎡", "noria fira atraccions"),
        ("🎢", "muntanya russa parc atraccions"),
        ("🎠", "cavallets fira"),
        ("🎪", "circ carpa"),
        ("🎭", "teatre mascares espectacle"),
        ("🎨", "art pintura museu"),
        ("🖼️", "quadre museu art"),
        ("🎿", "esqui neu hivern"),
        ("🏂", "snowboard neu hivern"),
        ("⛷️", "esqui neu"),
        ("❄️", "neu fred hivern"),
        ("🏄‍♂️", "surf mar ona"),
        ("🏊‍♂️", "nedar piscina mar"),
        ("🤿", "busseig snorkel submarinisme"),
        ("🚴‍♂️", "bicicleta ciclisme"),
        ("🥾", "senderisme botes excursio caminar"),
        ("🧗‍♂️", "escalada muntanya"),
        ("🎣", "pesca peix"),
        ("⚽️", "futbol partit"),
        ("🏀", "basquet"),
        ("🎾", "tenis"),
        ("⛳️", "golf"),
        ("🍜", "ramen fideus japo menjar"),
        ("🍣", "sushi japo menjar"),
        ("🍕", "pizza italia menjar"),
        ("🍝", "pasta italia menjar"),
        ("🥐", "croissant frança esmorzar"),
        ("🥘", "paella menjar espanya"),
        ("🌮", "taco mexic menjar"),
        ("🍷", "vi celler copa"),
        ("🍺", "cervesa bar"),
        ("🍸", "coctel copa festa"),
        ("☕️", "cafe esmorzar"),
        ("🍽️", "restaurant menjar sopar"),
        ("🧀", "formatge"),
        ("🍦", "gelat estiu"),
        ("🎒", "motxilla equipatge"),
        ("🧳", "maleta equipatge viatge"),
        ("📷", "camera fotos fotografia"),
        ("🗺️", "mapa itinerari"),
        ("🧭", "brúixola orientacio aventura"),
        ("🎫", "entrada bitllet tiquet"),
        ("🛂", "passaport control frontera"),
        ("💶", "euros diners"),
        ("💴", "iens japo diners"),
        ("💵", "dolars diners"),
        ("🏨", "hotel allotjament"),
        ("🛏️", "llit dormir hotel"),
        ("🐘", "elefant safari africa asia"),
        ("🦁", "lleo safari africa"),
        ("🦒", "girafa safari africa"),
        ("🐬", "dofi mar"),
        ("🐠", "peix tropical snorkel"),
        ("🐢", "tortuga mar"),
        ("🦜", "lloro tropical selva"),
        ("🐒", "mico selva"),
        ("🌸", "sakura flor japo primavera"),
        ("🍁", "tardor fulla canada"),
        ("🎄", "nadal arbre hivern"),
        ("🎆", "focs artificials festa cap any"),
        ("🎉", "festa celebracio"),
        ("❤️", "cor amor lluna mel"),
        ("💍", "anell casament lluna mel"),
        ("⭐️", "estrella"),
        ("🌟", "estrella brillant"),
        ("🔥", "foc aventura"),
        ("💎", "diamant luxe"),
        ("👑", "corona reial luxe"),
        ("🎁", "regal compres"),
        ("🛍️", "compres botigues shopping"),
        ("🌍", "mon terra europa africa"),
        ("🌎", "mon terra america"),
        ("🌏", "mon terra asia oceania"),
        ("🚀", "coet espai aventura"),
        ("🎵", "musica concert festival"),
        ("🎸", "guitarra concert musica"),
        ("📚", "llibres cultura estudi"),
        ("🧘‍♀️", "ioga relax benestar"),
        ("💆‍♀️", "spa massatge relax"),
        ("♨️", "termes aigues termals onsen"),
        ("📖", "llibre bitacora diari registre"),
        ("📔", "llibreta diari bitacora"),
        ("📍", "punt lloc ubicacio pin"),
        ("📦", "capsa paquet varis"),
        ("🏠", "casa llar"),
        ("👕", "roba samarreta"),
        ("💻", "ordinador tecnologia portatil"),
        ("💊", "medicaments pastilles farmacia"),
        ("📄", "document paper full"),
        ("🍫", "xocolata menjar snack"),
        ("🧴", "higiene gel xampu"),
        ("💼", "feina maletí treball"),
        ("🗂️", "documentacio carpetes arxius"),
        ("🕒", "hora rellotge horaris"),
        ("📝", "notes escriure llista"),
    ]

    private var filtrats: [(String, String)] {
        guard !cerca.isEmpty else { return Self.emojis }
        let q = cerca.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        return Self.emojis.filter { emoji, paraules in
            emoji == cerca || paraules.folding(options: .diacriticInsensitive, locale: .current).contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Cerca (p. ex. platja, tren, japó...)", text: $cerca)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .padding()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                        ForEach(filtrats, id: \.0) { emoji, _ in
                            Button {
                                seleccio = emoji
                                dismiss()
                            } label: {
                                Text(emoji)
                                    .font(.system(size: 38))
                                    .frame(width: 56, height: 56)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(seleccio == emoji ? Color.accentColor.opacity(0.25) : Color.gray.opacity(0.08))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)

                    if filtrats.isEmpty {
                        ContentUnavailableView(
                            "Cap resultat",
                            systemImage: "magnifyingglass",
                            description: Text("Prova una altra paraula, o enganxa directament un emoji al cercador.")
                        )
                        .padding(.top, 40)
                    }
                }
            }
            .navigationTitle("Tria una icona")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel·la") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 480)
        #endif
    }
}
