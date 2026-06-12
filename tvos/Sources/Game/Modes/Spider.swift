import Foundation

// Port of src/modes/spider.js
struct SpiderMode: GameMode {
    let id = "spider"
    let name = "Spider"
    let help = """
| GOAL:

Remove all 104 cards from the tableau by building eight sets of cards in \
suit from king to ace. The completed sets are removed from the tableau \
immediately.

| PLAY:

Build columns down regardless of suit. Either the topmost card or all \
packed cards of the same suit may be moved to another column which meets \
the build requirements.

When play comes to a standstill (or sooner if desired), deal the next \
group of 10 cards, 1 to each column, then play again if possible. Spaces \
in columns may be filled with any available card or build.

There is no redeal.

| HARD MODE:

Easy - Only two suits are represented (52 hearts, 52 spades).

Hard - Two full decks are used (all four suits). Very hard!
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "bottom"),
            pile: PileState(show: 1),
            foundations: []
        )

        var deck: [Int]
        if g.hard {
            deck = shuffled(deckCopies(Array(0..<52), 2))
        } else {
            let blacks: [Int] = Array(0...12) // spades
            let reds: [Int] = Array(39...51) // hearts
            deck = shuffled(deckCopies(reds + blacks, 4))
        }
        for _ in 0..<10 {
            var col: [Int] = []
            for _ in 0..<4 {
                col.append(deck.removeFirst() | CardUtils.FLIP_FLAG)
            }
            col.append(deck.removeFirst())
            g.state.work.append(col)
        }

        g.state.draw.cards = deck
    }

    // Removes any complete king-to-ace same-suit runs from the tableau.
    static func removeSets(_ g: SolitaireGame, requireMatchingSuit: Bool) {
        while true {
            var foundOne = false
            for workIndex in 0..<g.state.work.count {
                let work = g.state.work[workIndex]
                if work.count < 13 {
                    // optimization: this can't have a full set in it
                    continue
                }

                var kingPos = -1
                var kingSuit = -1
                for (rawIndex, raw) in work.enumerated() {
                    let info = CardUtils.info(raw)
                    if kingPos >= 0 {
                        if info.value != 12 - rawIndex + kingPos || (requireMatchingSuit && info.suit != kingSuit) {
                            kingPos = -1
                            kingSuit = -1
                        }
                    }

                    if kingPos < 0 {
                        if info.value == 12 && !info.flip {
                            kingPos = rawIndex
                            kingSuit = info.suit
                        }
                    }

                    if kingPos >= 0 && rawIndex - kingPos == 12 {
                        foundOne = true
                        g.state.work[workIndex].removeSubrange(kingPos...(kingPos + 12))
                        g.revealTopOfWork(workIndex)
                        break
                    }
                }
            }

            if !foundOne {
                break
            }
        }
    }

    // Deals one card from the draw to each column.
    static func dealRow(_ g: SolitaireGame) {
        for workIndex in 0..<g.state.work.count {
            if g.state.draw.cards.isEmpty {
                break
            }
            g.state.work[workIndex].append(g.state.draw.cards.removeLast())
        }

        g.select(.none)
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
                    if lowerInfo.value != upperInfo.value - 1 || lowerInfo.suit != upperInfo.suit {
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

        SpiderMode.removeSets(g, requireMatchingSuit: true)
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.state.draw.cards.isEmpty && g.state.pile.cards.isEmpty && g.workPileEmpty()
    }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        runStops(col, matchingSuit: true)
    }
}
