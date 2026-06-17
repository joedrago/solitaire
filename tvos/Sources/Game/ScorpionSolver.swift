import Foundation

// Fast winnability prover for Scorpion (see SolverCore for the model). Columns
// are cards bottom->top; face-down cards are the leading `faceDown` count (they
// are always at the bottom in Scorpion). Once the stock is dealt the seven
// columns are interchangeable, so canonHash sorts them and collapses the
// symmetry that made a naive search hopeless.
struct ScorpionSolver {
    let hard: Bool

    struct State {
        var cols: [[UInt8]]
        var faceDown: [UInt8]
        var stock: [UInt8]
        var stockDealt: Bool
    }

    static func from(_ gs: GameState) -> State {
        var cols: [[UInt8]] = []
        var faceDown: [UInt8] = []
        for col in gs.work {
            var cards: [UInt8] = []
            var fd: UInt8 = 0
            var leading = true
            for raw in col {
                if (raw & CardUtils.FLIP_FLAG) != 0, leading { fd += 1 } else { leading = false }
                cards.append(UInt8(raw & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)))
            }
            cols.append(cards)
            faceDown.append(fd)
        }
        let stock = gs.draw.cards.map { UInt8($0 & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)) }
        return State(cols: cols, faceDown: faceDown, stock: stock, stockDealt: stock.isEmpty)
    }

    private func isWon(_ s: State) -> Bool {
        if !s.stockDealt { return false }
        for (i, col) in s.cols.enumerated() {
            if col.isEmpty { continue }
            if s.faceDown[i] != 0 || col.count != 13 { return false }
            let suit0 = SC.suit(col[0])
            for (j, c) in col.enumerated() where SC.suit(c) != suit0 || SC.rank(c) != 12 - j {
                return false
            }
        }
        return true
    }

    private func children(_ s: State) -> [(Move, State)] {
        var out: [(Move, State)] = []

        if !s.stockDealt && s.stock.count == 3 {
            var n = s
            // The real engine deals via removeLast(): col 0 gets the last stock
            // card, col 1 the middle, col 2 the first. Mirror that order exactly
            // or the planned post-deal layout won't match the actual game.
            for i in 0..<3 { n.cols[i].append(s.stock[s.stock.count - 1 - i]) }
            n.stock = []
            n.stockDealt = true
            out.append((Move(kind: .stockDeal), n))
        }

        for i in 0..<s.cols.count {
            let col = s.cols[i]
            if col.isEmpty { continue }
            let fd = Int(s.faceDown[i])
            for j in fd..<col.count {
                let grabbed = col[j]
                let gRank = SC.rank(grabbed), gSuit = SC.suit(grabbed)
                for k in 0..<s.cols.count where k != i {
                    let dst = s.cols[k]
                    if dst.isEmpty {
                        if hard && gRank != 12 { continue }
                        if j == 0 { continue } // whole-column-to-empty is a pure relabel
                    } else {
                        let t = dst[dst.count - 1]
                        if SC.suit(t) != gSuit || SC.rank(t) != gRank + 1 { continue }
                    }
                    var n = s
                    n.cols[i].removeLast(col.count - j)
                    n.cols[k].append(contentsOf: col[j...])
                    if j == fd && fd > 0 { n.faceDown[i] = UInt8(fd - 1) }
                    out.append((Move(kind: .tableau, card: grabbed, count: col.count - j, from: i, to: k), n))
                }
            }
        }
        return out
    }

    private func score(_ s: State) -> Int {
        var fd = 0, runs = 0, empties = 0
        for i in 0..<s.cols.count {
            fd += Int(s.faceDown[i])
            let col = s.cols[i]
            if col.isEmpty { empties += 1; continue }
            var j = col.count - 1
            while j > Int(s.faceDown[i]) {
                if SC.rank(col[j]) == SC.rank(col[j - 1]) - 1 && SC.suit(col[j]) == SC.suit(col[j - 1]) { j -= 1 } else { break }
            }
            runs += col.count - j
        }
        return -fd * 8 + runs * 3 + empties * 5
    }

    private func canon(_ s: State) -> Int {
        var keys: [[UInt8]] = []
        keys.reserveCapacity(s.cols.count)
        for i in 0..<s.cols.count {
            var k = s.cols[i]
            k.append(255)
            k.append(s.faceDown[i])
            keys.append(k)
        }
        if s.stockDealt { keys.sort(by: SC.lexLess) }
        var h = Hasher()
        h.combine(s.stockDealt)
        for k in keys { h.combine(k) }
        return h.finalize()
    }

    func solvable(_ initial: State, maxNodes: Int, deadline: Date) -> Bool {
        dfsSolve(initial, isWon: isWon, children: children, score: score, canon: canon,
                 maxNodes: maxNodes, deadline: deadline).won
    }

    func solveWithMoves(_ initial: State, maxNodes: Int, deadline: Date) -> (moves: [Move]?, nodes: Int) {
        dfsSolvePath(initial, isWon: isWon, children: children, score: score, canon: canon,
                     maxNodes: maxNodes, deadline: deadline)
    }
}
