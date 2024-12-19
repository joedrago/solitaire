/*
 * decaffeinate suggestions:
 * DS202: Simplify dynamic range loops
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from "../cardutils"

const mode = {}

mode.name = "Baker's Dozen"
mode.help = `\
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Build columns down regardless of suit. Only the topmost card may be moved
to another column which meets the build requirements. Empty columns must
stay empty.

The topmost card of any column may be moved to a foundation.

Kings are always dealt to the bottom of columns.

| HARD MODE:

Easy - All cards are dealt face up.

Hard - The last non-King card is face down in each column.\
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
            show: this.hard ? 1 : 3,
            cards: []
        },
        foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE],
        work: []
    }

    // shuffle the deck, but shuffle kings separately
    const deck = cardutils.shuffle(
        [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
            .concat([13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24])
            .concat([26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37])
            .concat([39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50])
    )
    const kings = cardutils.shuffle([12, 25, 38, 51])

    for (let columnIndex = 0; columnIndex < 13; columnIndex++) {
        this.state.work.push([])
    }

    const kingPositions = cardutils.shuffle([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]).slice(0, 4)
    for (let pIndex = 0; pIndex < kingPositions.length; pIndex++) {
        let p = kingPositions[pIndex]
        this.state.work[p].push(kings[pIndex])
    }
    for (let columnIndex = 0; columnIndex < 13; columnIndex++) {
        let col = this.state.work[columnIndex]
        if (this.hard) {
            col.push(deck.shift() | cardutils.FLIP_FLAG)
        }
        while (col.length < 4) {
            col.push(deck.shift())
        }
    }

    this.state.draw.cards = deck
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
        case "draw":
            // Draw some cards
            if (!this.state.hard && this.state.draw.cards.length == 0) {
                this.state.draw.cards = this.state.pile.cards
                this.state.pile.cards = []
            } else {
                let cardsToDraw = this.state.pile.show
                if (cardsToDraw > this.state.draw.cards.length) {
                    cardsToDraw = this.state.draw.cards.length
                }
                for (let i = 0; i < cardsToDraw; ++i) {
                    this.state.pile.cards.push(this.state.draw.cards.shift())
                }
            }
            this.select("none")
            break

        // -------------------------------------------------------------------------------------------
        case "pile":
            // Selecting the top card on the draw pile
            this.select("pile")
            break

        // -------------------------------------------------------------------------------------------
        case "foundation":
        case "work":
            // Potential selections or destinations
            let src = this.getSelection()

            // -----------------------------------------------------------------------------------------
            if (type == "foundation") {
                while (true) {
                    // create a gauntlet of breaks. if we survive them all, move the card
                    if (src.length != 1) {
                        break
                    }
                    let srcInfo = cardutils.info(src[0])
                    if (this.state.foundations[outerIndex] < 0) {
                        // empty
                        if (srcInfo.value != 0) {
                            // Ace
                            break
                        }
                    } else {
                        let dstInfo = cardutils.info(this.state.foundations[outerIndex])
                        if (srcInfo.suit != dstInfo.suit) {
                            break
                        }
                        if (srcInfo.value != dstInfo.value + 1) {
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
                const sameWorkPile = this.state.selection.type == "work" && this.state.selection.outerIndex == outerIndex
                if (src.length > 0 && !sameWorkPile) {
                    // Moving into work

                    const dst = this.state.work[outerIndex]
                    if (dst.length > 0) {
                        // Empty piles must stay empty
                        if (cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING)) {
                            for (let c of src) {
                                dst.push(c)
                            }
                            this.eatSelection()
                        }
                    }

                    this.select("none")
                } else if (sameWorkPile && isMouseUp) {
                    this.select("none")
                } else {
                    // Selecting a fresh column
                    const col = this.state.work[outerIndex]
                    if (col.length < 1) {
                        this.select("none")
                    } else {
                        innerIndex = col.length - 1
                        this.select(type, outerIndex, innerIndex)
                    }
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
    return this.state.draw.cards.length == 0 && this.state.pile.cards.length == 0 && this.workPileEmpty()
}

export default mode
