import Foundation

// Port of src/modes/golf.js
struct GolfMode: GameMode {
    let id = "golf"
    let name = "Golf"
    let help = """
| GOAL:

Move all cards from the tableau into the foundation pile as fast as possible.

| PLAY:

Choose any card from a column to start the single foundation. Build the foundation pile up OR \
down regardless of suit, including wrapping (Aces can stack on Kings and vice versa). Any card \
completely exposed may be built on the foundation.

When play comes to a standstill, flip 1 card from the stock to the foundation, then continue if \
possible. Repeat until no cards remain in the stock.

There is no redeal.

| HARD MODE:

Easy - 7 columns of 5 cards each.

Hard - 6 columns of 6 cards each.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "middle"),
            pile: PileState(show: 1),
            foundations: []
        )
        g.state.timerStart = nil
        g.state.timerEnd = nil
        g.state.timerColor = "#fff"

        var deck = shuffled(Array(0..<52))

        let columnCount = g.hard ? 6 : 7
        let cardCount = g.hard ? 6 : 5
        for _ in 0..<columnCount {
            var col: [Int] = []
            for _ in 0..<cardCount {
                col.append(deck.removeFirst())
            }
            g.state.work.append(col)
        }

        g.state.draw.cards = deck
    }

    func golfCanPlay(_ g: SolitaireGame, _ raw: Int) -> Bool {
        if g.state.pile.cards.isEmpty {
            return true
        }
        let srcInfo = CardUtils.info(raw)
        let dstInfo = CardUtils.info(g.state.pile.cards[g.state.pile.cards.count - 1])
        if abs(srcInfo.value - dstInfo.value) == 1 {
            return true
        }
        if abs(srcInfo.value - dstInfo.value) == 12 {
            // Wrapping
            return true
        }
        return false
    }

    func golfHasPlays(_ g: SolitaireGame) -> Bool {
        for col in g.state.work {
            if let last = col.last, golfCanPlay(g, last) {
                return true
            }
        }
        return false
    }

    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool) {
        g.select(.none)

        let pileWasEmpty = g.state.pile.cards.isEmpty

        switch type {
        case .draw:
            if !g.state.draw.cards.isEmpty {
                g.state.pile.cards.append(g.state.draw.cards.removeFirst())
            }

        case .work:
            if let last = g.state.work[outerIndex].last {
                if golfCanPlay(g, last) {
                    g.state.pile.cards.append(g.state.work[outerIndex].removeLast())
                }
            }

        default:
            break
        }

        if pileWasEmpty && !g.state.pile.cards.isEmpty {
            g.state.timerStart = CardUtils.now()
        } else if g.state.timerEnd == nil {
            if g.workPileEmpty() {
                g.state.timerEnd = CardUtils.now()
                g.state.timerColor = "#3f3"
            } else if g.state.draw.cards.isEmpty && !golfHasPlays(g) {
                g.state.timerEnd = CardUtils.now()
                g.state.timerColor = "#ff0"
            }
        }
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.workPileEmpty()
    }

    func lost(_ g: SolitaireGame) -> Bool {
        g.state.timerEnd != nil && !g.workPileEmpty()
    }
}
