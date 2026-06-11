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
        let raw = rawIn & ~FLIP_FLAG
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
