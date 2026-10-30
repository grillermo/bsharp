import SwiftUI

/// The main screen. Task 9 of Plan 2 adds the controls and flags.
struct HomeView: View {
    let model: GameModel

    var body: some View {
        GeometryReader { geo in
            VStack {
                TitleCard(fontSize: TitleCard.fontSize(for: geo.size))
                    .padding(.top, 12)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(SkyBackground())
    }
}

#Preview { HomeView(model: GameModel(options: LaunchOptions(freshState: true))) }
