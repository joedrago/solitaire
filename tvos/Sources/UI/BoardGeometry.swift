import SwiftUI

// A clickable location on the table, mirroring the (type, outerIndex,
// innerIndex) triples the JS game passes to game.click().
struct Spot: Hashable {
    let type: SpotType
    let outer: Int
    let inner: Int

    init(_ type: SpotType, _ outer: Int = 0, _ inner: Int = 0) {
        self.type = type
        self.outer = outer
        self.inner = inner
    }
}

enum SelectedState {
    case none
    case selected
    case foundationOnly
}

struct CardPlacement: Identifiable {
    let id: String
    let raw: Int
    let rect: CGRect
    let selected: SelectedState
    let zIndex: Double
    // The clickable spot this card occupies, if any. Lets the cursor attach to
    // its target card in the render loop so overlapping cards occlude it.
    let spot: Spot?
    var opacity: Double = 1
    var rotation: Double = 0 // degrees, used by the win fan
}

// Layout port of SolitaireView.render(): positions are computed in units of
// one card height, then scaled to fit the screen.
struct BoardGeometry {
    static let cardWidth: CGFloat = 119
    static let cardHeight: CGFloat = 162
    static let pileCardOverlap: CGFloat = 0.105
    static let workCardOverlap: CGFloat = 0.25
    static let centerCardMargin: CGFloat = (0.5 * (cardHeight - cardWidth)) / cardHeight
    static let minimumScaleInCardHeights: CGFloat = 12

    var placements: [CardPlacement] = []
    var spotRects: [Spot: CGRect] = [:]
    var unit: CGFloat = 100 // one card height, in pixels
    var size: CGSize = .zero

    // Occurrence counters for real cards. Multi-deck modes tag duplicate
    // copies with COPY bits, so raws are normally unique already; this is a
    // fallback that keeps ids distinct for saves predating the tags (their
    // animations stay layout-order guesses until a new game is dealt).
    private var cardOccurrences: [Int: Int] = [:]

    private mutating func place(
        _ key: String, _ raw: Int, _ x: CGFloat, _ y: CGFloat,
        spot: Spot? = nil, selected: SelectedState = .none, z: Double = 0, opacity: Double = 1,
        rotation: Double = 0
    ) {
        // Real cards get an identity that follows the card rather than the
        // board slot, so SwiftUI animates a moved card from its old position
        // to its new one instead of treating the move as remove+insert. The
        // flip flag is masked off so a card keeps its identity when it turns
        // face-up, but the COPY bits stay in: they're what keep the twin
        // copies in multi-deck games from trading identities (and animations)
        // mid-move. Pseudo-cards (guides, the stock) keep their positional key.
        var key = key
        if raw >= 0 {
            let card = raw & ~CardUtils.FLIP_FLAG
            let n = cardOccurrences[card, default: 0]
            cardOccurrences[card] = n + 1
            key = "c\(card)_\(n)"
        }

        let rect = CGRect(x: x, y: y, width: unit * Self.cardWidth / Self.cardHeight, height: unit)
        placements.append(CardPlacement(
            id: key, raw: raw, rect: rect, selected: selected, zIndex: z, spot: spot,
            opacity: opacity, rotation: rotation
        ))
        if let spot {
            spotRects[spot] = rect
        }
    }

    static func compute(state: GameState, size: CGSize, won: Bool = false) -> BoardGeometry {
        var b = BoardGeometry()
        b.size = size

        if won {
            b.computeWinFan()
            return b
        }

        // Calculate necessary table extents, pretending a card is 1.0 units tall
        var largestWork = minimumScaleInCardHeights
        for w in state.work where largestWork < CGFloat(w.count) {
            largestWork = CGFloat(w.count)
        }

        let foundationOffsetL = CGFloat(state.work.count - state.foundations.count)
        let topWidth = CGFloat(state.foundations.count) + foundationOffsetL
        let workWidth = CGFloat(state.work.count)

        var workTop: CGFloat = 0
        if state.draw.pos == "top" || !state.foundations.isEmpty {
            workTop = 1.25
        }
        var workBottom = workTop + 1 + (largestWork - 1) * workCardOverlap
        if workBottom < 4.1 && (state.draw.pos == "middle" || state.reserve?.pos == "middle") {
            // Leave room for draw/reserve at the bottom of the screen
            workBottom = 4.1
        }

        let maxWidth = max(topWidth, workWidth)
        let maxHeight = workBottom
        let maxAspectRatio = maxWidth / maxHeight
        let boardAspectRatio = size.width / size.height

        let maxWidthPixels = maxWidth * cardHeight
        let maxHeightPixels = maxHeight * cardHeight

        var renderScale: CGFloat
        var renderOffsetL: CGFloat
        if maxAspectRatio < boardAspectRatio {
            // use height for scaling
            renderScale = size.height / maxHeightPixels
            renderOffsetL = (size.width - maxWidthPixels * renderScale) / 2
        } else {
            // use width for scaling
            renderScale = size.width / maxWidthPixels
            renderOffsetL = 0
        }
        let unit = renderScale * cardHeight
        b.unit = unit
        let renderOffsetT = unit * 0.1

        if state.draw.pos == "top" || state.draw.pos == "middle" {
            var drawOffsetL: CGFloat
            var drawOffsetT: CGFloat
            if state.draw.pos == "top" {
                drawOffsetL = 0
                drawOffsetT = 0
            } else if state.reserve?.pos == "middle" {
                drawOffsetL = 1 * unit
                drawOffsetT = 3 * unit
            } else {
                drawOffsetL = (maxWidth / 2 - 1) * unit
                drawOffsetT = 2.3 * unit
            }

            // Draw Pile
            var drawCard = CardUtils.BACK
            if state.draw.cards.isEmpty {
                drawCard = CardUtils.READY
                if state.draw.redeals == 0 {
                    drawCard = CardUtils.DEAD
                }
            }
            b.place(
                "draw", drawCard,
                drawOffsetL + renderOffsetL + unit * centerCardMargin,
                drawOffsetT + renderOffsetT,
                spot: Spot(.draw)
            )

            // Waste pile: an under-card (or guide), then the visible fan
            var pileRenderCount = state.pile.cards.count
            if pileRenderCount > state.pile.show {
                pileRenderCount = state.pile.show
            }
            let startPileIndex = state.pile.cards.count - pileRenderCount

            let pileBaseX = drawOffsetL + renderOffsetL + (1 + centerCardMargin) * unit
            if startPileIndex > 0 {
                b.place("pileundercard", state.pile.cards[startPileIndex - 1], pileBaseX, drawOffsetT + renderOffsetT)
            } else {
                b.place("pileguide", CardUtils.GUIDE, pileBaseX, drawOffsetT + renderOffsetT, spot: Spot(.pile))
            }

            for pileIndex in startPileIndex..<state.pile.cards.count {
                let isTop = pileIndex == state.pile.cards.count - 1
                let isSelected = state.selection.type == .pile && isTop
                b.place(
                    "pile\(pileIndex)", state.pile.cards[pileIndex],
                    pileBaseX + CGFloat(pileIndex - startPileIndex) * pileCardOverlap * unit,
                    drawOffsetT + renderOffsetT,
                    spot: isTop ? Spot(.pile) : nil,
                    selected: isSelected ? .selected : .none
                )
            }
        }

        // Work columns
        var currentL = renderOffsetL + centerCardMargin * unit
        for (workColumnIndex, workColumn) in state.work.enumerated() {
            b.place(
                "workguide\(workColumnIndex)", CardUtils.GUIDE,
                currentL, workTop * unit,
                spot: Spot(.work, workColumnIndex, -1)
            )
            for (workIndex, work) in workColumn.enumerated() {
                var selected = SelectedState.none
                if state.selection.type == .work && workColumnIndex == state.selection.outerIndex
                    && workIndex >= state.selection.innerIndex
                {
                    selected = state.selection.foundationOnly == true ? .foundationOnly : .selected
                }
                b.place(
                    "work\(workColumnIndex)_\(workIndex)", work,
                    currentL, (workTop + CGFloat(workIndex) * workCardOverlap) * unit,
                    spot: Spot(.work, workColumnIndex, workIndex),
                    selected: selected,
                    z: selected != .none ? 5 : 0
                )
            }
            currentL += unit
        }

        // Foundations
        currentL = renderOffsetL + (foundationOffsetL + centerCardMargin) * unit
        for (foundationIndex, foundation) in state.foundations.enumerated() {
            b.place(
                "foundguide\(foundationIndex)", CardUtils.GUIDE,
                currentL, renderOffsetT,
                spot: Spot(.foundation, foundationIndex)
            )
            if foundation != CardUtils.GUIDE {
                b.place(
                    "found\(foundationIndex)", foundation,
                    currentL, renderOffsetT,
                    spot: Spot(.foundation, foundationIndex)
                )
            }
            currentL += unit
        }

        if state.draw.pos == "bottom" {
            // Stock tied under column 0, peeking up from the screen edge — only
            // the top quarter shows. No extra width is reserved, so the board
            // never zooms out. When empty (no redeal in these modes) it's a
            // non-targetable guide.
            let isEmpty = state.draw.cards.isEmpty
            let drawCard = isEmpty ? CardUtils.GUIDE : CardUtils.BACK
            b.place(
                "draw", drawCard,
                renderOffsetL + centerCardMargin * unit,
                size.height - 0.25 * unit,
                spot: isEmpty ? nil : Spot(.draw),
                opacity: 0.75
            )
        }

        if let reserve = state.reserve {
            var drawOffsetL: CGFloat
            var drawOffsetT: CGFloat
            if reserve.pos == "middle" {
                drawOffsetL = (maxWidth / 2 - 0.5) * unit
                drawOffsetT = 3 * unit
            } else {
                drawOffsetL = 0
                drawOffsetT = 0
            }

            for (colIndex, col) in reserve.cols.enumerated() {
                var underCard = CardUtils.RESERVE
                if col.count > 1 {
                    underCard = col[col.count - 2]
                }
                let x = drawOffsetL + renderOffsetL + unit * (CGFloat(colIndex) + centerCardMargin)
                b.place(
                    "reserveguide\(colIndex)", underCard,
                    x, drawOffsetT + renderOffsetT,
                    spot: Spot(.reserve, colIndex)
                )

                if let top = col.last {
                    let isSelected = state.selection.type == .reserve && colIndex == state.selection.outerIndex
                    b.place(
                        "reserve\(colIndex)", top,
                        x, drawOffsetT + renderOffsetT,
                        spot: Spot(.reserve, colIndex),
                        selected: isSelected ? .selected : .none
                    )
                }
            }
        }

        return b
    }

    // Win celebration: the whole deck fans into a rainbow arch, each card
    // rotated to the arc's tangent. This is a graphic, not a state display —
    // it's always one full sorted deck regardless of mode, because won states
    // don't retain every card (foundations only track their top). Cards still
    // on the table fly to their arc slots via identity; the rest fade in.
    private mutating func computeWinFan() {
        unit = size.height * 0.22
        let radius = size.height * 0.75
        let centerX = size.width / 2
        let centerY = size.height * 1.05
        let spread = 150.0 // degrees, end to end
        let cardW = unit * Self.cardWidth / Self.cardHeight

        for card in 0..<52 {
            let t = Double(card) / 51.0
            let deg = spread * (t - 0.5)
            let rad = CGFloat(deg * .pi / 180)
            let x = centerX + radius * sin(rad)
            let y = centerY - radius * cos(rad)
            place(
                "winfan", card,
                x - cardW / 2, y - unit / 2,
                z: Double(card),
                rotation: deg
            )
        }
    }
}
