import SwiftUI

/// The skeleton screen: sky and title card. Plan 2 adds the controls and flags below.
struct HomeView: View {
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

#Preview { HomeView() }
