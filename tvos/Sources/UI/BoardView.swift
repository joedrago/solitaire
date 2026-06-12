import SwiftUI

struct BoardView: View {
    @ObservedObject var model: AppModel

    static let selectionColor = Color(red: 0.5, green: 0.5, blue: 1.0)
    static let foundationOnlyColor = Color.yellow

    // Theme. Dark mode dims the large bright surfaces (felt, white card faces,
    // cursor) without touching any assets — just color math.
    private var dark: Bool { model.darkMode.isDark }

    private var tableColor: Color {
        dark
            ? Color(red: 0x0b / 255.0, green: 0x14 / 255.0, blue: 0x0d / 255.0)
            : Color(red: 0x33 / 255.0, green: 0x66 / 255.0, blue: 0x33 / 255.0)
    }

    private var cursorColor: Color {
        // Warm amber at night reads as "night mode" and is far gentler than white.
        dark ? Color(red: 0.86, green: 0.68, blue: 0.38) : Color.white
    }

    // Color treatment for every card image, per the current dark-mode setting.
    private var cardTreatment: CardTreatment {
        model.darkMode.cardTreatment
    }

    // The resting color of the bottom-right game label: a muted gray that
    // recedes until Auto-Finish lights it up.
    private var labelColor: Color {
        dark ? Color(white: 0.45) : Color(white: 0.55)
    }

    var body: some View {
        GeometryReader { geo in
            let state = model.game.state!
            let board = BoardGeometry.compute(state: state, size: geo.size)
            let cursorSpot = cursorTargetSpot(board)

            ZStack(alignment: .topLeading) {
                ForEach(board.placements) { p in
                    // Drawing the cursor as part of its target card (rather than
                    // a top-level overlay) lets overlapping cards occlude it, so
                    // the outline hugs the visible portion of a buried card.
                    CardImage(
                        placement: p,
                        treatment: cardTreatment,
                        cursor: cursorSpot != nil && p.spot == cursorSpot,
                        cursorColor: cursorColor
                    )
                }

                texts(state: state, board: board, screen: geo.size)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(tableColor.ignoresSafeArea())
    }

    // The spot the cursor should highlight, guaranteed to have a placement so
    // it can be matched in the render loop. Nil while an overlay is up.
    private func cursorTargetSpot(_ board: BoardGeometry) -> Spot? {
        guard model.overlay == .none else {
            return nil
        }
        let nav = NavModel.build(model.game)
        guard let spot = model.cursorSpot(nav) else {
            return nil
        }
        if board.spotRects[spot] != nil {
            return spot
        }
        // A work spot whose card doesn't exist anymore (or an empty column's
        // guide); fall back to the column guide.
        if spot.type == .work {
            let guide = Spot(.work, spot.outer, -1)
            return board.spotRects[guide] != nil ? guide : nil
        }
        return nil
    }

    @ViewBuilder
    private func texts(state: GameState, board: BoardGeometry, screen: CGSize) -> some View {
        let unit = board.unit

        if let centerDisplay = state.centerDisplay {
            Text(centerDisplay)
                .font(.system(size: unit * 0.2, design: .monospaced))
                .foregroundColor(Color(red: 0x66 / 255.0, green: 0xaa / 255.0, blue: 0x66 / 255.0))
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .frame(width: screen.width)
                .position(x: screen.width / 2, y: 0.5 * unit + unit * 0.1)
        }

        if state.timerStart != nil {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                Text(timerText(state))
                    .font(.system(size: unit * 0.12, design: .monospaced))
                    .foregroundColor(timerColor(state))
                    .shadow(color: .black, radius: 0, x: 2, y: 2)
                    .frame(width: screen.width)
                    .position(x: screen.width / 2, y: 3.5 * unit)
            }
        }

        // The game name doubles as an affordance hint: muted gray normally, but
        // bold bright yellow when Auto-Finish is available in the menu.
        let gameLabel = "\(model.game.mode.name)\(state.hard ? " (Hard)" : "")"
        let canAutoFinish = model.game.canAutoWin()
        Text(gameLabel)
            .font(.system(size: 26, weight: canAutoFinish ? .bold : .regular, design: .monospaced))
            .foregroundColor(canAutoFinish ? Color.yellow : labelColor)
            .shadow(color: .black, radius: 0, x: 2, y: 2)
            .position(x: screen.width - CGFloat(gameLabel.count) * 8 - 30, y: screen.height - 30)
    }

    private func timerText(_ state: GameState) -> String {
        guard let start = state.timerStart else {
            return ""
        }
        let end = state.timerEnd ?? CardUtils.now()
        return prettyTime(end - start, showMS: state.timerEnd != nil)
    }

    private func timerColor(_ state: GameState) -> Color {
        switch state.timerColor {
        case "#3f3": return Color(red: 0.2, green: 1, blue: 0.2)
        case "#ff0": return Color.yellow
        default: return Color.white
        }
    }

    private func prettyTime(_ tIn: Double, showMS: Bool) -> String {
        var t = Int(tIn)
        let minutes = t / 60000
        t -= minutes * 60000
        let seconds = t / 1000
        t -= seconds * 1000
        if showMS {
            return String(format: "%02d:%02d.%03d", minutes, seconds, t)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CardImage: View {
    let placement: CardPlacement
    var treatment: CardTreatment = .identity
    var cursor: Bool = false
    var cursorColor: Color = .white

    var body: some View {
        let p = placement
        Image(imageName(p.raw))
            .resizable()
            .frame(width: p.rect.width, height: p.rect.height)
            .modifier(CardFX(t: treatment))
            .opacity(p.opacity)
            .overlay(selectionBorder)
            .overlay(cursorBorder)
            .position(x: p.rect.midX, y: p.rect.midY)
            .zIndex(p.zIndex)
    }

    @ViewBuilder
    private var cursorBorder: some View {
        if cursor {
            // Slightly larger than the card; not clipped, so it frames the card.
            // Drawn after CardFX so the dark-mode tint never recolors it.
            RoundedRectangle(cornerRadius: placement.rect.height * 0.07)
                .stroke(cursorColor, lineWidth: 5)
                .shadow(color: .black.opacity(0.8), radius: 6)
                .frame(width: placement.rect.width + 10, height: placement.rect.height + 10)
        }
    }

    @ViewBuilder
    private var selectionBorder: some View {
        switch placement.selected {
        case .none:
            EmptyView()
        case .selected:
            RoundedRectangle(cornerRadius: placement.rect.height * 0.06)
                .stroke(BoardView.selectionColor, lineWidth: 4)
        case .foundationOnly:
            RoundedRectangle(cornerRadius: placement.rect.height * 0.06)
                .stroke(BoardView.foundationOnlyColor, lineWidth: 4)
        }
    }

    private func imageName(_ raw: Int) -> String {
        switch raw {
        case CardUtils.GUIDE: return "cardGuide"
        case CardUtils.RESERVE: return "cardReserve"
        case CardUtils.DEAD: return "cardDead"
        case CardUtils.READY: return "cardReady"
        case CardUtils.BACK: return "cardBack"
        default:
            if (raw & CardUtils.FLIP_FLAG) != 0 {
                return "cardBack"
            }
            return "card\(raw & ~CardUtils.FLIP_FLAG)"
        }
    }
}
