import Foundation

// Port of src/modes/yukon.js
struct YukonMode: GameMode {
    let id = "yukon"
    let name = "Yukon"
    let help = """
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Build columns down and in any other suit.

Any face up card in the tableau along with all other cards on top of it, \
may be moved to another column provided that the connecting cards folow \
the build rules.Spaces in columns are filled only with kings.

There is no redeal.

| HARD MODE:

Easy - Columns are built on any other suit.

Hard - Columns are built on alternating colors.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "none"),
            pile: PileState(show: 3),
            foundations: [CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE]
        )

        var deck = g.shuffled(Array(0..<52))
        g.state.work.append([deck.removeFirst()])
        for columnIndex in 1..<7 {
            var col: [Int] = []
            for _ in 0..<columnIndex {
                col.append(deck.removeFirst() | CardUtils.FLIP_FLAG)
            }
            for _ in 0..<5 {
                col.append(deck.removeFirst())
            }
            g.state.work.append(col)
        }

        g.state.draw.cards = []
    }

    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool) {
        if isRightClick {
            g.sendHome(type, outerIndex, innerIndex)
            g.select(.none)
            return
        }

        switch type {
        case .foundation:
            g.standardFoundationClick(outerIndex)

        case .work:
            let src = g.getSelection()
            let sameWorkPile = g.state.selection.type == .work && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !sameWorkPile {
                // Moving into work
                let validFlags: CardUtils.ValidMove
                if g.state.hard {
                    validFlags = [.descending, .alternatingColor, .emptyKingsOnly]
                } else {
                    validFlags = [.descending, .anyOtherSuit, .emptyKingsOnly]
                }
                if CardUtils.validMove(src, g.state.work[outerIndex], validFlags) {
                    g.state.work[outerIndex].append(contentsOf: src)
                    g.eatSelection()
                }

                g.select(.none)
            } else {
                // Selecting a fresh column
                let col = g.state.work[outerIndex]
                var innerIndex = innerIndex
                if col.count < 1 {
                    g.select(.none)
                    return
                }
                while innerIndex < col.count && (col[innerIndex] & CardUtils.FLIP_FLAG) != 0 {
                    // Don't select face down cards
                    innerIndex += 1
                }

                g.select(type, outerIndex, innerIndex)
            }

        default:
            // Probably a background click, just forget the selection
            g.select(.none)
        }
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.state.draw.cards.isEmpty && g.state.pile.cards.isEmpty && g.workPileEmpty()
    }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        faceUpStops(col)
    }
}
