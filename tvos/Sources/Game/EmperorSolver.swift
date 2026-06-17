import Foundation

// Fast winnability prover for Emperor (two decks, 8 foundations up-in-suit
// A->K). Tableau builds down in alternating color; empties take any card. Stock
// flips one card at a time to a waste pile (no redeal); the waste top may go to
// a column or a foundation. Easy moves any grabbed pile (only the bottom card's
// fit matters, Yukon-style); hard moves a single card at a time.
struct EmperorSolver {
    let hard: Bool

    struct State {
        var cols: [[UInt8]]
        var faceDown: [UInt8]
        var stock: [UInt8]      // index 0 is the next card drawn (engine removeFirst)
        var pile: [UInt8]       // waste; last element is the exposed top
        var found: [[UInt8]]    // per suit (0..3): sorted heights 1..13, at most 2 each
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
        let pile = gs.pile.cards.map { UInt8($0 & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)) }
        var found: [[UInt8]] = [[], [], [], []]
        for f in gs.foundations where f >= 0 {
            let v = f & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK)
            found[v / 13].append(UInt8(v % 13 + 1))
        }
        for s in 0..<4 { found[s].sort() }
        return State(cols: cols, faceDown: faceDown, stock: stock, pile: pile, found: found)
    }

    @inline(__always) private func usedSlots(_ s: State) -> Int {
        s.found[0].count + s.found[1].count + s.found[2].count + s.found[3].count
    }

    // Can a card (suit, rank) go home? Rank>0 needs a same-suit foundation whose
    // top is rank-1 (height == rank); an ace (rank 0) needs a free foundation.
    @inline(__always) private func canPlace(_ s: State, _ suit: Int, _ rank: Int) -> Bool {
        if rank == 0 { return usedSlots(s) < 8 }
        return s.found[suit].contains(UInt8(rank))
    }

    private func place(_ s: inout State, _ suit: Int, _ rank: Int) {
        if rank == 0 {
            s.found[suit].append(1)
        } else if let idx = s.found[suit].firstIndex(of: UInt8(rank)) {
            s.found[suit][idx] = UInt8(rank + 1)
        }
        s.found[suit].sort()
    }

    private func isWon(_ s: State) -> Bool {
        if !s.stock.isEmpty || !s.pile.isEmpty { return false }
        for c in s.cols where !c.isEmpty { return false }
        return true
    }

    // Remove the top of column i to a foundation; flip an exposed face-down card.
    private func sendTop(_ s: inout State, _ i: Int) {
        let c = s.cols[i].removeLast()
        place(&s, SC.suit(c), SC.rank(c))
        if s.cols[i].count == Int(s.faceDown[i]) && s.faceDown[i] > 0 { s.faceDown[i] -= 1 }
    }

    @inline(__always) private func fits(_ moving: UInt8, on dstTop: UInt8) -> Bool {
        SC.rank(moving) == SC.rank(dstTop) - 1 && SC.red(moving) != SC.red(dstTop)
    }

    private func children(_ s: State) -> [(Move, State)] {
        // Forced safe auto-play of aces/twos (see YukonSolver for why it's safe).
        if let last = s.pile.last, SC.rank(last) <= 1, canPlace(s, SC.suit(last), SC.rank(last)) {
            var n = s
            n.pile.removeLast()
            place(&n, SC.suit(last), SC.rank(last))
            return [(Move(kind: .wasteToFoundation, card: last), n)]
        }
        for i in 0..<s.cols.count where !s.cols[i].isEmpty {
            let t = s.cols[i].last!
            if SC.rank(t) <= 1 && canPlace(s, SC.suit(t), SC.rank(t)) {
                var n = s
                sendTop(&n, i)
                return [(Move(kind: .foundation, card: t, from: i), n)]
            }
        }

        var out: [(Move, State)] = []

        // Draw one card from stock to the waste.
        if !s.stock.isEmpty {
            var n = s
            n.pile.append(n.stock.removeFirst())
            out.append((Move(kind: .draw), n))
        }

        // Waste -> foundation (rank >= 2).
        if let t = s.pile.last, canPlace(s, SC.suit(t), SC.rank(t)) {
            var n = s
            n.pile.removeLast()
            place(&n, SC.suit(t), SC.rank(t))
            out.append((Move(kind: .wasteToFoundation, card: t), n))
        }

        // Column top -> foundation (rank >= 2).
        for i in 0..<s.cols.count where !s.cols[i].isEmpty {
            let t = s.cols[i].last!
            if canPlace(s, SC.suit(t), SC.rank(t)) {
                var n = s
                sendTop(&n, i)
                out.append((Move(kind: .foundation, card: t, from: i), n))
            }
        }

        // Waste -> column.
        if let t = s.pile.last {
            for k in 0..<s.cols.count {
                let dst = s.cols[k]
                if dst.isEmpty || fits(t, on: dst[dst.count - 1]) {
                    var n = s
                    n.pile.removeLast()
                    n.cols[k].append(t)
                    out.append((Move(kind: .wasteToCol, card: t, to: k), n))
                }
            }
        }

        // Column -> column. Easy grabs any face-up suffix; hard only the top card.
        for i in 0..<s.cols.count {
            let col = s.cols[i]
            if col.isEmpty { continue }
            let fd = Int(s.faceDown[i])
            let lo = hard ? col.count - 1 : fd
            for j in lo..<col.count {
                let g = col[j]
                for k in 0..<s.cols.count where k != i {
                    let dst = s.cols[k]
                    if dst.isEmpty {
                        if j == 0 { continue } // whole column to empty = relabel
                    } else if !fits(g, on: dst[dst.count - 1]) {
                        continue
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

    private func score(_ s: State) -> Int {
        var fd = 0, empties = 0, runs = 0
        var home = 0
        for su in 0..<4 { for h in s.found[su] { home += Int(h) } }
        for i in 0..<s.cols.count {
            fd += Int(s.faceDown[i])
            let col = s.cols[i]
            if col.isEmpty { empties += 1; continue }
            var j = col.count - 1
            while j > Int(s.faceDown[i]) {
                if fits(col[j], on: col[j - 1]) { j -= 1 } else { break }
            }
            runs += col.count - 1 - j
        }
        return home * 5 - fd * 5 + empties * 2 + runs - s.pile.count
    }

    // Best-first priority (higher expands sooner): state quality dominates, with
    // a gentle depth penalty so the search prefers progress over diving.
    private func priority(_ s: State, _ depth: Int) -> Int { score(s) * 4 - depth }

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
        for su in 0..<4 { h.combine(s.found[su]) }
        h.combine(s.stock)
        h.combine(s.pile)
        for k in keys { h.combine(k) }
        return h.finalize()
    }

    func solvable(_ initial: State, maxNodes: Int, deadline: Date) -> Bool {
        bestFirstSolve(initial, isWon: isWon, children: children, priority: priority, canon: canon,
                       maxNodes: maxNodes, deadline: deadline).won
    }

    func solveWithMoves(_ initial: State, maxNodes: Int, deadline: Date) -> (moves: [Move]?, nodes: Int) {
        bestFirstSolvePath(initial, isWon: isWon, children: children, priority: priority, canon: canon,
                           maxNodes: maxNodes, deadline: deadline)
    }
}
