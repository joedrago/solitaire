import Foundation

// Deals seeds (no UI, no save) and asks the per-game fast solver whether a deal
// is winnable. The fast solvers (e.g. ScorpionSolver) work on a compact
// card-only model with direct move generation and a canonicalizing
// transposition table — fast enough to run on the Apple TV. Modes without a
// fast solver yet are left unfiltered (see AppModel.winnableSupported).
final class Solver {
    // Reusable sandbox game used only to deal a layout from a seed.
    private let g = SolitaireGame(load: false)

    func deal(mode: String, hard: Bool, seed: Int) -> GameState {
        g.modeId = mode
        g.hard = hard
        g.seed = seed
        g.rng = SeededGenerator(seed: seed)
        g.mode.newGame(g)
        return g.state
    }

    // Provably winnable within the budget? Dispatches to the mode's fast solver.
    // A mode without one returns false (callers gate on winnableSupported).
    func isWinnable(mode: String, _ gs: GameState, maxNodes: Int, deadline: Date) -> Bool {
        switch mode {
        case "scorpion":
            let solver = ScorpionSolver(hard: gs.hard)
            return solver.solvable(ScorpionSolver.from(gs), maxNodes: maxNodes, deadline: deadline)
        case "yukon":
            let solver = YukonSolver(hard: gs.hard)
            return solver.solvable(YukonSolver.from(gs), maxNodes: maxNodes, deadline: deadline)
        case "emperor":
            let solver = EmperorSolver(hard: gs.hard)
            return solver.solvable(EmperorSolver.from(gs), maxNodes: maxNodes, deadline: deadline)
        default:
            return false
        }
    }

    // Search random seeds for a provably-winnable one within an overall budget.
    // Returns the winnable seed, or a fresh random seed if none is proven in
    // time (so the player never waits forever).
    func findWinnableSeed(mode: String, hard: Bool, perSeedNodes: Int, perSeedSecs: Double, totalSecs: Double) -> Int {
        let overall = Date().addingTimeInterval(totalSecs)
        var lastSeed = randomSeed()
        while Date() < overall {
            let seed = randomSeed()
            lastSeed = seed
            let gs = deal(mode: mode, hard: hard, seed: seed)
            let deadline = min(Date().addingTimeInterval(perSeedSecs), overall)
            if isWinnable(mode: mode, gs, maxNodes: perSeedNodes, deadline: deadline) {
                return seed
            }
        }
        return lastSeed
    }
}
