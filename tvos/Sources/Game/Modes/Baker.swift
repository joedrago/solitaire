import Foundation

// Port of src/modes/baker.js
struct BakerMode: GameMode {
    let id = "baker"
    let name = "Baker's Dozen"
    let help = """
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Build columns down regardless of suit. Only the topmost card may be moved \
to another column which meets the build requirements. Empty columns must \
stay empty.

The topmost card of any column may be moved to a foundation.

Kings are always dealt to the bottom of columns.

| HARD MODE:

Easy - All cards are dealt face up.

Hard - The last non-King card is face down in each column.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "none"),
            pile: PileState(show: g.hard ? 1 : 3),
            foundations: [CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE]
        )

        // shuffle the deck, but shuffle kings separately
        var nonKings: [Int] = []
        nonKings.append(contentsOf: 0...11)
        nonKings.append(contentsOf: 13...24)
        nonKings.append(contentsOf: 26...37)
        nonKings.append(contentsOf: 39...50)
        var deck = shuffled(nonKings)
        let kings = shuffled([12, 25, 38, 51])

        for _ in 0..<13 {
            g.state.work.append([])
        }

        let kingPositions = Array(shuffled(Array(0...12)).prefix(4))
        for (pIndex, p) in kingPositions.enumerated() {
            g.state.work[p].append(kings[pIndex])
        }
        for columnIndex in 0..<13 {
            if g.hard {
                g.state.work[columnIndex].append(deck.removeFirst() | CardUtils.FLIP_FLAG)
            }
            while g.state.work[columnIndex].count < 4 {
                g.state.work[columnIndex].append(deck.removeFirst())
            }
        }

        g.state.draw.cards = deck
    }

    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool) {
        if isRightClick {
            g.sendHome(type, outerIndex, innerIndex)
            g.select(.none)
            return
        }

        switch type {
        case .draw:
            g.standardDrawClick(allowRecycle: !g.state.hard)

        case .pile:
            g.select(.pile)

        case .foundation:
            g.standardFoundationClick(outerIndex)

        case .work:
            let src = g.getSelection()
            let sameWorkPile = g.state.selection.type == .work && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !sameWorkPile {
                // Moving into work
                if !g.state.work[outerIndex].isEmpty {
                    // Empty piles must stay empty
                    if CardUtils.validMove(src, g.state.work[outerIndex], [.descending]) {
                        g.state.work[outerIndex].append(contentsOf: src)
                        g.eatSelection()
                    }
                }

                g.select(.none)
            } else {
                // Selecting a fresh column
                let col = g.state.work[outerIndex]
                if col.count < 1 {
                    g.select(.none)
                } else {
                    g.select(type, outerIndex, col.count - 1)
                }
            }

        default:
            // Probably a background click, just forget the selection
            g.select(.none)
        }
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.state.draw.cards.isEmpty && g.state.pile.cards.isEmpty && g.workPileEmpty()
    }
}
