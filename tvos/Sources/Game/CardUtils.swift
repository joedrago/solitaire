import Foundation

// Direct port of src/cardutils.js. Cards are raw Ints: 0..51 (suit = raw/13,
// value = raw%13), with FLIP_FLAG (1024) ORed in for face-down cards. Negative
// values are the special pseudo-cards (back/guide/reserve/dead/ready).
enum CardUtils {
    static let BACK = -1
    static let GUIDE = -2
    static let RESERVE = -3
    static let DEAD = -4
    static let READY = -5
    static let FLIP_FLAG = 1024

    // Multi-deck games tag each repeat copy of a card with these bits so every
    // physical card has a unique raw for its whole life. The tag is pure
    // identity: info() and rendering mask it off, game logic never sees it,
    // but it lets the board animate the copy that actually moved instead of
    // guessing by layout order (and flying cards between identical twins).
    // Two bits covers the worst case (easy Spider deals four copies per card).
    static let COPY_SHIFT = 11
    static let COPY_MASK = 3 << COPY_SHIFT

    struct Info {
        let value: Int
        let valueName: String
        let suit: Int
        let flip: Bool
        let red: Bool
    }

    static func info(_ rawIn: Int) -> Info {
        if rawIn < 0 {
            return Info(value: rawIn, valueName: "", suit: rawIn, flip: rawIn == BACK, red: false)
        }
        let flip = (rawIn & FLIP_FLAG) == FLIP_FLAG
        let raw = rawIn & ~(FLIP_FLAG | COPY_MASK)
        let suit = raw / 13
        let value = raw % 13

        let valueName: String
        switch value {
        case 0: valueName = "A"
        case 10: valueName = "J"
        case 11: valueName = "Q"
        case 12: valueName = "K"
        default: valueName = "\(value + 1)"
        }

        return Info(value: value, valueName: valueName, suit: suit, flip: flip, red: suit > 1)
    }

    struct ValidMove: OptionSet {
        let rawValue: Int
        static let descending = ValidMove(rawValue: 1 << 0)
        static let descendingWrap = ValidMove(rawValue: 1 << 1)
        static let alternatingColor = ValidMove(rawValue: 1 << 2)
        static let anyOtherSuit = ValidMove(rawValue: 1 << 3)
        static let matchingSuit = ValidMove(rawValue: 1 << 4)
        static let emptyKingsOnly = ValidMove(rawValue: 1 << 5)
        static let disallowStackingFoundationBase = ValidMove(rawValue: 1 << 6)
    }

    static func validMove(_ src: [Int], _ dst: [Int], _ flags: ValidMove, foundationBase: Int? = nil) -> Bool {
        let srcInfo = info(src[0])

        if dst.isEmpty {
            if flags.contains(.emptyKingsOnly) {
                return srcInfo.value == 12
            }
            return true
        }

        let dstInfo = info(dst[dst.count - 1])
        if flags.contains(.alternatingColor) && srcInfo.red == dstInfo.red {
            return false
        }
        if flags.contains(.matchingSuit) && srcInfo.suit != dstInfo.suit {
            return false
        }
        if flags.contains(.anyOtherSuit) && srcInfo.suit == dstInfo.suit {
            return false
        }
        if flags.contains(.descending) && srcInfo.value != dstInfo.value - 1 {
            return false
        }
        if flags.contains(.descendingWrap) && srcInfo.value != dstInfo.value - 1 && srcInfo.value != dstInfo.value + 12 {
            return false
        }
        if flags.contains(.disallowStackingFoundationBase) && dstInfo.value == foundationBase {
            return false
        }

        return true
    }

    static func now() -> Double {
        Date().timeIntervalSince1970 * 1000
    }
}

// Deterministic seeded RNG (mulberry32), mirroring src/cardutils.js makeRng. A
// "seed" is a human-friendly integer the player can read off the screen, scan
// from the QR code, or type back in; it fully determines the deal, so the same
// seed always deals the same game. hashSeed folds the seed so that nearby seeds
// (1000 vs 1001) still produce wildly different deals.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt32

    init(seed: Int) {
        state = SeededGenerator.hashSeed(seed)
    }

    static func hashSeed(_ seedInput: Int) -> UInt32 {
        let str = String(seedInput)
        var h: UInt32 = 1779033703 ^ UInt32(truncatingIfNeeded: str.count)
        for scalar in str.unicodeScalars {
            h = (h ^ scalar.value) &* 3432918353
            h = (h << 13) | (h >> 19)
        }
        h = (h ^ (h >> 16)) &* 2246822507
        h = (h ^ (h >> 13)) &* 3266489909
        return h ^ (h >> 16)
    }

    mutating func nextU32() -> UInt32 {
        state = state &+ 0x6D2B79F5
        var t = (state ^ (state >> 15)) &* (state | 1)
        t = (t &+ ((t ^ (t >> 7)) &* (t | 61))) ^ t
        return t ^ (t >> 14)
    }

    // Fisher-Yates needs an index in 0..<n. Plain modulo: the bias against
    // 2^32 for n <= 104 is ~10^-8, far below anything a shuffle could reveal.
    mutating func int(below n: Int) -> Int {
        Int(nextU32() % UInt32(n))
    }

    mutating func next() -> UInt64 {
        (UInt64(nextU32()) << 32) | UInt64(nextU32())
    }
}

// A fresh, unpredictable seed for a brand-new random game.
func randomSeed() -> Int {
    Int.random(in: 0..<1_000_000_000)
}
