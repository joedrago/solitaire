import Foundation

// Port of src/modes/eagle.js
struct EagleMode: GameMode {
    let id = "eagle"
    let name = "Eagle Wing"
    let help = """
| GOAL:

Build the foundations up, in suit, from the rank of the first card played in the foundation, \
untill all cards of the suit have been played, wrapping from king to ace as necessary.

| PLAY:

The reserve is dealt 14 cards to begin with. Empty spaces in columns are filled automatically \
from the reserve. If there are no cards left in the reserve, empty spaces of columns can be \
filled with any available card.

Build columns down and in suit, wrapping as necessary. There is a 3 card maximum for colums. \
Cards from the reserve, waste pile, and packed cards from other columns may be moved to a column.

There is one redeal.

| HARD MODE:

Easy - 14 cards in the reserve pile.

Hard - 17 cards in the reserve pile.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "middle", redeals: 1),
            pile: PileState(show: 1),
            foundations: [CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE],
            reserve: ReserveState(pos: "middle", cols: [[]])
        )

        var deck = shuffled(Array(0..<52))

        for _ in 0..<8 {
            g.state.work.append([deck.removeFirst()])
        }

        let reserveCount = g.hard ? 17 : 14
        for _ in 0..<reserveCount {
            g.state.reserve?.cols[0].append(deck.removeFirst())
        }

        g.state.foundations[0] = deck.removeFirst()
        let foundationInfo = CardUtils.info(g.state.foundations[0])
        g.state.foundationBase = foundationInfo.value
        g.state.centerDisplay = foundationInfo.valueName
        g.state.draw.cards = deck
    }

    func eagleDealReserve(_ g: SolitaireGame) {
        for workIndex in 0..<g.state.work.count {
            if (g.state.reserve?.cols[0].count ?? 0) < 1 {
                break
            }
            if g.state.work[workIndex].isEmpty {
                if let card = g.state.reserve?.cols[0].popLast() {
                    g.state.work[workIndex].append(card)
                }
            }
        }
    }

    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool) {
        if isRightClick {
            g.sendHome(type, outerIndex, innerIndex)
            eagleDealReserve(g)
            g.select(.none)
            return
        }

        switch type {
        case .draw:
            g.standardDrawClick(allowRecycle: !g.state.hard, useRedeals: true)

        case .pile:
            g.select(.pile)

        case .reserve:
            g.select(.reserve, 0, (g.state.reserve?.cols[0].count ?? 0) - 1)

        case .foundation:
            g.standardFoundationClick(outerIndex, base: g.state.foundationBase ?? 0, wrap: true)

        case .work:
            let src = g.getSelection()
            let sameWorkPile = g.state.selection.type == .work && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !sameWorkPile {
                // Moving into work

                if g.state.selection.foundationOnly == true {
                    g.select(.none)
                    eagleDealReserve(g)
                    return
                }

                let dst = g.state.work[outerIndex]
                if dst.count + src.count <= 3 {
                    // Eagle Wing has a pile max of 3
                    if dst.isEmpty
                        || CardUtils.validMove(
                            src, dst,
                            [.descendingWrap, .matchingSuit, .disallowStackingFoundationBase],
                            foundationBase: g.state.foundationBase
                        )
                    {
                        g.state.work[outerIndex].append(contentsOf: src)
                        g.eatSelection()
                    }
                }

                g.select(.none)
            } else {
                // Selecting a fresh column
                let col = g.state.work[outerIndex]
                let wasClickingLastCard = innerIndex == col.count - 1

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

        eagleDealReserve(g)
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.state.draw.cards.isEmpty && g.state.pile.cards.isEmpty
            && (g.state.reserve?.cols[0].isEmpty ?? true) && g.workPileEmpty()
    }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        runStops(col, matchingSuit: false)
    }
}
