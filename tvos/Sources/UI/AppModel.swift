import SwiftUI

// Display brightness preference. Off is the original look; Dim and Inverted
// both darken the felt/cursor/text and differ only in how the cards are tinted.
enum DarkMode: Int {
    case off = 0
    case dim = 1
    case inverted = 2

    var label: String {
        switch self {
        case .off: return "Off"
        case .dim: return "Dim"
        case .inverted: return "Inverted"
        }
    }

    var next: DarkMode {
        DarkMode(rawValue: (rawValue + 1) % 3) ?? .off
    }

    // Whether the dark surfaces (felt, cursor, text) are in effect.
    var isDark: Bool { self != .off }

    var cardTreatment: CardTreatment {
        switch self {
        case .off: return .identity
        case .dim: return .dim
        case .inverted: return .inverted
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    let game = SolitaireGame()

    // Bumped after every game mutation so SwiftUI re-renders (GameState lives
    // inside the SolitaireGame reference type and isn't directly observable).
    @Published private(set) var version = 0

    @Published var cursor: Cursor = .top(0)
    @Published var overlay: Overlay = .none
    @Published var menuIndex = 0

    // Pure display preference (separate from the game save): dims the felt,
    // card faces, and cursor for play in a dark room. Tri-state, cycled from
    // the menu.
    @Published var darkMode: DarkMode = DarkMode(rawValue: UserDefaults.standard.integer(forKey: "darkMode")) ?? .off {
        didSet { UserDefaults.standard.set(darkMode.rawValue, forKey: "darkMode") }
    }

    enum Overlay: Equatable {
        case none
        case menu
        case help
        case win
        case lose
    }

    private var toastShown = false
    private var autowinTimer: Timer?

    init() {
        toastShown = game.won() || game.lost()
        resetCursor()
    }

    private func refresh() {
        version += 1
    }

    private func resetCursor() {
        if game.state.draw.pos == "top" {
            cursor = .top(0)
        } else {
            let nav = NavModel.build(game)
            cursor = .work(col: 0, stopIdx: max(0, nav.workStops.first.map { $0.count - 1 } ?? 0))
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Cursor

    func cursorSpot(_ nav: NavModel) -> Spot? {
        switch cursor {
        case .top(let i):
            return nav.top.indices.contains(i) ? nav.top[i].spot : nil
        case .work(let col, let stopIdx):
            guard nav.workStops.indices.contains(col) else { return nil }
            let stops = nav.workStops[col]
            guard stops.indices.contains(stopIdx) else { return nil }
            return Spot(.work, col, stops[stopIdx])
        case .bottom(let i):
            return nav.bottom.indices.contains(i) ? nav.bottom[i].spot : nil
        }
    }

    private func clampCursor(_ nav: NavModel) {
        switch cursor {
        case .top(let i):
            if nav.top.isEmpty {
                cursor = .work(col: 0, stopIdx: nav.workStops[0].count - 1)
            } else if i >= nav.top.count {
                cursor = .top(nav.top.count - 1)
            }
        case .work(let col, let stopIdx):
            let c = min(max(col, 0), nav.workStops.count - 1)
            let s = min(max(stopIdx, 0), nav.workStops[c].count - 1)
            cursor = .work(col: c, stopIdx: s)
        case .bottom(let i):
            if nav.bottom.isEmpty {
                cursor = .work(col: 0, stopIdx: nav.workStops[0].count - 1)
            } else if i >= nav.bottom.count {
                cursor = .bottom(nav.bottom.count - 1)
            }
        }
    }

    private func cursorX(_ nav: NavModel) -> Double {
        switch cursor {
        case .top(let i):
            return nav.top.indices.contains(i) ? nav.top[i].x : 0
        case .work(let col, _):
            return Double(col)
        case .bottom(let i):
            return nav.bottom.indices.contains(i) ? nav.bottom[i].x : 0
        }
    }

    private func moveCursor(_ dir: Direction, isRepeat: Bool) {
        let nav = NavModel.build(game)
        clampCursor(nav)
        let x = cursorX(nav)
        // Wrap around an edge only on a deliberate press; a held repeat pulse
        // stops dead at the edge so auto-repeat never runs off the end.
        let wrap = !isRepeat

        switch dir {
        case .left, .right:
            let delta = dir == .right ? 1 : -1
            switch cursor {
            case .top(let i):
                cursor = .top(Self.step(i, delta, nav.top.count, wrap: wrap))
            case .work(let col, _):
                let c = Self.step(col, delta, nav.workStops.count, wrap: wrap)
                cursor = .work(col: c, stopIdx: nav.workStops[c].count - 1)
            case .bottom(let i):
                cursor = .bottom(Self.step(i, delta, nav.bottom.count, wrap: wrap))
            }

        case .up:
            switch cursor {
            case .top:
                // Top of the vertical cycle: a press wraps to the bottom-most row.
                if wrap { wrapToBottomEnd(nav, x: x) }
            case .work(let col, let stopIdx):
                if stopIdx > 0 {
                    cursor = .work(col: col, stopIdx: stopIdx - 1)
                } else if let i = nav.nearestIndex(in: nav.top, toX: x) {
                    cursor = .top(i)
                } else if wrap {
                    // No top row above this column; wrap to the bottom end.
                    wrapToBottomEnd(nav, x: x)
                }
            case .bottom:
                let c = nav.nearestWorkColumn(toX: x)
                cursor = .work(col: c, stopIdx: nav.workStops[c].count - 1)
            }

        case .down:
            switch cursor {
            case .top:
                let c = nav.nearestWorkColumn(toX: x)
                // Entering from the top, start at the highest stop so a column
                // of choices is walked downward naturally.
                cursor = .work(col: c, stopIdx: 0)
            case .work(let col, let stopIdx):
                if stopIdx < nav.workStops[col].count - 1 {
                    cursor = .work(col: col, stopIdx: stopIdx + 1)
                } else if let i = nav.nearestIndex(in: nav.bottom, toX: x) {
                    cursor = .bottom(i)
                } else if wrap {
                    // No bottom row below this column; wrap to the top end.
                    wrapToTopEnd(nav, x: x)
                }
            case .bottom:
                // Bottom of the vertical cycle: a press wraps to the top-most row.
                if wrap { wrapToTopEnd(nav, x: x) }
            }
        }
    }

    // Index step with optional edge wrap. With wrap off, the index clamps at
    // the ends instead of cycling.
    private static func step(_ i: Int, _ delta: Int, _ count: Int, wrap: Bool) -> Int {
        guard count > 0 else { return 0 }
        let n = i + delta
        if n < 0 { return wrap ? count - 1 : 0 }
        if n >= count { return wrap ? 0 : count - 1 }
        return n
    }

    // Jump to the bottom-most vertical position nearest x: the bottom row if
    // there is one, otherwise the deepest stop of the nearest work column.
    private func wrapToBottomEnd(_ nav: NavModel, x: Double) {
        if let i = nav.nearestIndex(in: nav.bottom, toX: x) {
            cursor = .bottom(i)
        } else {
            let c = nav.nearestWorkColumn(toX: x)
            cursor = .work(col: c, stopIdx: nav.workStops[c].count - 1)
        }
    }

    // Jump to the top-most vertical position nearest x: the top row if there
    // is one, otherwise the first stop of the nearest work column.
    private func wrapToTopEnd(_ nav: NavModel, x: Double) {
        if let i = nav.nearestIndex(in: nav.top, toX: x) {
            cursor = .top(i)
        } else {
            let c = nav.nearestWorkColumn(toX: x)
            cursor = .work(col: c, stopIdx: 0)
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Remote input entry points

    func onDirection(_ dir: Direction, isRepeat: Bool) {
        switch overlay {
        case .none:
            moveCursor(dir, isRepeat: isRepeat)
        case .menu:
            let items = menuItems()
            if dir == .up {
                menuIndex = max(0, menuIndex - 1)
            } else if dir == .down {
                menuIndex = min(items.count - 1, menuIndex + 1)
            }
        case .help, .win, .lose:
            break
        }
    }

    func onSelect() {
        switch overlay {
        case .none:
            activateCursor(isRightClick: false)
        case .menu:
            activateMenuItem()
        case .help:
            overlay = .none
        case .win, .lose:
            overlay = .none
            game.newGame()
            afterNewGame()
        }
    }

    func onSelectLong() {
        switch overlay {
        case .none:
            // Long press = the web build's right-click: send the card home.
            activateCursor(isRightClick: true)
        default:
            onSelect()
        }
    }

    func onPlayPause() {
        stopAutowin()
        switch overlay {
        case .menu:
            overlay = .none
        case .none, .help, .win, .lose:
            menuIndex = 0
            overlay = .menu
        }
        refresh()
    }

    // Back is always handled in-app — stop autowin, close an overlay, clear a
    // selection, or open the menu. The Home button still suspends to tvOS.
    func menuWantsCapture() -> Bool {
        return true
    }

    func onMenu() {
        if autowinTimer != nil {
            stopAutowin()
            refresh()
            return
        }
        switch overlay {
        case .none:
            if game.state.selection.type != .none {
                // Clear the selection, like a background click.
                game.click(.background)
            } else {
                // Nothing selected: open the menu.
                menuIndex = 0
                overlay = .menu
            }
            refresh()
        case .menu, .help, .win, .lose:
            overlay = .none
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Actions

    private func activateCursor(isRightClick: Bool) {
        let nav = NavModel.build(game)
        clampCursor(nav)
        guard let spot = cursorSpot(nav) else {
            return
        }
        game.click(spot.type, spot.outer, spot.inner, isRightClick: isRightClick)
        afterAction()
    }

    private func afterAction() {
        let nav = NavModel.build(game)
        clampCursor(nav)
        checkToasts()
        refresh()
    }

    private func afterNewGame() {
        toastShown = false
        stopAutowin()
        resetCursor()
        refresh()
    }

    private func checkToasts() {
        if toastShown {
            return
        }
        if game.won() {
            overlay = .win
            toastShown = true
            stopAutowin()
        } else if game.lost() {
            overlay = .lose
            toastShown = true
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Menu

    struct MenuEntry: Identifiable {
        let id: String
        let label: String
        let enabled: Bool
        let action: () -> Void
    }

    func menuItems() -> [MenuEntry] {
        var items: [MenuEntry] = []

        items.append(MenuEntry(id: "undo", label: "Undo", enabled: game.canUndo) { [weak self] in
            guard let self else { return }
            self.game.undo()
            // Stay in the menu so the player can keep undoing (like Dark Mode,
            // this is a repeatable in-menu action).
            self.afterAction()
        })

        if game.canAutoWin() {
            items.append(MenuEntry(id: "autowin", label: "Auto-Finish", enabled: true) { [weak self] in
                guard let self else { return }
                self.overlay = .none
                self.startAutowin()
            })
        }

        items.append(MenuEntry(id: "help", label: "Rule Help: \(game.mode.name)", enabled: true) { [weak self] in
            self?.overlay = .help
        })

        items.append(MenuEntry(id: "hard", label: "Hard Mode (next game): \(game.hard ? "On" : "Off")", enabled: true) { [weak self] in
            guard let self else { return }
            self.game.hard.toggle()
            self.game.save()
            self.refresh()
        })

        items.append(MenuEntry(id: "dark", label: "Dark Mode: \(darkMode.label)", enabled: true) { [weak self] in
            guard let self else { return }
            self.darkMode = self.darkMode.next
            self.refresh()
        })

        items.append(MenuEntry(id: "again", label: "Play Again: \(game.mode.name)", enabled: true) { [weak self] in
            guard let self else { return }
            self.overlay = .none
            self.game.newGame()
            self.afterNewGame()
        })

        for modeId in game.modeOrder {
            guard let mode = game.modes[modeId] else { continue }
            items.append(MenuEntry(id: "new_\(modeId)", label: "New Game: \(mode.name)", enabled: true) { [weak self] in
                guard let self else { return }
                self.overlay = .none
                self.game.newGame(modeId)
                self.afterNewGame()
            })
        }

        return items
    }

    private func activateMenuItem() {
        let items = menuItems()
        guard items.indices.contains(menuIndex) else {
            return
        }
        let item = items[menuIndex]
        if item.enabled {
            item.action()
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Autowin

    var autowinRunning: Bool { autowinTimer != nil }

    private func startAutowin() {
        stopAutowin()
        autowinTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if !self.game.sendAny() {
                    self.stopAutowin()
                }
                self.afterAction()
            }
        }
        refresh()
    }

    private func stopAutowin() {
        autowinTimer?.invalidate()
        autowinTimer = nil
    }
}
