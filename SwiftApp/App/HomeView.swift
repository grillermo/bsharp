import ElisaKit
import SwiftUI
import UniformTypeIdentifiers

/// The main screen: the gear menu at the top, then either the game (flags, the play hint and
/// the play button) or the open panel. Six quick taps on the empty part of the top bar open
/// the parent-only progress import.
struct HomeView: View {
    let model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlock = TapUnlock()
    @State private var choosingFile = false
    @State private var pendingImport: Data?
    @State private var importError: String?
    @State private var menuOpen = false
    @State private var panel: Panel?

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size)
            VStack(spacing: 0) {
                topBar(metrics)
                    .padding(.bottom, metrics.controlsGap)
                if let panel {
                    PanelCard { panelView(panel, metrics) }
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                } else {
                    FlagGrid(chords: model.game.chords, landscape: metrics.landscape, gap: metrics.flagGap,
                             marked: model.game.marked, dimmed: model.game.awaitingPlay,
                             noteStyle: model.game.noteStyle, onTap: { model.tap($0) })
                        .padding(.bottom, metrics.controlsGap)
                    if model.game.showsPlayHint {
                        PlayHint(buttonSize: metrics.buttonSize, arrowSize: metrics.arrowSize)
                    }
                    ControlsBar(buttonSize: metrics.buttonSize, iconSize: metrics.iconSize,
                                onPlay: { model.play() })
                        .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            // The character pops up at the bottom, beside the play button.
            .overlay(alignment: .bottomTrailing) {
                if panel == nil {
                    reveal(metrics)
                        .padding(.bottom, 10)
                        .padding(.trailing, metrics.revealTrailing)
                }
            }
        }
        .background(SkyBackground())
        .overlay {
            StreakOutline(streak: model.game.streak).ignoresSafeArea()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
            readImport(result)
        }
        .alert("¿Reemplazar el progreso con este archivo?",
               isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } })) {
            Button("Reemplazar", role: .destructive) { confirmImport() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El progreso actual se guarda aparte por si acaso.")
        }
        .alert("No se pudo importar",
               isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
    }

    /// The character reveal, faded in and out as the right answer's character comes and goes.
    private func reveal(_ metrics: Metrics) -> some View {
        ZStack {
            if let name = model.game.character {
                CharacterReveal(name: name, metrics: metrics)
                    .id(name)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.game.character)
    }

    /// The gear menu over a clear strip; six quick taps on the strip open the progress import.
    private func topBar(_ metrics: Metrics) -> some View {
        MenuBar(open: $menuOpen, panel: $panel, profile: model.game.profile, metrics: metrics)
            .padding(.top, 6)
            .frame(minHeight: 44)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if unlock.tap(at: Date().timeIntervalSince1970) { choosingFile = true }
                    }
                    .accessibilityIdentifier("import-strip")
            }
    }

    @ViewBuilder
    private func panelView(_ panel: Panel, _ metrics: Metrics) -> some View {
        switch panel {
        case .trainer: TrainerPanel(landscape: metrics.landscape, onTap: { model.playTrainer($0) })
        case .info: InfoPanel(onRojo: { model.easterEggTap() })
        case .history: HistoryPanel(rows: model.game.progress.historyRows)
        case .profile: ProfilePanel(model: model, onClose: { self.panel = nil })
        }
    }

    /// Reads and checks the file before asking, so a wrong file fails here and not after
    /// "Reemplazar".
    private func readImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            _ = try ProgressStore.decode(data)
            pendingImport = data
        } catch {
            importError = error.localizedDescription
        }
    }

    private func confirmImport() {
        guard let data = pendingImport else { return }
        pendingImport = nil
        do {
            try model.importProgress(data)
        } catch {
            importError = error.localizedDescription
        }
    }
}

#Preview { HomeView(model: GameModel(options: LaunchOptions(freshState: true))) }
