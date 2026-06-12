import Foundation

// Port of src/modes/emperor.js
struct EmperorMode: GameMode {
    let id = "emperor"
    let name = "Emperor"
    let help = """
| GOAL:

Build the foundations up in suit from ace to king (2 decks).

| PLAY:

Cards are flipped 1 at a time to a waste pile. Columns are built down, in \
alternating colors.

The topmost card of any column or the waste pile may be moved to a \
foundation. The top card of the waste pile may also be moved to a column \
if desired, thus making the card below it playable also. Spaces in \
columns may be filled with any card.

No redeals.

| HARD MODE:

Easy - Any number of packed cards may be moved together. (modern rules)

Hard - Only one card may be moved at a time. (original rules)
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "top", redeals: 0),
            pile: PileState(show: 1),
            foundations: Array(repeating: CardUtils.GUIDE, count: 8)
        )

        var deck = shuffled(deckCopies(Array(0..<52), 2))
        for _ in 0..<10 {
            var col: [Int] = []
            for _ in 0..<3 {
                col.append(deck.removeFirst() | CardUtils.FLIP_FLAG)
            }
            col.append(deck.removeFirst())
            g.state.work.append(col)
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
            if !g.state.draw.cards.isEmpty {
                g.standardDrawClick(allowRecycle: false)
            } else {
                g.select(.none)
            }

        case .pile:
            g.select(.pile)

        case .foundation:
            g.standardFoundationClick(outerIndex)

        case .work:
            let src = g.getSelection()
            let sameWorkPile = g.state.selection.type == .work && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !sameWorkPile {
                // Moving into work
                if CardUtils.validMove(src, g.state.work[outerIndex], [.descending, .alternatingColor]) {
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
                } else if g.state.hard {
                    innerIndex = col.count - 1
                } else {
                    while innerIndex < col.count && (col[innerIndex] & CardUtils.FLIP_FLAG) != 0 {
                        // Don't select face down cards
                        innerIndex += 1
                    }
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
        if g.state.hard {
            return col.isEmpty ? [] : [col.count - 1]
        }
        return faceUpStops(col)
    }
}
