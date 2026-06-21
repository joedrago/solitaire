import Foundation

// Port of src/modes/spiderette.js
struct SpideretteMode: GameMode {
    let id = "spiderette"
    let name = "Spiderette"
    let help = """
| GOAL:

Remove all cards from the tableau by building four sets of cards from king \
to ace regardless of suit. The completed sets are removed from the \
tableau immediately.

| PLAY:

Build columns down regardless of suit. Either the topmost card or all \
packed cards of a column may be moved to another column which meets the \
build requirements.

When play comes to a standstill (or sooner if desired), deal the next \
group of 7 cards, 1 to each column, then play again if possible. Spaces \
in columns may be filled with any available card or build.

There is no redeal.

| HARD MODE:

Easy - 2 cards are dealt face down to columns.

Hard - 3 cards are dealt face down to columns.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "bottom"),
            pile: PileState(show: 1),
            foundations: []
        )

        var deck = g.shuffled(Array(0..<52))
        let faceDownCount = g.hard ? 3 : 2
        for _ in 0..<7 {
            var col: [Int] = []
            for _ in 0..<faceDownCount {
                col.append(deck.removeFirst() | CardUtils.FLIP_FLAG)
            }
            col.append(deck.removeFirst())
            g.state.work.append(col)
        }

        g.state.draw.cards = deck
    }

    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool) {
        if isRightClick {
            return
        }

        switch type {
        case .draw:
            SpiderMode.dealRow(g)

        case .work:
            let src = g.getSelection()
            let sameWorkPile = g.state.selection.type == .work && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !sameWorkPile {
                // Moving into work
                if CardUtils.validMove(src, g.state.work[outerIndex], [.descending]) {
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
                if innerIndex != col.count - 1 {
                    innerIndex = 0
                }
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

                g.select(type, outerIndex, innerIndex)
            }

        default:
            // Probably a background click, just forget the selection
            g.select(.none)
        }

        SpiderMode.removeSets(g, requireMatchingSuit: false)
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.state.draw.cards.isEmpty && g.state.pile.cards.isEmpty && g.workPileEmpty()
    }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        runStops(col, matchingSuit: false)
    }
}
