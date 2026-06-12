import SwiftUI

// The menu the web build keeps in its drawer: game actions on the main page
// (with display options at the bottom), and a Choose Game page listing the
// modes. Opened with play/pause.
struct MenuOverlay: View {
    @ObservedObject var model: AppModel

    var body: some View {
        let items = model.menuItems()
        let chooseGame = model.menuPage == .chooseGame

        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 6) {
                Text(chooseGame ? "Choose Game" : "Solitaire")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 18)

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isCursor = index == model.menuIndex
                    Text(item.label)
                        .font(.system(size: 30, weight: isCursor ? .bold : .regular))
                        .foregroundColor(item.enabled ? (isCursor ? .black : .white) : .gray)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isCursor ? Color.white : Color.clear)
                        )
                }

                Text(chooseGame ? "OK starts a new game · Back returns" : "OK selects · Play/Pause or Back closes")
                    .font(.system(size: 21))
                    .foregroundColor(.gray)
                    .padding(.top, 18)
            }
        }
    }
}

// Rule help for the current mode, formatted like the web dialog: "| TITLE"
// paragraphs become headers.
struct HelpOverlay: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Rule Help: \(model.game.mode.name)")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.bottom, 8)

                ForEach(Array(paragraphs().enumerated()), id: \.offset) { _, para in
                    if para.isHeader {
                        Text(para.text)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(red: 0.5, green: 0.8, blue: 0.5))
                    } else {
                        Text(para.text)
                            .font(.system(size: 26))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("OK or Back closes")
                    .font(.system(size: 21))
                    .foregroundColor(.gray)
                    .padding(.top, 12)
            }
            .frame(maxWidth: 1100)
        }
    }

    private struct Paragraph {
        let text: String
        let isHeader: Bool
    }

    private func paragraphs() -> [Paragraph] {
        model.game.mode.help.components(separatedBy: "\n\n").map { chunk in
            let flattened = chunk.replacingOccurrences(of: "\n", with: " ")
            if flattened.hasPrefix("| ") {
                return Paragraph(text: String(flattened.dropFirst(2)), isHeader: true)
            }
            return Paragraph(text: flattened, isHeader: false)
        }
    }
}

struct ToastOverlay: View {
    @ObservedObject var model: AppModel
    let won: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(won ? "You Win!" : "You Lose.")
                .font(.system(size: 54, weight: .bold))
                .foregroundColor(.white)
            Text("OK plays again · Back dismisses")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(0.82))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 70)
    }
}
