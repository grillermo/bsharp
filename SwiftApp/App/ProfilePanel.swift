import ElisaKit
import SwiftUI

/// Profiles and settings (#profile-info-container): the switcher, then the form. Level and
/// instrument apply at once, as the web app's selectors do; the rest waits for Guardar (or
/// Agregar perfil in add mode), which closes the panel.
struct ProfilePanel: View {
    let model: GameModel
    let onClose: () -> Void

    @State private var adding = false
    @State private var draft = ProfileSettings.blank
    @State private var failure: String?
    @State private var confirmingDelete = false
    @State private var showingGuidedAccess = false

    private var profile: Profile { model.game.profile }
    private var isGuest: Bool { profile.id == Defaults.guestProfileID }

    static let showChordModes = [("always", "Siempre"), ("black_only", "Solo acordes negros"), ("never", "Nunca")]
    static let revealChordModes = [("always", "Siempre"), ("after_guess", "Después de adivinar")]
    static let chordDisplayModes = [("shapes_and_letters", "Figuras y letras"), ("shapes_only", "Solo figuras"),
                                    ("letters_only", "Solo letras")]
    static let selectionModes = [("random", "Al azar"), ("adaptive", "Adaptativa")]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                switcher
                Divider().overlay(Color(white: 0.33))
                row("Nivel:") { levelPicker }
                row("Instrumento:") { instrumentPicker }
                row("Nombre:") {
                    TextField("", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.text(18))
                        .frame(maxWidth: 260)
                        .disabled(isGuest && !adding)
                        .accessibilityIdentifier("profile-name")
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ícono:")
                    iconPicker
                }
                row("Mostrar notas del acorde:") { picker($draft.showChordMode, Self.showChordModes, id: "profile-show-chord") }
                row("Mostrar notas:") { picker($draft.revealChordMode, Self.revealChordModes, id: "profile-reveal") }
                row("Formato de notas:") { picker($draft.chordDisplayMode, Self.chordDisplayModes, id: "profile-display") }
                row("Mantener carita:") { Toggle("", isOn: $draft.persistReactionFace).labelsHidden() }
                row("Mostrar ayudas:") {
                    Toggle("", isOn: $draft.enableOnboardingHints).labelsHidden()
                        .accessibilityIdentifier("profile-hints")
                }
                row("Meta por sesión:") {
                    TextField("", text: $draft.targetNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(Theme.text(18))
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("profile-target")
                }
                row("Elección de acordes:") { picker($draft.chordSelectionMode, Self.selectionModes, id: "profile-selection") }
                row("Fijar pantalla:") {
                    Button { showingGuidedAccess = true } label: { Label("Info", systemImage: "pin.fill") }
                        .buttonStyle(PillButtonStyle())
                        .accessibilityIdentifier("profile-guided-access")
                }
                buttons
            }
            .font(Theme.text(22))
            .foregroundStyle(Theme.ink)
            .tint(Theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .onAppear { draft = ProfileSettings(profile: profile) }
        .alert("No se pudo guardar",
               isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(failure ?? "")
        }
        .alert("¿Seguro que quieres borrar el perfil \(profile.name)?", isPresented: $confirmingDelete) {
            Button("Borrar", role: .destructive) { run { try model.deleteProfile(); onClose() } }
            Button("Cancelar", role: .cancel) {}
        }
        .sheet(isPresented: $showingGuidedAccess) { GuidedAccessInfo() }
    }

    // MARK: Switcher

    private var switcher: some View {
        HStack(spacing: 8) {
            ForEach(model.game.progress.switcherProfiles, id: \.id) { other in
                Button {
                    adding = false
                    model.switchProfile(other.id)
                    draft = ProfileSettings(profile: model.game.profile)
                } label: {
                    switcherCircle(ProfileIcons.symbol(for: other.icon), active: !adding && other.id == profile.id,
                                   dashed: false)
                }
                .accessibilityIdentifier("switcher-\(other.id)")
                .accessibilityLabel(other.name)
            }
            Button {
                adding = true
                draft = .blank
            } label: {
                switcherCircle("plus", active: adding, dashed: true)
            }
            .accessibilityIdentifier("profile-add")
        }
    }

    private func switcherCircle(_ symbol: String, active: Bool, dashed: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(Theme.noteInk)
            .frame(width: 40, height: 40)
            .background(Circle().fill(active ? Color(white: 0.88) : .clear))
            .overlay(
                Circle().strokeBorder(active ? Theme.active : (dashed ? Color(white: 0.53) : .clear),
                                      style: StrokeStyle(lineWidth: 2, dash: dashed && !active ? [4, 3] : []))
            )
    }

    // MARK: Fields

    private func row<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        // Label and field side by side when they fit, the field under the label on a phone.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { Text(label); content() }
            VStack(alignment: .leading, spacing: 8) { Text(label); content() }
        }
    }

    private var levelPicker: some View {
        Picker("Nivel", selection: Binding(get: { model.game.level }, set: { model.changeLevel($0) })) {
            Section("Acordes blancos") {
                ForEach(LevelOptions.white(includingRed: model.redLevelUnlocked || model.game.level == "red")) {
                    Text($0.label).tag($0.id)
                }
            }
            Section("Acordes negros") {
                ForEach(LevelOptions.black) { Text($0.label).tag($0.id) }
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("profile-level")
    }

    private var instrumentPicker: some View {
        Picker("Instrumento", selection: Binding(get: { model.game.instrument },
                                                 set: { model.changeInstrument($0) })) {
            ForEach(Instrument.allCases, id: \.self) { Text($0.spanishName).tag($0) }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("profile-instrument")
    }

    private func picker(_ selection: Binding<String>, _ options: [(String, String)], id: String) -> some View {
        Picker("", selection: selection) {
            ForEach(options, id: \.0) { Text($0.1).tag($0.0) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityIdentifier(id)
    }

    /// The icons as round buttons (the web app's radio buttons, too small for a finger).
    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(ProfileIcons.all, id: \.self) { icon in
                Button { draft.icon = icon } label: {
                    Image(systemName: ProfileIcons.symbol(for: icon))
                        .font(.system(size: 24))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(draft.icon == icon ? Theme.edge : .clear))
                }
                .accessibilityIdentifier("icon-\(icon)")
                .accessibilityValue(draft.icon == icon ? "selected" : "")
            }
        }
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack {
            if adding {
                Spacer()
                Button("Agregar perfil") { run { try model.addProfile(draft); onClose() } }
                    .accessibilityIdentifier("profile-submit-add")
                Spacer()
            } else {
                Button("Borrar perfil") { confirmingDelete = true }
                    .disabled(isGuest)
                    .accessibilityIdentifier("profile-delete")
                Spacer()
                Button("Guardar") { run { try model.updateProfile(draft); onClose() } }
                    .accessibilityIdentifier("profile-save")
            }
        }
        .buttonStyle(PillButtonStyle())
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
        } catch let error as ProfileError {
            failure = error.message
        } catch {
            failure = error.localizedDescription
        }
    }
}

#Preview {
    PanelCard { ProfilePanel(model: GameModel(options: LaunchOptions(freshState: true)), onClose: {}) }.padding()
}
