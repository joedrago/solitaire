import Foundation

// Port of src/modes/scorpion.js
struct ScorpionMode: GameMode {
    let id = "scorpion"
    let name = "Scorpion"
    let help = """
| GOAL:

Arrange four sets of cards in suit, from, king down to ace.

| PLAY:

Build columns down and in suit. Any face up card may be moved, along \
with all other cards on top of it, to a completely exposed card which \
meets the build requirements. Flip face down cards which become exposed \
face up.

When play comes to a standstill (or sooner if desired), deal the three \
remaining cards of the stock to the first three columns, then continue if \
possible. Empty spaces in columns may be filled with any cards.

There is no redeal.

| HARD MODE:

Easy - 2 cards face down in the first 4 columns. Fill empties with any cards.

Hard - 3 cards face down in the first 4 columns. Fill empties with Kings only.
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
        let faceUpCount = g.hard ? 4 : 5
        for columnIndex in 0..<7 {
            var col: [Int] = []
            if columnIndex < 4 {
                for _ in 0..<faceDownCount {
                    col.append(deck.removeFirst() | CardUtils.FLIP_FLAG)
                }
                for _ in 0..<faceUpCount {
                    col.append(deck.removeFirst())
                }
            } else {
                for _ in 0..<7 {
                    col.append(deck.removeFirst())
                }
            }
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
                var validFlags: CardUtils.ValidMove = [.descending, .matchingSuit]
                if g.state.hard {
                    validFlags.insert(.emptyKingsOnly)
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
        if !g.state.draw.cards.isEmpty {
            return false
        }

        // each work must either be empty or have a perfect 13 card run of same-suit in it
        for work in g.state.work {
            if work.isEmpty {
                continue
            }
            if work.count != 13 {
                return false
            }
            for (cIndex, c) in work.enumerated() {
                let info = CardUtils.info(c)
                if info.flip {
                    return false
                }
                if info.value != 12 - cIndex {
                    return false
                }
            }
        }
        return true
    }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        faceUpStops(col)
    }
}
