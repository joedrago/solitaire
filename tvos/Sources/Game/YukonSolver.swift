import Foundation

// Fast winnability prover for Yukon (single deck, foundations up-in-suit A->K).
// Yukon's signature: ANY face-up card plus everything on top of it may move, as
// long as the bottom grabbed card connects to the destination — the cards riding
// on top need not form an ordered run. Columns have no identity, so canon sorts
// them. Empties take kings only. Easy builds on any other suit; hard builds on
// alternating color.
struct YukonSolver {
    let hard: Bool

    struct State {
        var cols: [[UInt8]]
        var faceDown: [UInt8]
        var found: [UInt8] // height per suit 0..13 (number of cards home)
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
        return State(cols: cols, faceDown: faceDown, found: [0, 0, 0, 0])
    }

    private func isWon(_ s: State) -> Bool {
        s.found[0] == 13 && s.found[1] == 13 && s.found[2] == 13 && s.found[3] == 13
    }

    // Remove the top card of column i to its foundation (the caller has checked
    // it belongs there); flips an exposed face-down card.
    private func sendTop(_ s: inout State, _ i: Int) {
        let c = s.cols[i].removeLast()
        s.found[SC.suit(c)] += 1
        if s.cols[i].count == Int(s.faceDown[i]) && s.faceDown[i] > 0 { s.faceDown[i] -= 1 }
    }

    private func children(_ s: State) -> [(Move, State)] {
        // Forced safe auto-play: aces and twos never help in the tableau (nothing
        // can stack on an ace; only an ace stacks on a two and aces always go
        // home), so sending one home can never lose a winnable game. Doing it as
        // a single forced child collapses a lot of pointless branching.
        for i in 0..<s.cols.count where !s.cols[i].isEmpty {
            let t = s.cols[i].last!
            let r = SC.rank(t)
            if r <= 1 && r == Int(s.found[SC.suit(t)]) {
                var n = s
                sendTop(&n, i)
                return [(Move(kind: .foundation, card: t, from: i), n)]
            }
        }

        var out: [(Move, State)] = []

        // Discretionary foundation moves (rank >= 2).
        for i in 0..<s.cols.count where !s.cols[i].isEmpty {
            let t = s.cols[i].last!
            if SC.rank(t) == Int(s.found[SC.suit(t)]) {
                var n = s
                sendTop(&n, i)
                out.append((Move(kind: .foundation, card: t, from: i), n))
            }
        }

        // Tableau moves: grab col[j...] onto another column.
        for i in 0..<s.cols.count {
            let col = s.cols[i]
            if col.isEmpty { continue }
            let fd = Int(s.faceDown[i])
            for j in fd..<col.count {
                let g = col[j]
                let gRank = SC.rank(g), gSuit = SC.suit(g), gRed = SC.red(g)
                for k in 0..<s.cols.count where k != i {
                    let dst = s.cols[k]
                    if dst.isEmpty {
                        if gRank != 12 { continue }      // empties take kings only
                        if j == 0 { continue }           // whole column to empty = relabel
                    } else {
                        let t = dst[dst.count - 1]
                        if SC.rank(t) != gRank + 1 { continue }
                        if hard { if SC.red(t) == gRed { continue } }   // alternating color
                        else { if SC.suit(t) == gSuit { continue } }     // any other suit
                    }
                    var n = s
                    n.cols[i].removeLast(col.count - j)
                    n.cols[k].append(contentsOf: col[j...])
                    if j == fd && fd > 0 { n.faceDown[i] = UInt8(fd - 1) }
                    out.append((Move(kind: .tableau, card: g, count: col.count - j, from: i, to: k), n))
                }
            }
        }
        return out
    }

    // Higher is better (explored first). Reward cards home and uncovering
    // face-down cards; mild credit for empties and exposed in-build runs.
    private func score(_ s: State) -> Int {
        var fd = 0, empties = 0, runs = 0
        let home = Int(s.found[0]) + Int(s.found[1]) + Int(s.found[2]) + Int(s.found[3])
        for i in 0..<s.cols.count {
            fd += Int(s.faceDown[i])
            let col = s.cols[i]
            if col.isEmpty { empties += 1; continue }
            var j = col.count - 1
            while j > Int(s.faceDown[i]) {
                let lo = col[j], hi = col[j - 1]
                let ok = SC.rank(lo) == SC.rank(hi) - 1 && (hard ? SC.red(lo) != SC.red(hi) : SC.suit(lo) != SC.suit(hi))
                if ok { j -= 1 } else { break }
            }
            runs += col.count - 1 - j
        }
        return home * 6 - fd * 7 + empties * 2 + runs
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
        keys.sort(by: SC.lexLess)
        var h = Hasher()
        for v in s.found { h.combine(v) }
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
