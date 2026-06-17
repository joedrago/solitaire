import Foundation

// Command-line solver: `solve <game> <seed> [hard]`. Deals the exact game for
// that seed and prints the winning move sequence (or that none was found in
// budget). Built from the same Sources/Game code the app uses.
let args = CommandLine.arguments
guard args.count >= 3, let seed = Int(args[2]) else {
    FileHandle.standardError.write(Data("usage: solve <game> <seed> [hard]\n".utf8))
    exit(2)
}
let game = args[1]
let hard = args.count >= 4 && ["hard", "true", "1", "y"].contains(args[3].lowercased())

let dealer = Solver()
let gs = dealer.deal(mode: game, hard: hard, seed: seed)
let deadline = Date().addingTimeInterval(30)
let maxNodes = 8_000_000

func report(_ moves: [Move]?, _ nodes: Int) {
    let tag = "\(game) seed \(seed)\(hard ? " (hard)" : "")"
    if let moves {
        print("\(tag): SOLVED in \(moves.count) moves  [\(nodes) nodes]")
        for (i, m) in moves.enumerated() { print(String(format: "  %3d. %@", i + 1, m.describe())) }
    } else {
        print("\(tag): no solution found  [\(nodes) nodes]")
    }
}

switch game {
case "scorpion":
    let solver = ScorpionSolver(hard: hard)
    let r = solver.solveWithMoves(ScorpionSolver.from(gs), maxNodes: maxNodes, deadline: deadline)
    report(r.moves, r.nodes)
case "yukon":
    let solver = YukonSolver(hard: hard)
    let r = solver.solveWithMoves(YukonSolver.from(gs), maxNodes: maxNodes, deadline: deadline)
    report(r.moves, r.nodes)
case "emperor":
    let solver = EmperorSolver(hard: hard)
    let r = solver.solveWithMoves(EmperorSolver.from(gs), maxNodes: maxNodes, deadline: deadline)
    report(r.moves, r.nodes)
default:
    FileHandle.standardError.write(Data("no solver for '\(game)' yet (have: scorpion, yukon, emperor)\n".utf8))
    exit(1)
}
