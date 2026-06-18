import Foundation

// Shared helpers + search for the fast card-only solvers. Cards are UInt8: low
// 7 bits are the face value 0..51 (suit = v/13, rank = v%13, A=0..K=12), and
// bit 0x80 marks a face-down card. Two-deck games simply repeat values; the
// solver never needs to tell duplicates apart.
enum SC {
    static let DOWN: UInt8 = 0x80

    @inline(__always) static func rank(_ c: UInt8) -> Int { Int(c & 0x7f) % 13 }
    @inline(__always) static func suit(_ c: UInt8) -> Int { Int(c & 0x7f) / 13 }
    @inline(__always) static func red(_ c: UInt8) -> Bool { suit(c) > 1 }
    @inline(__always) static func isDown(_ c: UInt8) -> Bool { (c & DOWN) != 0 }
    @inline(__always) static func face(_ c: UInt8) -> UInt8 { c & 0x7f }

    static func from(_ raw: Int) -> UInt8 {
        let v = UInt8(raw & ~(CardUtils.FLIP_FLAG | CardUtils.COPY_MASK))
        return (raw & CardUtils.FLIP_FLAG) != 0 ? (v | DOWN) : v
    }

    @inline(__always) static func faceUpStart(_ col: [UInt8]) -> Int {
        var i = 0
        while i < col.count && isDown(col[i]) { i += 1 }
        return i
    }

    @inline(__always) static func flipTop(_ col: inout [UInt8]) {
        if let last = col.last, isDown(last) { col[col.count - 1] = last & 0x7f }
    }

    static func lexLess(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        let n = min(a.count, b.count)
        var i = 0
        while i < n { if a[i] != b[i] { return a[i] < b[i] }; i += 1 }
        return a.count < b.count
    }

    private static let rankNames = ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
    private static let suitNames = ["S", "C", "D", "H"] // 0,1 black; 2,3 red
    static func name(_ c: UInt8) -> String { rankNames[rank(c)] + suitNames[suit(c)] }
}

// A move, kept compact during search and formatted only when printing a
// solution (for the `solve` CLI tool). Indices are column indices unless noted.
struct Move {
    enum Kind { case tableau, foundation, wasteToFoundation, cell, cellToCol, wasteToCol, reserveToCol, stockDeal, stockFlip, draw, recycle }
    var kind: Kind
    var card: UInt8 = 0
    var count: Int = 1
    var from: Int = -1
    var to: Int = -1

    func describe() -> String {
        switch kind {
        case .tableau:
            let tail = count > 1 ? " (+\(count - 1) on top)" : ""
            return "col \(from) → col \(to): \(SC.name(card))\(tail)"
        case .foundation: return "col \(from) → foundation: \(SC.name(card))"
        case .wasteToFoundation: return "waste → foundation: \(SC.name(card))"
        case .cell: return "col \(from) → free cell: \(SC.name(card))"
        case .cellToCol: return "free cell → col \(to): \(SC.name(card))"
        case .wasteToCol: return "waste → col \(to): \(SC.name(card))"
        case .reserveToCol: return "reserve → col \(to): \(SC.name(card))"
        case .stockDeal: return "deal a row from the stock"
        case .stockFlip: return "flip stock → foundation: \(SC.name(card))"
        case .draw: return "draw from stock"
        case .recycle: return "recycle the waste pile"
        }
    }
}

// A bucketed priority queue for the beam searches below. Priorities index
// directly into fixed buckets, so push/pop are O(1) and — crucially — never sift
// the (heavy, array-backed) state payload the way a binary heap does. That ARC
// churn from sifting was what pinned the large-game node rate at ~14k/s.
//
// `bucketCount`/`bias` map the integer priority into [0, bucketCount); the bias
// centers the expected range so nothing clamps in practice. Ordering within a
// bucket is LIFO, which is fine for a heuristic search.
private struct BucketQueue<T> {
    private var buckets: [[(T, Int)]] // payload + priority
    private let bias: Int
    private(set) var count = 0
    private var hi = -1 // highest non-empty bucket
    private var lo: Int // lowest non-empty bucket (advanced while trimming)

    init(bucketCount: Int = 16384, bias: Int = 8192) {
        buckets = Array(repeating: [], count: bucketCount)
        self.bias = bias
        lo = bucketCount
    }

    @inline(__always) private func index(_ p: Int) -> Int {
        let i = p + bias
        if i < 0 { return 0 }
        if i >= buckets.count { return buckets.count - 1 }
        return i
    }

    mutating func push(_ priority: Int, _ value: T) {
        let i = index(priority)
        buckets[i].append((value, priority))
        count += 1
        if i > hi { hi = i }
        if i < lo { lo = i }
    }

    mutating func pop() -> T? {
        while hi >= 0 && buckets[hi].isEmpty { hi -= 1 }
        if hi < 0 { return nil }
        let v = buckets[hi].removeLast().0
        count -= 1
        return v
    }

    // Drop the lowest-priority states to keep the live frontier under `cap`
    // (turns the search into a beam). Never trims the top bucket.
    mutating func trim(to cap: Int) {
        while count > cap {
            while lo < buckets.count && buckets[lo].isEmpty { lo += 1 }
            if lo >= hi { break }
            count -= buckets[lo].count
            buckets[lo].removeAll(keepingCapacity: false)
            lo += 1
        }
    }
}

// Budgeted beam best-first search over the canonical state graph. `priority(
// state, depth)` returns higher for states to expand sooner — goal-directed, so
// it jumps to the most promising frontier state instead of diving like DFS
// (which blows up on the large foundation games). The frontier is capped to
// `frontierCap` states, bounding memory (a beam, hence incomplete — failing
// within budget/cap is a tolerable false negative). Bool-only and lean for the
// on-device winnable check.
func beamSolve<S>(
    _ initial: S,
    isWon: (S) -> Bool,
    children: (S) -> [(Move, S)],
    priority: (S, Int) -> Int,
    canon: (S) -> Int,
    maxNodes: Int,
    deadline: Date,
    frontierCap: Int
) -> (won: Bool, nodes: Int) {
    var visited = Set<Int>()
    var queue = BucketQueue<(S, Int)>() // (state, depth)
    queue.push(priority(initial, 0), (initial, 0))
    var nodes = 0
    while let (s, depth) = queue.pop() {
        if isWon(s) { return (true, nodes) }
        if !visited.insert(canon(s)).inserted { continue }
        nodes += 1
        if nodes >= maxNodes || Date() >= deadline { return (false, nodes) }
        for (_, c) in children(s) { queue.push(priority(c, depth + 1), (c, depth + 1)) }
        if queue.count > frontierCap { queue.trim(to: frontierCap) }
    }
    return (false, nodes)
}

// Beam variant that records the move path via a parent-pointer tree (one node
// per expanded state) so the CLI tools can print a solution.
func beamSolvePath<S>(
    _ initial: S,
    isWon: (S) -> Bool,
    children: (S) -> [(Move, S)],
    priority: (S, Int) -> Int,
    canon: (S) -> Int,
    maxNodes: Int,
    deadline: Date,
    frontierCap: Int
) -> (moves: [Move]?, nodes: Int) {
    var visited = Set<Int>()
    var tree: [(move: Move, parent: Int)] = []
    var queue = BucketQueue<(S, Int, Move?, Int)>() // (state, depth, incoming move, parent tree idx)
    queue.push(priority(initial, 0), (initial, 0, nil, -1))
    var nodes = 0

    func reconstruct(_ idx: Int) -> [Move] {
        var moves: [Move] = []
        var i = idx
        while i >= 0 { moves.append(tree[i].move); i = tree[i].parent }
        return moves.reversed()
    }

    while let (s, depth, inMove, parentIdx) = queue.pop() {
        if isWon(s) {
            if let inMove { return (reconstruct(parentIdx) + [inMove], nodes) }
            return ([], nodes)
        }
        if !visited.insert(canon(s)).inserted { continue }
        nodes += 1
        if nodes >= maxNodes || Date() >= deadline { return (nil, nodes) }
        let myIdx: Int
        if let inMove { myIdx = tree.count; tree.append((inMove, parentIdx)) } else { myIdx = -1 }
        for (m, c) in children(s) { queue.push(priority(c, depth + 1), (c, depth + 1, m, myIdx)) }
        if queue.count > frontierCap { queue.trim(to: frontierCap) }
    }
    return (nil, nodes)
}

// Budgeted DFS, transposition table, greedy child ordering (best explored
// first). Bool-only and lean — used for the on-device winnable check. Failing
// within budget is reported as not-winnable (a tolerable false negative).
func dfsSolve<S>(
    _ initial: S,
    isWon: (S) -> Bool,
    children: (S) -> [(Move, S)],
    score: (S) -> Int,
    canon: (S) -> Int,
    maxNodes: Int,
    deadline: Date
) -> (won: Bool, nodes: Int) {
    var visited = Set<Int>()
    var stack = [initial]
    var nodes = 0
    while let s = stack.popLast() {
        if isWon(s) { return (true, nodes) }
        if !visited.insert(canon(s)).inserted { continue }
        nodes += 1
        if nodes >= maxNodes || Date() >= deadline { return (false, nodes) }
        var kids = children(s)
        kids.sort { score($0.1) < score($1.1) }
        for k in kids { stack.append(k.1) }
    }
    return (false, nodes)
}

// Same search, but records the move path so the CLI tool can print a solution.
// Memory is bounded to one node per *expanded* state via a parent-pointer tree
// (no per-stack-entry path copies), so deep, wide trees like Emperor's stay in
// memory. The winning path is reconstructed by walking parents.
func dfsSolvePath<S>(
    _ initial: S,
    isWon: (S) -> Bool,
    children: (S) -> [(Move, S)],
    score: (S) -> Int,
    canon: (S) -> Int,
    maxNodes: Int,
    deadline: Date
) -> (moves: [Move]?, nodes: Int) {
    var visited = Set<Int>()
    var tree: [(move: Move, parent: Int)] = [] // one entry per expanded node
    var stack: [(S, Move?, Int)] = [(initial, nil, -1)] // (state, incoming move, parent tree idx)
    var nodes = 0

    func reconstruct(_ idx: Int) -> [Move] {
        var moves: [Move] = []
        var i = idx
        while i >= 0 { moves.append(tree[i].move); i = tree[i].parent }
        return moves.reversed()
    }

    while let (s, inMove, parentIdx) = stack.popLast() {
        if isWon(s) {
            if let inMove { return (reconstruct(parentIdx) + [inMove], nodes) }
            return ([], nodes)
        }
        if !visited.insert(canon(s)).inserted { continue }
        nodes += 1
        if nodes >= maxNodes || Date() >= deadline { return (nil, nodes) }
        let myIdx: Int
        if let inMove { myIdx = tree.count; tree.append((inMove, parentIdx)) } else { myIdx = -1 }
        var kids = children(s)
        kids.sort { score($0.1) < score($1.1) }
        for (m, c) in kids { stack.append((c, m, myIdx)) }
    }
    return (nil, nodes)
}
