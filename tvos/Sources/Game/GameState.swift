import Foundation

// Direct port of the JS game state shape (the `this.state` object each mode
// builds in newGame). Codable so save/load and the undo stack can snapshot it.

enum SpotType: String, Codable {
    case none
    case background
    case draw
    case pile
    case reserve
    case foundation
    case work
}

struct Selection: Codable, Equatable {
    var type: SpotType = .none
    var outerIndex: Int = 0
    var innerIndex: Int = 0
    var foundationOnly: Bool? = nil
}

struct DrawState: Codable, Equatable {
    var pos: String // "top" | "middle" | "bottom" | "none"
    var redeals: Int? = nil
    var cards: [Int] = []
}

struct PileState: Codable, Equatable {
    var show: Int
    var cards: [Int] = []
}

struct ReserveState: Codable, Equatable {
    var pos: String // "top" | "middle"
    var cols: [[Int]]
}

struct GameState: Codable, Equatable {
    var hard: Bool
    var seed: Int? = nil
    var draw: DrawState
    var selection: Selection = Selection()
    var pile: PileState
    var foundations: [Int] = []
    var work: [[Int]] = []
    var reserve: ReserveState? = nil
    var foundationBase: Int? = nil
    var centerDisplay: String? = nil
    var timerStart: Double? = nil
    var timerEnd: Double? = nil
    var timerColor: String? = nil

    // Equality that ignores the selection, used to decide whether a click
    // actually changed the board (and therefore deserves an undo snapshot).
    func boardEquals(_ other: GameState) -> Bool {
        var a = self
        var b = other
        a.selection = Selection()
        b.selection = Selection()
        return a == b
    }
}
