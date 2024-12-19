import * as cardutils from "../cardutils"

const mode = {}

mode.name = "Klondike"
mode.help = `\
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Cards are flipped 3 at a time to a waste pile. Columns are built down, in
alternating colors. All packed cards in a column must be moved as a unit
to other columns.

The topmost card of any column or the waste pile may be moved to a
foundation. The top card of the waste pile may also be moved to a column
if desired, thus making the card below it playable also.

Unlimited redeals are allowed.

| HARD MODE:

Easy - Cards are flipped 3 cards at a time with unlimited redeals.

Hard - Cards are flipped 1 card at a time with no redeals.\
`

mode.newGame = function () {
    this.state = {
        hard: this.hard,
        draw: {
            pos: "top",
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

    const deck = cardutils.shuffle(cardutils.range(0, 52))
    for (let columnIndex = 0; columnIndex < 7; columnIndex++) {
        let col = []
        for (let i = 0; i < columnIndex; ++i) {
            col.push(deck.shift() | cardutils.FLIP_FLAG)
        }
        col.push(deck.shift())
        this.state.work.push(col)
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

                    if (this.state.selection.foundationOnly) {
                        this.select("none")
                        return
                    }

                    const dst = this.state.work[outerIndex]
                    if (
                        cardutils.validMove(
                            src,
                            dst,
                            cardutils.VALIDMOVE_DESCENDING |
                                cardutils.VALIDMOVE_ALTERNATING_COLOR |
                                cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
                        )
                    ) {
                        for (let c of src) {
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
                    const wasClickingLastCard = innerIndex == col.length - 1

                    innerIndex = 0 // "All packed cards in a column must be moved as a unit to other columns."
                    while (innerIndex < col.length && col[innerIndex] & cardutils.FLIP_FLAG) {
                        // Don't select face down cards
                        innerIndex += 1
                    }

                    const stopIndex = innerIndex
                    innerIndex = col.length - 1
                    while (innerIndex > stopIndex) {
                        let lowerInfo = cardutils.info(col[innerIndex])
                        let upperInfo = cardutils.info(col[innerIndex - 1])
                        if (lowerInfo.value != upperInfo.value - 1) {
                            break
                        }
                        innerIndex -= 1
                    }

                    const isClickingLastCard = innerIndex == col.length - 1

                    if (wasClickingLastCard && !isClickingLastCard) {
                        this.select(type, outerIndex, col.length - 1)
                        this.state.selection.foundationOnly = true
                    } else {
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
