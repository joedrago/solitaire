import SwiftUI

@main
struct SolitaireApp: App {
    var body: some Scene {
        WindowGroup {
            GameScreen()
        }
    }
}

struct GameScreen: View {
    @StateObject private var model = AppModel()

    var body: some View {
        ZStack {
            BoardView(model: model)

            // Transparent press-capture layer; the only focusable view.
            RemoteInput(model: model)
                .ignoresSafeArea()

            switch model.overlay {
            case .none:
                EmptyView()
            case .menu:
                MenuOverlay(model: model)
            case .help:
                HelpOverlay(model: model)
            case .win:
                ToastOverlay(model: model, won: true)
            case .lose:
                ToastOverlay(model: model, won: false)
            case .shuffling:
                ShufflingOverlay()
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}
