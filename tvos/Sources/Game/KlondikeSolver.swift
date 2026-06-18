import Foundation

// Fast winnability prover for Klondike (single deck, foundations up-in-suit
// A->K). Stock flips to a waste pile; tableau builds down in alternating color,
// empties take kings. Big state space (stock+waste+foundations) so it uses the
// beam search.
//
// Engine quirks this mirrors exactly (see KlondikeMode.click): the movable unit
// from a column is the maximal *descending-by-value* run from the top (color is
// NOT checked for grouping); only the run's bottom card is checked against the
// destination (descending + alternating color, or a king onto an empty column).
// Easy deals 3 at a time with unlimited redeals (recycle waste -> stock in
// order); hard deals 1 at a time with no redeal.
struct KlondikeSolver {
    let hard: Bool
    private var drawCount: Int { hard ? 1 : 3 }

    struct State {
        var cols: [[UInt8]]
        var faceDown: [UInt8]
        var found: [UInt8]   // height per suit 0..13
        var stock: [UInt8]   // index 0 is the next card drawn (engine removeFirst)
        var waste: [UInt8]   // last element is the exposed top
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
        var found: [UInt8] = [0, 0, 0, 0]
        for f in gs.foundations where f >= 0 {
            let v = f & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)
            found[v / 13] = UInt8(v % 13 + 1)
        }
        let stock = gs.draw.cards.map { UInt8($0 & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)) }
        let waste = gs.pile.cards.map { UInt8($0 & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)) }
        return State(cols: cols, faceDown: faceDown, found: found, stock: stock, waste: waste)
    }

    private func isWon(_ s: State) -> Bool {
        s.found[0] == 13 && s.found[1] == 13 && s.found[2] == 13 && s.found[3] == 13
    }

    private func sendTop(_ s: inout State, _ i: Int) {
        let c = s.cols[i].removeLast()
        s.found[SC.suit(c)] += 1
        if s.cols[i].count == Int(s.faceDown[i]) && s.faceDown[i] > 0 { s.faceDown[i] -= 1 }
    }

    // Start index of the maximal descending-by-value run at the top of column i.
    @inline(__always) private func runStart(_ col: [UInt8], _ fd: Int) -> Int {
        var rs = col.count - 1
        while rs > fd && SC.rank(col[rs - 1]) == SC.rank(col[rs]) + 1 { rs -= 1 }
        return rs
    }

    private func children(_ s: State) -> [(Move, State)] {
        // Forced safe auto-play of aces/twos (see YukonSolver for why it's safe).
        if let t = s.waste.last, SC.rank(t) <= 1, SC.rank(t) == Int(s.found[SC.suit(t)]) {
            var n = s
            n.waste.removeLast()
            n.found[SC.suit(t)] += 1
            return [(Move(kind: .wasteToFoundation, card: t), n)]
        }
        for i in 0..<s.cols.count where !s.cols[i].isEmpty {
            let t = s.cols[i].last!
            if SC.rank(t) <= 1 && SC.rank(t) == Int(s.found[SC.suit(t)]) {
                var n = s
                sendTop(&n, i)
                return [(Move(kind: .foundation, card: t, from: i), n)]
            }
        }

        var out: [(Move, State)] = []
        var firstEmpty = -1
        for k in 0..<s.cols.count where s.cols[k].isEmpty { firstEmpty = k; break }

        // Waste / column tops -> foundation (rank >= 2).
        if let t = s.waste.last, SC.rank(t) == Int(s.found[SC.suit(t)]) {
            var n = s
            n.waste.removeLast()
            n.found[SC.suit(t)] += 1
            out.append((Move(kind: .wasteToFoundation, card: t), n))
        }
        for i in 0..<s.cols.count where !s.cols[i].isEmpty {
            let t = s.cols[i].last!
            if SC.rank(t) == Int(s.found[SC.suit(t)]) {
                var n = s
                sendTop(&n, i)
                out.append((Move(kind: .foundation, card: t, from: i), n))
            }
        }

        // Waste top -> column.
        if let t = s.waste.last {
            let tr = SC.rank(t), tred = SC.red(t)
            for k in 0..<s.cols.count {
                let dst = s.cols[k]
                if dst.isEmpty {
                    if k != firstEmpty || tr != 12 { continue }
                } else {
                    let d = dst[dst.count - 1]
                    if SC.rank(d) != tr + 1 || SC.red(d) == tred { continue }
                }
                var n = s
                n.waste.removeLast()
                n.cols[k].append(t)
                out.append((Move(kind: .wasteToCol, card: t, to: k), n))
            }
        }

        // Column maximal-run -> column.
        for i in 0..<s.cols.count {
            let col = s.cols[i]
            if col.isEmpty { continue }
            let fd = Int(s.faceDown[i])
            let rs = runStart(col, fd)
            let bottom = col[rs]
            let br = SC.rank(bottom), bred = SC.red(bottom)
            for k in 0..<s.cols.count where k != i {
                let dst = s.cols[k]
                if dst.isEmpty {
                    if k != firstEmpty { continue }
                    if br != 12 { continue }   // empties take kings only
                    if rs == 0 { continue }    // whole column to empty = relabel
                } else {
                    let d = dst[dst.count - 1]
                    if SC.rank(d) != br + 1 || SC.red(d) == bred { continue }
                }
                var n = s
                n.cols[i].removeLast(col.count - rs)
                n.cols[k].append(contentsOf: col[rs...])
                if rs == fd && fd > 0 { n.faceDown[i] = UInt8(fd - 1) }
                out.append((Move(kind: .tableau, card: bottom, count: col.count - rs, from: i, to: k), n))
            }
        }

        // Draw, or recycle the waste when the stock is empty (easy only).
        if !s.stock.isEmpty {
            var n = s
            let d = min(drawCount, n.stock.count)
            for _ in 0..<d { n.waste.append(n.stock.removeFirst()) }
            out.append((Move(kind: .draw), n))
        } else if !hard && !s.waste.isEmpty {
            var n = s
            n.stock = n.waste
            n.waste = []
            out.append((Move(kind: .recycle), n))
        }
        return out
    }

    private func score(_ s: State) -> Int {
        var fd = 0, empties = 0, runs = 0
        let home = Int(s.found[0]) + Int(s.found[1]) + Int(s.found[2]) + Int(s.found[3])
        for i in 0..<s.cols.count {
            fd += Int(s.faceDown[i])
            let col = s.cols[i]
            if col.isEmpty { empties += 1; continue }
            var j = col.count - 1
            while j > Int(s.faceDown[i]) && SC.rank(col[j - 1]) == SC.rank(col[j]) + 1 { j -= 1 }
            runs += col.count - 1 - j
        }
        return home * 6 - fd * 5 + empties * 3 + runs
    }

    private func priority(_ s: State, _ depth: Int) -> Int { score(s) * 4 - depth }

    // Order-independent over columns, allocation-free (runs per node).
    private func canon(_ s: State) -> Int {
        var colMix: UInt64 = 0
        for i in 0..<s.cols.count {
            var ch: UInt64 = 1469598103934665603
            for c in s.cols[i] { ch = (ch ^ UInt64(c)) &* 1099511628211 }
            ch = (ch ^ UInt64(s.faceDown[i])) &* 1099511628211
            colMix = colMix &+ (ch | 1)
        }
        var h: UInt64 = colMix &* 1099511628211
        for v in s.found { h = (h ^ UInt64(v)) &* 1099511628211 }
        for c in s.stock { h = (h ^ UInt64(c)) &* 1099511628211 }
        h = h &* 1099511628211
        for c in s.waste { h = (h ^ UInt64(c)) &* 1099511628211 }
        return Int(bitPattern: UInt(truncatingIfNeeded: h))
    }

    private let frontierCap = 300_000

    func solvable(_ initial: State, maxNodes: Int, deadline: Date) -> Bool {
        beamSolve(initial, isWon: isWon, children: children, priority: priority, canon: canon,
                  maxNodes: maxNodes, deadline: deadline, frontierCap: frontierCap).won
    }

    func solveWithMoves(_ initial: State, maxNodes: Int, deadline: Date) -> (moves: [Move]?, nodes: Int) {
        beamSolvePath(initial, isWon: isWon, children: children, priority: priority, canon: canon,
                      maxNodes: maxNodes, deadline: deadline, frontierCap: frontierCap)
    }
}
