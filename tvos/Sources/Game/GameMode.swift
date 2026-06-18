import Foundation

// A single "you could pick this up and move it somewhere new" suggestion: the
// spot of the source card a hint highlights. Deliberately a game-layer type
// (not the UI's Spot) so the CLI solver targets, which compile only
// Sources/Game, still build; the UI converts these to Spots for rendering.
struct HintMove: Equatable {
    let type: SpotType
    let outer: Int
    let inner: Int
}

// Equivalent of the JS mode objects in src/modes/*.js. Each mode owns dealing,
// click handling, and win/loss detection; shared helpers live on SolitaireGame.
protocol GameMode {
    var id: String { get }
    var name: String { get }
    var help: String { get }

    func newGame(_ g: SolitaireGame)
    func click(_ g: SolitaireGame, _ type: SpotType, _ outerIndex: Int, _ innerIndex: Int, _ isRightClick: Bool)
    func won(_ g: SolitaireGame) -> Bool
    func lost(_ g: SolitaireGame) -> Bool

    // Inner indices in `col` the cursor may rest on: every position whose
    // click produces a distinct selection in this mode. The default (just the
    // topmost card) suits modes that only ever move single cards.
    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int]

    // Hints. A mode opts in by returning true and implementing `hints`, which
    // lists the source cards that can be picked up and moved somewhere new. The
    // board gently highlights these when the player asks for a hint, and uses
    // `hasMoves` (hint cards plus any other progress, e.g. dealing the stock)
    // to decide when to show a quiet "Game Over".
    var supportsHints: Bool { get }
    func hints(_ g: SolitaireGame) -> [HintMove]
    func hasMoves(_ g: SolitaireGame) -> Bool
}

extension GameMode {
    func lost(_ g: SolitaireGame) -> Bool { false }

    var supportsHints: Bool { false }

    func hints(_ g: SolitaireGame) -> [HintMove] { [] }

    func hasMoves(_ g: SolitaireGame) -> Bool { !hints(g).isEmpty }

    func cursorStops(_ g: SolitaireGame, _ col: [Int]) -> [Int] {
        col.isEmpty ? [] : [col.count - 1]
    }

    // Shared stop list for modes that let you grab any face-up card.
    func faceUpStops(_ col: [Int]) -> [Int] {
        var stops: [Int] = []
        for (i, raw) in col.enumerated() where (raw & CardUtils.FLIP_FLAG) == 0 {
            stops.append(i)
        }
        return stops
    }

    // Shared stop list for run-grabbing modes (klondike, eagle, spider,
    // spiderette). Their click logic offers exactly two outcomes: clicking
    // the topmost card (single-card / foundation-only selection) or clicking
    // anywhere deeper (the maximal packed run ending at the topmost card).
    // Mirrors the "Selecting a fresh column" walk in those modes' click().
    func runStops(_ col: [Int], matchingSuit: Bool) -> [Int] {
        if col.isEmpty {
            return []
        }
        var stopIndex = 0
        while stopIndex < col.count && (col[stopIndex] & CardUtils.FLIP_FLAG) != 0 {
            stopIndex += 1
        }
        var innerIndex = col.count - 1
        while innerIndex > stopIndex {
            let lowerInfo = CardUtils.info(col[innerIndex])
            let upperInfo = CardUtils.info(col[innerIndex - 1])
            if lowerInfo.value != upperInfo.value - 1 {
                break
            }
            if matchingSuit && lowerInfo.suit != upperInfo.suit {
                break
            }
            innerIndex -= 1
        }
        if innerIndex >= col.count - 1 {
            return [col.count - 1]
        }
        return [innerIndex, col.count - 1]
    }
}
