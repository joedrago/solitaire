import * as cardutils from "../cardutils"

const mode = {}

mode.name = "Yukon"
mode.help = `\
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Build columns down and in any other suit.

Any face up card in the tableau along with all other cards on top of it,
may be moved to another column provided that the connecting cards folow
the build rules.Spaces in columns are filled only with kings.

There is no redeal.

| HARD MODE:

Easy - Columns are built on any other suit.

Hard - Columns are built on alternating colors.\
`

mode.newGame = function () {
    this.state = {
        hard: this.hard,
        draw: {
            pos: "none",
            cards: []
        },
        selection: {
            type: "none",
            outerIndex: 0,
            innerIndex: 0
        },
        pile: {
            show: 3,
            cards: []
        },
        foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE],
        work: []
    }

    const deck = cardutils.shuffle(cardutils.range(0, 52))
    this.state.work.push([deck.shift()])
    for (let columnIndex = 1; columnIndex < 7; columnIndex++) {
        var col = []
        for (let i = 0; i < columnIndex; ++i) {
            col.push(deck.shift() | cardutils.FLIP_FLAG)
        }
        for (let i = 0; i < 5; i++) {
            col.push(deck.shift())
        }
        this.state.work.push(col)
    }

    this.state.draw.cards = []
}

mode.click = function (type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    if (isRightClick) {
        if (!isMouseUp) {
            this.sendHome(type, outerIndex, innerIndex)
        }
        this.select("none")
        return
    }

    switch (type) {
        // -------------------------------------------------------------------------------------------
        case "foundation":
        case "work":
            // Potential selections or destinations
            var src = this.getSelection()

            // -----------------------------------------------------------------------------------------
            if (type === "foundation") {
                while (true) {
                    // create a gauntlet of breaks. if we survive them all, move the card
                    if (src.length !== 1) {
                        break
                    }
                    var srcInfo = cardutils.info(src[0])
                    if (this.state.foundations[outerIndex] < 0) {
                        // empty
                        if (srcInfo.value !== 0) {
                            // Ace
                            break
                        }
                    } else {
                        var dstInfo = cardutils.info(this.state.foundations[outerIndex])
                        if (srcInfo.suit !== dstInfo.suit) {
                            break
                        }
                        if (srcInfo.value !== dstInfo.value + 1) {
                            break
                        }
                    }

                    this.state.foundations[outerIndex] = src[0]
                    this.eatSelection()
                    break
                }
                this.select("none")

                // ---------------------------------------------------------------------------------------
            } else {
                // type == work
                const sameWorkPile = this.state.selection.type === "work" && this.state.selection.outerIndex === outerIndex
                if (src.length > 0 && !sameWorkPile) {
                    // Moving into work
                    let validFlags
                    const dst = this.state.work[outerIndex]

                    if (this.state.hard) {
                        validFlags =
                            cardutils.VALIDMOVE_DESCENDING |
                            cardutils.VALIDMOVE_ALTERNATING_COLOR |
                            cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
                    } else {
                        validFlags =
                            cardutils.VALIDMOVE_DESCENDING |
                            cardutils.VALIDMOVE_ANY_OTHER_SUIT |
                            cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
                    }
                    if (cardutils.validMove(src, dst, validFlags)) {
                        for (var c of src) {
                            dst.push(c)
                        }
                        this.eatSelection()
                    }

                    this.select("none")
                } else if (sameWorkPile && isMouseUp) {
                    this.select("none")
                } else {
                    // Selecting a fresh column
                    const col = this.state.work[outerIndex]
                    while (innerIndex < col.length && col[innerIndex] & cardutils.FLIP_FLAG) {
                        // Don't select face down cards
                        innerIndex += 1
                    }

                    this.select(type, outerIndex, innerIndex)
                }
            }
            break

        // -------------------------------------------------------------------------------------------
        default:
            // Probably a background click, just forget the selection
            this.select("none")
    }
}

mode.won = function () {
    return this.state.draw.cards.length === 0 && this.state.pile.cards.length === 0 && this.workPileEmpty()
}

export default mode
