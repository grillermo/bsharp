import ElisaKit
import SwiftUI
import UniformTypeIdentifiers

/// The main screen: title, play and next, the play hint and the flags. Six quick taps on the
/// title open the parent-only progress import.
struct HomeView: View {
    let model: GameModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var unlock = TapUnlock()
    @State private var choosingFile = false
    @State private var pendingImport: Data?
    @State private var importError: String?

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size)
            VStack(spacing: 0) {
                TitleCard(fontSize: metrics.titleFont)
                    .padding(.top, 12)
                    .padding(.bottom, metrics.titleGap)
                    .onTapGesture {
                        if unlock.tap(at: Date().timeIntervalSince1970) { choosingFile = true }
                    }
                ControlsBar(buttonSize: metrics.buttonSize, iconSize: metrics.iconSize,
                            spacing: metrics.buttonSpacing, onPlay: { model.play() })
                    .padding(.bottom, metrics.controlsGap)
                if model.game.showsPlayHint {
                    PlayHint(buttonSize: metrics.buttonSize, spacing: metrics.buttonSpacing,
                             arrowSize: metrics.arrowSize)
                }
                FlagGrid(chords: model.game.chords, landscape: metrics.landscape, gap: metrics.flagGap,
                         marked: model.game.marked, dimmed: model.game.awaitingPlay,
                         noteStyle: model.game.noteStyle, onTap: { model.tap($0) })
                    // Portrait: stand the character on the flags. The web's 9vh lands its feet
                    // there; anchoring to the flags keeps that with the status bar above.
                    .overlay(alignment: .topTrailing) {
                        if !metrics.landscape {
                            reveal(metrics)
                                .padding(.trailing, metrics.revealTrailing - 10)
                                .offset(y: 4 - metrics.revealImageHeight)
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
            .overlay(alignment: .topTrailing) {
                if metrics.landscape {
                    reveal(metrics)
                        .padding(.top, metrics.revealTop)
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
