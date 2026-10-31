import SwiftUI

/// What the method is and how to practise (#i-infobox). The links open in Safari; six quick
/// taps on "rojo" unlock level 0 in the level picker.
struct InfoPanel: View {
    let onRojo: () -> Void

    private static let paragraphs = [
        "Esta app usa el [método de identificación de acordes de Eguchi](https://www.ganbar.us/documents/sakakibara_2012_chord_identification.pdf). Ver también [Ichionkai Music School](https://ichionkai.co.jp/english3.html).",
        "[Video corto (en inglés) de cómo se usa](https://youtu.be/kNfkm6PQC20).",
        "Es un método para enseñar oído absoluto a niños de 2 a 6 años. Practiquen unas 5 veces al día, 2–3 minutos cada vez (unas 20–25 respuestas). Los acordes siempre se identifican con colores, en este orden: [rojo](elisa://rojo) (Do Mi Sol), amarillo (Do Fa La), azul (Si Re Sol), negro (La Do Fa), verde (Re Sol Si), naranja (Mi Sol Do), morado (Fa La Do), rosa (Sol Si Re), café (Sol Do Mi).",
        "Presenten los acordes uno por uno, con al menos 2 semanas entre cada acorde nuevo. No agreguen un acorde nuevo hasta que identifique todos los actuales con 100% de aciertos.",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(Self.paragraphs, id: \.self) { paragraph in
                    Text((try? AttributedString(markdown: paragraph)) ?? AttributedString(paragraph))
                }
            }
            .font(Theme.text(20))
            .lineSpacing(8)
            // Links look like the rest of the text, as on bluey.chiq.me.
            .tint(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "elisa" else { return .systemAction }
            onRojo()
            return .handled
        })
        .accessibilityIdentifier("info-panel")
    }
}

#Preview { PanelCard { InfoPanel(onRojo: {}) }.padding() }
