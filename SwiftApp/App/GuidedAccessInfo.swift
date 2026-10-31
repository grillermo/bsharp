import SwiftUI
import UIKit

/// How to lock the iPad to this app (the web app's screen-pinning modal), behind
/// "Fijar pantalla". An app can't start Guided Access itself on an unmanaged iPad.
struct GuidedAccessInfo: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if UIAccessibility.isGuidedAccessEnabled {
                    Text("**Acceso guiado está activo ahora.**")
                }
                Text("**Acceso guiado** deja el iPad fijo en esta app para que Elisa no pueda salirse.")
                    .accessibilityIdentifier("guided-access-info")
                Text("**Actívalo:**")
                Text("1. Abre **Ajustes > Accesibilidad > Acceso guiado** y actívalo.\n2. En **Ajustes de código**, define un código.")
                Text("**Úsalo:**")
                Text("1. Abre la app y presiona tres veces el botón superior.\n2. Toca **Iniciar**.")
                Text("**Para salir:** presiona tres veces el botón superior e ingresa el código.")
                HStack {
                    Spacer()
                    Button("OK") { dismiss() }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityIdentifier("guided-access-ok")
                    Spacer()
                }
                .padding(.top, 8)
            }
            .font(Theme.text(18))
            .foregroundStyle(Theme.ink)
            .padding(28)
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview { Text("").sheet(isPresented: .constant(true)) { GuidedAccessInfo() } }
