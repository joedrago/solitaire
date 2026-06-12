import Foundation

// Direct port of src/SolitaireGame.js. Holds the current mode + state, the
// undo stack, persistence, and the generic helpers the modes call into.
final class SolitaireGame {
    var state: GameState!
    var modeId: String = "klondike"
    var hard: Bool = false // toggle for the *next* game; state.hard is this game's
    var undoStack: [GameState] = []

    let modeOrder = ["baker", "eagle", "emperor", "freecell", "golf", "klondike", "scorpion", "spider", "spiderette", "yukon"]
    let modes: [String: GameMode] = [
        "baker": BakerMode(),
        "eagle": EagleMode(),
        "emperor": EmperorMode(),
        "freecell": FreecellMode(),
        "golf": GolfMode(),
        "klondike": KlondikeMode(),
        "scorpion": ScorpionMode(),
        "spider": SpiderMode(),
        "spiderette": SpideretteMode(),
        "yukon": YukonMode(),
    ]

    var mode: GameMode { modes[modeId] ?? modes["klondike"]! }

    init() {
        if !load() {
            newGame()
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Persistence (UserDefaults stands in for the web build's localStorage)

    private struct SavePayload: Codable {
        var mode: String
        var hard: Bool
        var state: GameState
    }

    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: "save"),
              let payload = try? JSONDecoder().decode(SavePayload.self, from: data),
              modes[payload.mode] != nil
        else {
            return false
        }
        modeId = payload.mode
        hard = payload.hard
        state = payload.state
        undoStack = []
        return true
    }

    func save() {
        let payload = SavePayload(mode: modeId, hard: hard, state: state)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: "save")
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Undo

    var canUndo: Bool { !undoStack.isEmpty }

    func pushUndo() {
        undoStack.append(state)
    }

    func undo() {
        if let prev = undoStack.popLast() {
            state = prev
            save()
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Generic input handlers

    func newGame(_ newMode: String? = nil) {
        if let newMode, modes[newMode] != nil {
            modeId = newMode
        }
        mode.newGame(self)
        undoStack = []
        save()
    }

    func click(_ type: SpotType, _ outerIndex: Int = 0, _ innerIndex: Int = 0, isRightClick: Bool = false) {
        let before = state!
        pushUndo()
        mode.click(self, type, outerIndex, innerIndex, isRightClick)
        // The web build snapshots every click, including pure selection
        // changes; on a remote that makes Undo feel broken (it "does
        // nothing" several times). Only keep snapshots of real board changes.
        if state.boardEquals(before) {
            _ = undoStack.popLast()
        }
        save()
    }

    func won() -> Bool {
        mode.won(self)
    }

    func lost() -> Bool {
        mode.lost(self)
    }

    // -----------------------------------------------------------------------------------------------
    // Generic helpers

    func findFoundationSuitIndex(_ raw: Int) -> Int {
        if state.foundations.isEmpty {
            return -1
        }

        // find a matching suit
        let srcInfo = CardUtils.info(raw)
        for (fIndex, f) in state.foundations.enumerated() where f >= 0 {
            let dstInfo = CardUtils.info(f)
            if srcInfo.suit == dstInfo.suit && (srcInfo.value == dstInfo.value + 1 || srcInfo.value == dstInfo.value - 12) {
                return fIndex
            }
        }

        // find a free slot
        for (fIndex, f) in state.foundations.enumerated() where f < 0 {
            return fIndex
        }

        return -1
    }

    func workPileEmpty() -> Bool {
        for work in state.work where !work.isEmpty {
            return false
        }
        return true
    }

    func reserveEmpty() -> Bool {
        guard let reserve = state.reserve else {
            return true
        }
        for col in reserve.cols where !col.isEmpty {
            return false
        }
        return true
    }

    func canAutoWin() -> Bool {
        if won() {
            return false
        }
        if state.foundations.isEmpty {
            return false
        }
        if !state.draw.cards.isEmpty {
            return false
        }
        if !state.pile.cards.isEmpty {
            return false
        }
        if let reserve = state.reserve {
            for col in reserve.cols where !col.isEmpty {
                return false
            }
        }
        for col in state.work {
            var last = 100
            for raw in col {
                if (raw & CardUtils.FLIP_FLAG) != 0 {
                    return false
                }
                let info = CardUtils.info(raw)
                if info.value > last {
                    return false
                }
                last = info.value
            }
        }
        return true
    }

    @discardableResult
    func sendHome(_ type: SpotType, _ outerIndex: Int, _ innerIndex: Int) -> Bool {
        var src: Int? = nil
        switch type {
        case .pile:
            if let last = state.pile.cards.last {
                src = last
            }
        case .reserve:
            if let reserve = state.reserve, reserve.cols.count > outerIndex, let last = reserve.cols[outerIndex].last {
                src = last
            }
        case .work:
            let srcCol = state.work[outerIndex]
            if innerIndex != srcCol.count - 1 {
                return false
            }
            if innerIndex >= 0 && innerIndex < srcCol.count {
                src = srcCol[innerIndex]
            }
        default:
            break
        }

        guard let src else {
            return false
        }

        let srcInfo = CardUtils.info(src)
        let dstIndex = findFoundationSuitIndex(src)
        if dstIndex >= 0 {
            var sendHome = false
            if state.foundations[dstIndex] >= 0 {
                let dstInfo = CardUtils.info(state.foundations[dstIndex])
                if srcInfo.value == dstInfo.value + 1 || srcInfo.value == dstInfo.value - 12 {
                    sendHome = true
                }
            } else {
                let foundationBase = state.foundationBase ?? 0 // Ace
                if srcInfo.value == foundationBase {
                    sendHome = true
                }
            }

            if sendHome {
                state.foundations[dstIndex] = src
                switch type {
                case .pile:
                    state.pile.cards.removeLast()
                case .reserve:
                    state.reserve?.cols[outerIndex].removeLast()
                case .work:
                    state.work[outerIndex].removeLast()
                    revealTopOfWork(outerIndex)
                default:
                    break
                }
                select(.none)
                return true
            }
        }
        return false
    }

    @discardableResult
    func sendAny() -> Bool {
        if !canAutoWin() {
            return false
        }
        for workIndex in 0..<state.work.count {
            let work = state.work[workIndex]
            if !work.isEmpty {
                if sendHome(.work, workIndex, work.count - 1) {
                    save()
                    return true
                }
            }
        }
        return false
    }

    // Reveal any face down card left on top of a work column
    func revealTopOfWork(_ outerIndex: Int) {
        let count = state.work[outerIndex].count
        if count > 0 {
            state.work[outerIndex][count - 1] = state.work[outerIndex][count - 1] & ~CardUtils.FLIP_FLAG
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Selection

    func select(_ type: SpotType, _ outerIndex: Int = 0, _ innerIndex: Int = 0) {
        var type = type
        var outerIndex = outerIndex
        var innerIndex = innerIndex
        if state.selection.type == type && state.selection.outerIndex == outerIndex && state.selection.innerIndex == innerIndex {
            // Toggle
            type = .none
            outerIndex = 0
            innerIndex = 0
        }

        state.selection = Selection(type: type, outerIndex: outerIndex, innerIndex: innerIndex)
    }

    func eatSelection() {
        switch state.selection.type {
        case .pile:
            state.pile.cards.removeLast()
        case .reserve:
            let outer = state.selection.outerIndex
            state.reserve?.cols[outer].removeLast()
        case .work:
            let outer = state.selection.outerIndex
            if state.selection.innerIndex >= 0 {
                while state.selection.innerIndex < state.work[outer].count {
                    state.work[outer].removeLast()
                }
            }
            revealTopOfWork(outer)
        default:
            break
        }
        select(.none)
    }

    func getSelection() -> [Int] {
        var selectedCards: [Int] = []
        switch state.selection.type {
        case .pile:
            if let last = state.pile.cards.last {
                selectedCards.append(last)
            }
        case .reserve:
            if let reserve = state.reserve {
                let col = reserve.cols[state.selection.outerIndex]
                if let last = col.last {
                    selectedCards.append(last)
                }
            }
        case .work:
            if state.selection.outerIndex >= 0 && state.selection.innerIndex >= 0 {
                let srcCol = state.work[state.selection.outerIndex]
                var index = state.selection.innerIndex
                while index < srcCol.count {
                    selectedCards.append(srcCol[index])
                    index += 1
                }
            }
        default:
            break
        }

        return selectedCards
    }

    // -----------------------------------------------------------------------------------------------
    // Shared mode helpers (the common draw/foundation click logic repeated in
    // most of the JS modes)

    // klondike/baker/freecell-style draw click: recycle the pile back into the
    // draw when allowed, otherwise flip `pile.show` cards onto the pile.
    // `useRedeals` is the eagle variant where recycles are counted.
    func standardDrawClick(allowRecycle: Bool, useRedeals: Bool = false) {
        if allowRecycle && state.draw.cards.isEmpty {
            if useRedeals {
                if (state.draw.redeals ?? 0) > 0 {
                    state.draw.redeals = (state.draw.redeals ?? 0) - 1
                    state.draw.cards = state.pile.cards
                    state.pile.cards = []
                }
            } else {
                state.draw.cards = state.pile.cards
                state.pile.cards = []
            }
        } else {
            var cardsToDraw = state.pile.show
            if cardsToDraw > state.draw.cards.count {
                cardsToDraw = state.draw.cards.count
            }
            for _ in 0..<cardsToDraw {
                state.pile.cards.append(state.draw.cards.removeFirst())
            }
        }
        select(.none)
    }

    // The "gauntlet of breaks" foundation click shared by klondike, baker,
    // emperor, freecell, yukon (base 0, no wrap) and eagle (foundationBase,
    // wrapping king to ace).
    func standardFoundationClick(_ outerIndex: Int, base: Int = 0, wrap: Bool = false) {
        let src = getSelection()
        gauntlet: while true {
            if src.count != 1 {
                break gauntlet
            }
            let srcInfo = CardUtils.info(src[0])
            if state.foundations[outerIndex] < 0 {
                // empty
                if srcInfo.value != base {
                    break gauntlet
                }
            } else {
                let dstInfo = CardUtils.info(state.foundations[outerIndex])
                if srcInfo.suit != dstInfo.suit {
                    break gauntlet
                }
                if srcInfo.value != dstInfo.value + 1 && !(wrap && srcInfo.value == dstInfo.value - 12) {
                    break gauntlet
                }
            }

            state.foundations[outerIndex] = src[0]
            eatSelection()
            break gauntlet
        }
        select(.none)
    }
}

// Concatenates `copies` copies of cards, tagging each repeat with COPY bits so
// duplicate cards stay distinguishable (see CardUtils.COPY_MASK).
func deckCopies(_ cards: [Int], _ copies: Int) -> [Int] {
    var deck: [Int] = []
    for copy in 0..<copies {
        deck.append(contentsOf: cards.map { $0 | (copy << CardUtils.COPY_SHIFT) })
    }
    return deck
}

func shuffled(_ array: [Int]) -> [Int] {
    var array = array
    for i in stride(from: array.count - 1, to: 0, by: -1) {
        let j = Int.random(in: 0...i)
        array.swapAt(i, j)
    }
    return array
}
