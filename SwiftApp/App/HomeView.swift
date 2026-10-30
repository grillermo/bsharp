import ElisaKit
import SwiftUI

/// The main screen: title, play and next, the play hint and the flags.
struct HomeView: View {
    let model: GameModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geo in
            let metrics = Metrics(size: geo.size)
            VStack(spacing: 0) {
                TitleCard(fontSize: metrics.titleFont)
                    .padding(.top, 12)
                    .padding(.bottom, metrics.titleGap)
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
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(SkyBackground())
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.becameActive() }
        }
    }
}

#Preview { HomeView(model: GameModel(options: LaunchOptions(freshState: true))) }
