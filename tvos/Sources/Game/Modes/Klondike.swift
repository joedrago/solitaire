import Foundation

// Port of src/modes/klondike.js
struct KlondikeMode: GameMode {
    let id = "klondike"
    let name = "Klondike"
    let help = """
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Cards are flipped 3 at a time to a waste pile. Columns are built down, in \
alternating colors. All packed cards in a column must be moved as a unit \
to other columns.

The topmost card of any column or the waste pile may be moved to a \
foundation. The top card of the waste pile may also be moved to a column \
if desired, thus making the card below it playable also.

Unlimited redeals are allowed.

| HARD MODE:

Easy - Cards are flipped 3 cards at a time with unlimited redeals.

Hard - Cards are flipped 1 card at a time with no redeals.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "top"),
            pile: PileState(show: g.hard ? 1 : 3),
            foundations: [CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE]
        )

        var deck = g.shuffled(Array(0..<52))
        for columnIndex in 0..<7 {
            var col: [Int] = []
            for _ in 0..<columnIndex {
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

                if g.state.selection.foundationOnly == true {
                    g.select(.none)
                    return
                }

                if CardUtils.validMove(src, g.state.work[outerIndex], [.descending, .alternatingColor, .emptyKingsOnly]) {
                    g.state.work[outerIndex].append(contentsOf: src)
                    g.eatSelection()
                }

                g.select(.none)
            } else {
                // Selecting a fresh column
                let col = g.state.work[outerIndex]
                let wasClickingLastCard = innerIndex == col.count - 1

                // "All packed cards in a column must be moved as a unit to other columns."
                var innerIndex = 0
                while innerIndex < col.count && (col[innerIndex] & CardUtils.FLIP_FLAG) != 0 {
                    // Don't select face down cards
                    innerIndex += 1
                }

                let stopIndex = innerIndex
                innerIndex = col.count - 1
                while innerIndex > stopIndex {
                    let lowerInfo = CardUtils.info(col[innerIndex])
                    let upperInfo = CardUtils.info(col[innerIndex - 1])
                    if lowerInfo.value != upperInfo.value - 1 {
                        break
                    }
                    innerIndex -= 1
                }

                let isClickingLastCard = innerIndex == col.count - 1

                if wasClickingLastCard && !isClickingLastCard {
                    g.select(type, outerIndex, col.count - 1)
                    g.state.selection.foundationOnly = true
                } else {
                    g.select(type, outerIndex, innerIndex)
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

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        runStops(col, matchingSuit: false)
    }
}
