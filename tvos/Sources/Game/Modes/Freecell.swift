import Foundation

// Port of src/modes/freecell.js
struct FreecellMode: GameMode {
    let id = "freecell"
    let name = "Freecell"
    let help = """
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Columns are built down in alternating colors. Cards on the bottom of a \
column can be moved to a cell to gain access to cards below it, but at a \
cost.

Cards that are descending and in suit may be moved all at once, but the \
max count of cards that can be moved at a single time is based on how \
many cells are free and how many columns are empty. You're always allowed \
to move a single card (1) plus an additional card for every free cell. \
This number is then doubled for every empty column.

The max count able to be moved is displayed between the cells and \
foundations for your convenience.

The topmost card of any column or cell may be moved to a foundation. Cards \
in a cell may also be moved to a foundation.

| HARD MODE:

Easy - There are four cells.

Hard - There are only two cells.
"""

    func newGame(_ g: SolitaireGame) {
        g.state = GameState(
            hard: g.hard,
            draw: DrawState(pos: "none"),
            pile: PileState(show: g.hard ? 1 : 3),
            foundations: [CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE, CardUtils.GUIDE],
            reserve: ReserveState(pos: "top", cols: [])
        )

        let cellCount = g.hard ? 2 : 4
        for _ in 0..<cellCount {
            g.state.reserve?.cols.append([])
        }

        var deck = shuffled(Array(0..<52))
        for columnIndex in 0..<8 {
            var col: [Int] = []
            let colCount = columnIndex < 4 ? 7 : 6
            for _ in 0..<colCount {
                col.append(deck.removeFirst())
            }
            g.state.work.append(col)
        }

        g.state.draw.cards = deck
        freecellUpdateCount(g)
    }

    @discardableResult
    func freecellUpdateCount(_ g: SolitaireGame) -> Int {
        var count = 1
        for col in g.state.reserve?.cols ?? [] where col.isEmpty {
            count += 1
        }

        for col in g.state.work where col.isEmpty {
            count *= 2
        }

        if count > 52 {
            count = 52
        }

        g.state.centerDisplay = "\(count)"
        return count
    }

    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool) {
        if isRightClick {
            g.sendHome(type, outerIndex, innerIndex)
            freecellUpdateCount(g)
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

        case .reserve:
            let src = g.getSelection()
            let srcIsDest = g.state.selection.type == .reserve && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !srcIsDest {
                // Moving into reserve
                if src.count == 1 && (g.state.reserve?.cols[outerIndex].isEmpty ?? false) {
                    g.state.reserve?.cols[outerIndex].append(src[0])
                    g.eatSelection()
                }
                g.select(.none)
            } else {
                // Selecting a reserve card
                let col = g.state.reserve?.cols[outerIndex] ?? []
                if !col.isEmpty {
                    g.select(.reserve, outerIndex, col.count - 1)
                } else {
                    g.select(.none)
                }
            }

        case .work:
            let src = g.getSelection()
            let srcIsDest = g.state.selection.type == .work && g.state.selection.outerIndex == outerIndex
            if !src.isEmpty && !srcIsDest {
                // Moving into work

                if g.state.selection.foundationOnly == true {
                    g.select(.none)
                    freecellUpdateCount(g)
                    return
                }

                if CardUtils.validMove(src, g.state.work[outerIndex], [.descending, .alternatingColor]) {
                    g.state.work[outerIndex].append(contentsOf: src)
                    g.eatSelection()
                }

                g.select(.none)
            } else {
                // Selecting a fresh column
                let col = g.state.work[outerIndex]

                let stopIndex = innerIndex
                var innerIndex = col.count - 1
                while innerIndex > stopIndex {
                    let lowerInfo = CardUtils.info(col[innerIndex])
                    let upperInfo = CardUtils.info(col[innerIndex - 1])
                    if lowerInfo.value != upperInfo.value - 1 || lowerInfo.red == upperInfo.red {
                        break
                    }
                    innerIndex -= 1
                }

                let maxCount = freecellUpdateCount(g)
                while col.count - innerIndex > maxCount {
                    innerIndex += 1
                }

                g.select(type, outerIndex, innerIndex)
            }

        default:
            // Probably a background click, just forget the selection
            g.select(.none)
        }

        freecellUpdateCount(g)
    }

    func won(_ g: SolitaireGame) -> Bool {
        g.workPileEmpty() && g.reserveEmpty()
    }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        // Stops are the cards of the tail run that could actually be picked
        // up: descending, alternating colors, capped by the freecell max-move
        // count.
        if col.isEmpty {
            return []
        }
        var start = col.count - 1
        while start > 0 {
            let lowerInfo = CardUtils.info(col[start])
            let upperInfo = CardUtils.info(col[start - 1])
            if lowerInfo.value != upperInfo.value - 1 || lowerInfo.red == upperInfo.red {
                break
            }
            start -= 1
        }
        let maxCount = freecellUpdateCount(g)
        while col.count - start > maxCount {
            start += 1
        }
        return Array(start...(col.count - 1))
    }
}
