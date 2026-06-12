import Foundation

// The remote-navigable structure of the board. Spots are arranged in three
// logical rows:
//
//   top    — draw/pile (when at the top), top reserve cells, foundations
//   work   — the work columns; up/down can also walk cards within a column
//   bottom — draw/pile/reserve positioned "middle" or "bottom"
//
// Left/right moves within a row; up/down moves between rows (entering the
// row's nearest spot by x) or, inside a work column, between cursor stops.
// All x coordinates are in card-height units, matching BoardGeometry.

enum Direction {
    case up, down, left, right
}

struct NavSpot {
    let spot: Spot
    let x: Double
    // If set, this bottom-row spot is vertically tied to that work column:
    // only that column reaches it with up/down, so other columns' vertical
    // movement stays within themselves.
    var column: Int? = nil
}

struct NavModel {
    var top: [NavSpot] = []
    var bottom: [NavSpot] = []

    // Per work column: the inner indices the cursor can rest on, ascending.
    // An empty column gets a single -1 stop (its guide card).
    var workStops: [[Int]] = []

    static func build(_ game: SolitaireGame) -> NavModel {
        let state = game.state!
        let mode = game.mode
        var nav = NavModel()

        let maxWidth = Double(state.work.count) // see BoardGeometry: maxWidth == work count for every mode

        // The mode's pile is only worth visiting when clicking it does
        // something (golf's pile is a display-only foundation).
        let pileInteractive = !(mode is GolfMode)

        if state.draw.pos == "top" {
            nav.top.append(NavSpot(spot: Spot(.draw), x: 0))
            if pileInteractive {
                nav.top.append(NavSpot(spot: Spot(.pile), x: 1))
            }
        }
        if let reserve = state.reserve, reserve.pos == "top" {
            for i in reserve.cols.indices {
                nav.top.append(NavSpot(spot: Spot(.reserve, i), x: Double(i)))
            }
        }
        let foundationOffsetL = Double(state.work.count - state.foundations.count)
        for i in state.foundations.indices {
            nav.top.append(NavSpot(spot: Spot(.foundation, i), x: foundationOffsetL + Double(i)))
        }
        nav.top.sort { $0.x < $1.x }

        if state.draw.pos == "middle" {
            if state.reserve?.pos == "middle" {
                nav.bottom.append(NavSpot(spot: Spot(.draw), x: 1))
                if pileInteractive {
                    nav.bottom.append(NavSpot(spot: Spot(.pile), x: 2))
                }
            } else {
                nav.bottom.append(NavSpot(spot: Spot(.draw), x: maxWidth / 2 - 1))
                if pileInteractive {
                    nav.bottom.append(NavSpot(spot: Spot(.pile), x: maxWidth / 2))
                }
            }
        } else if state.draw.pos == "bottom" {
            // Stock is tied under column 0. Skip it entirely when empty (these
            // modes have no redeal) so it can't be targeted.
            if !state.draw.cards.isEmpty {
                nav.bottom.append(NavSpot(spot: Spot(.draw), x: 0, column: 0))
            }
        }
        if let reserve = state.reserve, reserve.pos == "middle" {
            for i in reserve.cols.indices {
                nav.bottom.append(NavSpot(spot: Spot(.reserve, i), x: maxWidth / 2 - 0.5 + Double(i)))
            }
        }
        nav.bottom.sort { $0.x < $1.x }

        // While a selection is held, columns act as plain drop targets — no
        // point walking individual cards.
        let selectionActive = state.selection.type != .none
        for col in state.work {
            if col.isEmpty {
                nav.workStops.append([-1])
            } else if selectionActive {
                nav.workStops.append([col.count - 1])
            } else {
                let stops = mode.cursorStops(game, col)
                nav.workStops.append(stops.isEmpty ? [col.count - 1] : stops)
            }
        }

        return nav
    }

    func nearestIndex(in row: [NavSpot], toX x: Double) -> Int? {
        guard !row.isEmpty else { return nil }
        var best = 0
        var bestDist = Double.greatestFiniteMagnitude
        for (i, navSpot) in row.enumerated() {
            let d = abs(navSpot.x - x)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    // The bottom spot a work column should bridge to with up/down: a spot tied
    // to this column if there is one, otherwise the nearest untied spot (the
    // shared draw/pile/reserve of middle-layout modes). A spot tied to a
    // *different* column is never returned, keeping its column's chain private.
    func bottomTarget(forColumn col: Int) -> Int? {
        if let i = bottom.firstIndex(where: { $0.column == col }) {
            return i
        }
        return freeBottomNearest(toX: Double(col))
    }

    // Nearest bottom spot that isn't tied to a specific column.
    func freeBottomNearest(toX x: Double) -> Int? {
        var best: Int?
        var bestDist = Double.greatestFiniteMagnitude
        for (i, navSpot) in bottom.enumerated() where navSpot.column == nil {
            let d = abs(navSpot.x - x)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }

    func nearestWorkColumn(toX x: Double) -> Int {
        guard !workStops.isEmpty else { return 0 }
        var best = 0
        var bestDist = Double.greatestFiniteMagnitude
        for i in workStops.indices {
            let d = abs(Double(i) - x)
            if d < bestDist {
                bestDist = d
                best = i
            }
        }
        return best
    }
}

// Where the cursor is, in terms of the nav rows.
enum Cursor: Equatable {
    case top(Int)
    case work(col: Int, stopIdx: Int)
    case bottom(Int)
}
