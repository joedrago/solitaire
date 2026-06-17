import Foundation

// Solver verifier: solve a deal, then replay the emitted moves through the REAL
// game engine (the same mode.click the app uses) and assert the game is won.
// This proves the fast solver's move generation matches the real rules — no
// illegal or impossible moves slip into a "winnable" verdict.
//
//   verify <game> <seed> [hard]          verify one deal
//   verify <game> batch <count> [hard]   solve+replay <count> random deals
//
// Built from the same Sources/Game code as the app and the `solve` tool.
@main
enum Verify {
    // Per-game dispatch: ask the fast solver for a winning move list. Add a case
    // here (and in tools/main.swift) as each game's solver lands.
    static func solveMoves(_ game: String, _ gs: GameState, perSeed: Double) -> [Move]? {
        let deadline = Date().addingTimeInterval(perSeed)
        switch game {
        case "scorpion":
            let s = ScorpionSolver(hard: gs.hard)
            return s.solveWithMoves(ScorpionSolver.from(gs), maxNodes: 8_000_000, deadline: deadline).moves
        case "yukon":
            let s = YukonSolver(hard: gs.hard)
            return s.solveWithMoves(YukonSolver.from(gs), maxNodes: 8_000_000, deadline: deadline).moves
        case "emperor":
            let s = EmperorSolver(hard: gs.hard)
            return s.solveWithMoves(EmperorSolver.from(gs), maxNodes: 8_000_000, deadline: deadline).moves
        default:
            FileHandle.standardError.write(Data("no solver for '\(game)' yet (have: scorpion, yukon, emperor)\n".utf8))
            exit(1)
        }
    }

    // Replay one solution through a fresh real game. Returns (won, firstBadStep);
    // firstBadStep is -1 when every move was legal (changed the board).
    static func replay(_ game: String, seed: Int, hard: Bool, _ moves: [Move]) -> (won: Bool, badStep: Int) {
        let g = SolitaireGame(load: false)
        g.modeId = game; g.hard = hard; g.seed = seed
        g.rng = SeededGenerator(seed: seed)
        g.mode.newGame(g)
        g.state.seed = seed

        for (idx, m) in moves.enumerated() {
            let before = g.state!
            switch m.kind {
            case .stockDeal, .draw:
                g.click(.draw, 0, 0)
            case .tableau:
                let inner = g.state.work[m.from].count - m.count
                g.click(.work, m.from, inner) // select the run (bottom card = m.card)
                g.click(.work, m.to, 0)       // drop it onto the destination column
            case .foundation:
                let top = g.state.work[m.from].count - 1
                g.click(.work, m.from, top, isRightClick: true) // send top card home
            case .wasteToFoundation:
                g.click(.pile, 0, 0, isRightClick: true)        // send waste top home
            case .wasteToCol:
                g.click(.pile, 0, 0)
                g.click(.work, m.to, 0)
            default:
                return (false, idx + 1) // unhandled kind = treat as a verification gap
            }
            if g.state.boardEquals(before) { return (false, idx + 1) } // no-op = illegal
        }
        return (g.won(), -1)
    }

    static func main() {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            FileHandle.standardError.write(Data("usage: verify <game> <seed|batch> [count] [hard]\n".utf8))
            exit(2)
        }
        let game = args[1]
        let dealer = Solver()

        if args[2].lowercased() == "batch" {
            let count = args.count >= 4 ? (Int(args[3]) ?? 200) : 200
            let hard = args.count >= 5 && ["hard", "true", "1", "y"].contains(args[4].lowercased())
            let perSeed: Double = hard ? 2 : 5

            var solved = 0, verified = 0, illegal = 0, notWon = 0, firstBad = -1
            let start = Date()
            for _ in 0..<count {
                let seed = randomSeed()
                let gs = dealer.deal(mode: game, hard: hard, seed: seed)
                guard let moves = solveMoves(game, gs, perSeed: perSeed) else { continue }
                solved += 1
                let r = replay(game, seed: seed, hard: hard, moves)
                if r.won {
                    verified += 1
                } else if r.badStep >= 0 {
                    illegal += 1
                    if firstBad < 0 { firstBad = seed; print("ILLEGAL move at step \(r.badStep): seed \(seed)") }
                } else {
                    notWon += 1
                    if firstBad < 0 { firstBad = seed; print("solved-but-not-won: seed \(seed)") }
                }
            }
            let secs = Date().timeIntervalSince(start)
            print("\(game) \(hard ? "hard" : "easy"): \(count) seeds in \(String(format: "%.1f", secs))s")
            print("  solvable: \(solved)   verified-win: \(verified)   ILLEGAL: \(illegal)   not-won: \(notWon)")
            if illegal == 0 && notWon == 0 {
                print("  ALL solutions replay-legal and win \u{2713}")
                exit(0)
            }
            exit(1)
        }

        // Single-seed mode.
        guard let seed = Int(args[2]) else {
            FileHandle.standardError.write(Data("usage: verify <game> <seed> [hard]\n".utf8))
            exit(2)
        }
        let hard = args.count >= 4 && ["hard", "true", "1", "y"].contains(args[3].lowercased())
        let gs = dealer.deal(mode: game, hard: hard, seed: seed)
        let tag = "\(game) seed \(seed)\(hard ? " (hard)" : "")"

        guard let moves = solveMoves(game, gs, perSeed: 30) else {
            print("\(tag): no solution found in budget")
            exit(1)
        }
        let r = replay(game, seed: seed, hard: hard, moves)
        if r.won {
            print("\(tag): VERIFIED WIN \u{2713}  (\(moves.count) moves, all legal)")
            exit(0)
        } else if r.badStep >= 0 {
            print("\(tag): DIVERGENCE at step \(r.badStep): \(moves[r.badStep - 1].describe())")
            print("  (that move did not change the real board — illegal/impossible)")
            exit(1)
        } else {
            print("\(tag): replayed all \(moves.count) moves but game NOT won")
            exit(1)
        }
    }
}
