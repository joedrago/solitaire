import SwiftUI

// Display brightness preference. Off is the original look; Dim and Candlelight
// both darken the felt/cursor/text and differ only in how the cards are tinted.
enum DarkMode: Int {
    case off = 0
    case dim = 1
    case candlelight = 2

    var label: String {
        switch self {
        case .off: return "Off"
        case .dim: return "Dim"
        case .candlelight: return "Candlelight"
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
        case .candlelight: return .candlelight
        }
    }
}

// Card-back deck color. Each case selects a pre-colorized variant of the back
// art (generated offline from the desaturated master, which Gray shows as-is).
enum DeckColor: Int {
    case green = 0
    case red = 1
    case blue = 2
    case purple = 3
    case gray = 4

    var label: String {
        switch self {
        case .green: return "Green"
        case .red: return "Red"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .gray: return "Gray"
        }
    }

    var next: DeckColor {
        DeckColor(rawValue: (rawValue + 1) % 5) ?? .green
    }

    var imageName: String {
        switch self {
        case .green: return "cardBackGreen"
        case .red: return "cardBackRed"
        case .blue: return "cardBackBlue"
        case .purple: return "cardBackPurple"
        case .gray: return "cardBack"
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
    @Published var menuPage: MenuPage = .main

    // When on, the board gently highlights every card the current mode says can
    // be picked up and moved somewhere new. Turned on from the menu, and turned
    // off again the instant the next real move is made (see activateCursor).
    @Published var hintsActive = false

    // Cached QR image of the current seed (regenerated only when the seed
    // changes, not every render). Shown beneath the game label.
    @Published private(set) var seedQR: Image? = nil
    private var seedQRSeed: Int? = nil

    // Set by RemoteInput: presents the tvOS system keyboard to type a seed,
    // calling back with the entered seed (or nil if cancelled). Lives here so
    // the menu action can reach the UIKit presentation layer.
    var presentSeedEntry: ((Int, @escaping (Int?) -> Void) -> Void)?

    // Pure display preference (separate from the game save): dims the felt,
    // card faces, and cursor for play in a dark room. Tri-state, cycled from
    // the menu.
    @Published var darkMode: DarkMode = DarkMode(rawValue: UserDefaults.standard.integer(forKey: "darkMode")) ?? .off {
        didSet { UserDefaults.standard.set(darkMode.rawValue, forKey: "darkMode") }
    }

    // Deck color for the card backs, also display-only and menu-cycled.
    @Published var deckColor: DeckColor = DeckColor(rawValue: UserDefaults.standard.integer(forKey: "deckColor")) ?? .green {
        didSet { UserDefaults.standard.set(deckColor.rawValue, forKey: "deckColor") }
    }

    // When on, a new *random* game keeps re-dealing seeds until the solver
    // proves one winnable (shown behind a "Shuffling…" overlay). A typed seed
    // or "Start Over" is always honored as-is — this only governs fresh deals.
    @Published var winnableOnly: Bool = UserDefaults.standard.bool(forKey: "winnableOnly") {
        didSet { UserDefaults.standard.set(winnableOnly, forKey: "winnableOnly") }
    }

    // Modes with a fast on-device solver wired up. Others deal normally even
    // with the toggle on. Grows as each game's solver lands.
    private let winnableSupported: Set<String> = ["scorpion", "yukon", "emperor", "klondike"]

    // Per-mode seed-search budgets for "Winnable only". The small/cheap games
    // (Scorpion, Yukon — single-deck DFS) solve in a few thousand nodes, so a
    // big cap is free. Emperor's 2-deck beam search is far heavier: a *small*
    // per-seed node cap is the key — most winnable deals are found in well under
    // 80k nodes, so capping there rejects hard deals cheaply and lets the
    // generator try many more seeds in the window (measured ~0.85-0.95 hit rate
    // within 25-30s even at 5-9x the Apple TV slowdown).
    private func winnableBudget(_ mode: String) -> (nodes: Int, perSeedSecs: Double, totalSecs: Double) {
        switch mode {
        case "emperor": return (80_000, 12, 30)
        case "klondike": return (200_000, 6, 25) // single-deck beam, ~400k nodes/s — small cap keeps per-seed time tiny
        default: return (2_000_000, 3, 25)
        }
    }

    enum Overlay: Equatable {
        case none
        case menu
        case help
        case win
        case lose
        case shuffling // searching seeds for a winnable deal
    }

    // Which page the menu overlay is showing: the main actions, or the
    // Choose Game list of modes.
    enum MenuPage: Equatable {
        case main
        case chooseGame
    }

    private var toastShown = false
    private var autowinTimer: Timer?

    // Double-tapping a card is an alias for the long-press "send home" (a common
    // instinct). We remember the spot and time of the last plain select tap so a
    // quick second tap on the *same* card can stand in for the long press.
    private var lastSelectSpot: Spot? = nil
    private var lastSelectTime: Double = 0
    private static let doubleTapWindowMs: Double = 450

    init() {
        toastShown = game.won() || game.lost()
        resetCursor()
        refreshSeedQR()
    }

    private func refresh() {
        version += 1
    }

    // Rebuild the seed QR only when the seed actually changed (cheap guard so
    // it isn't regenerated on every cursor move / animation tick).
    private func refreshSeedQR() {
        if seedQRSeed != game.seed {
            // "SOL" prefix so a scanning phone reads it as text, not a phone
            // number. SolitaireGame.parseSeed strips it back off on entry.
            seedQR = QRCode.image("SOL\(game.seed)")
            seedQRSeed = game.seed
        }
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

    // The source cards an active hint highlights, as render-layer Spots. Empty
    // unless a hint is showing (and the mode supports hints at all).
    func hintSpots() -> Set<Spot> {
        guard hintsActive, game.mode.supportsHints else {
            return []
        }
        return Set(game.mode.hints(game).map { Spot($0.type, $0.outer, $0.inner) })
    }

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
                if wrap { wrapToBottomEnd(nav, x: x, column: nil) }
            case .work(let col, let stopIdx):
                if stopIdx > 0 {
                    cursor = .work(col: col, stopIdx: stopIdx - 1)
                } else if let i = nav.nearestIndex(in: nav.top, toX: x) {
                    cursor = .top(i)
                } else if wrap {
                    // No top row above this column; wrap to the bottom end.
                    wrapToBottomEnd(nav, x: x, column: col)
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
                } else if let i = nav.bottomTarget(forColumn: col) {
                    cursor = .bottom(i)
                } else if wrap {
                    // Nothing below this column; wrap to the top end.
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

    // Jump to the bottom-most vertical position. From a work column, prefer a
    // bottom spot that column can reach (tied or shared); if none, wrap to the
    // column's own deepest stop so it stays put. From the top row (column nil),
    // fall to the nearest untied spot, else the nearest column's deepest stop.
    private func wrapToBottomEnd(_ nav: NavModel, x: Double, column: Int?) {
        if let column, let i = nav.bottomTarget(forColumn: column) {
            cursor = .bottom(i)
        } else if column == nil, let i = nav.freeBottomNearest(toX: x) {
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
            // Moving the cursor breaks any pending double-tap pairing.
            lastSelectSpot = nil
            moveCursor(dir, isRepeat: isRepeat)
        case .menu:
            let items = menuItems()
            if dir == .up {
                menuIndex = max(0, menuIndex - 1)
            } else if dir == .down {
                menuIndex = min(items.count - 1, menuIndex + 1)
            }
        case .help, .win, .lose, .shuffling:
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
            startNewGame(mode: nil)
        case .shuffling:
            break
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
        case .shuffling:
            break // don't interrupt the search
        case .none, .help, .win, .lose:
            menuPage = .main
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
                menuPage = .main
                menuIndex = 0
                overlay = .menu
            }
            refresh()
        case .menu:
            if menuPage == .chooseGame {
                // Step back to the main page, cursor on the Choose Game entry.
                menuPage = .main
                menuIndex = menuItems().firstIndex { $0.id == "choose" } ?? 0
            } else {
                overlay = .none
            }
        case .help, .win, .lose:
            overlay = .none
        case .shuffling:
            break // can't cancel mid-search
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

        // Treat a quick second tap on the same card as a long-press "send home".
        // Same-spot only, so it never turns a select-then-move into a send-home;
        // the draw pile is excluded since rapid taps there cycle the stock.
        var isRightClick = isRightClick
        if !isRightClick {
            let now = CardUtils.now()
            if spot.type != .draw, lastSelectSpot == spot, now - lastSelectTime < Self.doubleTapWindowMs {
                isRightClick = true
                lastSelectSpot = nil
            } else {
                lastSelectSpot = spot.type == .draw ? nil : spot
                lastSelectTime = now
            }
        } else {
            lastSelectSpot = nil
        }

        let droppingOnWork = game.state.selection.type != .none && spot.type == .work
        let before = game.state!
        game.click(spot.type, spot.outer, spot.inner, isRightClick: isRightClick)
        // A hint stays up through selection/cursor moves, but turns off the
        // moment a real move lands — before the version bump animates it.
        if hintsActive && !game.state.boardEquals(before) {
            hintsActive = false
        }
        // After dropping on a work column, land on its deepest stop (the tip
        // of the dropped run). While a selection is held the column is a
        // single drop-target stop, so the held stopIdx would otherwise be
        // misread against the rebuilt full stop list and jump high up the pile.
        if droppingOnWork, game.state.selection.type == .none {
            let nav = NavModel.build(game)
            if nav.workStops.indices.contains(spot.outer) {
                cursor = .work(col: spot.outer, stopIdx: nav.workStops[spot.outer].count - 1)
            }
        }
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
        hintsActive = false
        stopAutowin()
        resetCursor()
        refreshSeedQR()
        refresh()
    }

    // The single entry point for dealing a fresh *random* game (Play Again, a
    // variant pick, or playing again after a toast). Honors "Winnable only":
    // when on (and the mode is supported), it searches seeds off the main
    // thread behind a "Shuffling…" overlay and deals the first provably
    // winnable one. Otherwise it deals immediately.
    func startNewGame(mode: String?) {
        let targetMode = mode ?? game.modeId
        guard winnableOnly && winnableSupported.contains(targetMode) else {
            overlay = .none
            game.newGame(mode)
            afterNewGame()
            return
        }

        let hard = game.hard
        overlay = .shuffling
        refresh()

        // Solver work is CPU-heavy; run it off the main thread so the overlay
        // animates and the remote stays responsive, then hop back to deal.
        let budget = winnableBudget(targetMode)
        let worker = Thread {
            let solver = Solver()
            let seed = solver.findWinnableSeed(
                mode: targetMode, hard: hard,
                perSeedNodes: budget.nodes, perSeedSecs: budget.perSeedSecs, totalSecs: budget.totalSecs
            )
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.game.newGame(targetMode, seed: seed)
                self.overlay = .none
                self.afterNewGame()
            }
        }
        worker.stackSize = 8 * 1024 * 1024
        worker.start()
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
        switch menuPage {
        case .main: return mainMenuItems()
        case .chooseGame: return chooseGameItems()
        }
    }

    // Game actions first, display options at the bottom.
    private func mainMenuItems() -> [MenuEntry] {
        var items: [MenuEntry] = []

        items.append(MenuEntry(id: "undo", label: "Undo", enabled: game.canUndo) { [weak self] in
            guard let self else { return }
            self.game.undo()
            self.hintsActive = false
            // Stay in the menu so the player can keep undoing (like Dark Mode,
            // this is a repeatable in-menu action).
            self.afterAction()
        })

        // Hint: only for modes that can enumerate moves, and only enabled when
        // there's actually something to point at. Closes the menu and lights up
        // the movable cards until the next move.
        if game.mode.supportsHints {
            items.append(MenuEntry(id: "hint", label: "Hint", enabled: !game.mode.hints(game).isEmpty) { [weak self] in
                guard let self else { return }
                self.hintsActive = true
                self.overlay = .none
                self.refresh()
            })
        }

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

        items.append(MenuEntry(id: "winnable", label: "Winnable Only: \(winnableOnly ? "On" : "Off")", enabled: true) { [weak self] in
            guard let self else { return }
            self.winnableOnly.toggle()
            self.refresh()
        })

        items.append(MenuEntry(id: "again", label: "Play Again: \(game.mode.name)", enabled: true) { [weak self] in
            self?.startNewGame(mode: nil)
        })

        items.append(MenuEntry(id: "startover", label: "Start Over (same deal)", enabled: true) { [weak self] in
            guard let self else { return }
            self.overlay = .none
            self.game.newGame(nil, seed: self.game.seed)
            self.afterNewGame()
        })

        items.append(MenuEntry(id: "seed", label: "Enter Seed…", enabled: presentSeedEntry != nil) { [weak self] in
            guard let self, let present = self.presentSeedEntry else { return }
            present(self.game.seed) { entered in
                guard let entered else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.overlay = .none
                    self.game.newGame(nil, seed: entered)
                    self.afterNewGame()
                }
            }
        })

        items.append(MenuEntry(id: "choose", label: "Choose Game…", enabled: true) { [weak self] in
            guard let self else { return }
            self.menuPage = .chooseGame
            // Land the cursor on the game currently being played.
            self.menuIndex = self.game.modeOrder.firstIndex(of: self.game.modeId) ?? 0
        })

        items.append(MenuEntry(id: "dark", label: "Dark Mode: \(darkMode.label)", enabled: true) { [weak self] in
            guard let self else { return }
            self.darkMode = self.darkMode.next
            self.refresh()
        })

        items.append(MenuEntry(id: "deck", label: "Deck Color: \(deckColor.label)", enabled: true) { [weak self] in
            guard let self else { return }
            self.deckColor = self.deckColor.next
            self.refresh()
        })

        return items
    }

    private func chooseGameItems() -> [MenuEntry] {
        game.modeOrder.compactMap { modeId in
            guard let mode = game.modes[modeId] else { return nil }
            return MenuEntry(id: "new_\(modeId)", label: mode.name, enabled: true) { [weak self] in
                guard let self else { return }
                self.menuPage = .main
                self.startNewGame(mode: modeId)
            }
        }
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
        hintsActive = false
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
