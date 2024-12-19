/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS202: Simplify dynamic range loops
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from "../cardutils"

const mode = {}

mode.name = "Eagle Wing"
mode.help = `\
| GOAL:

Build the foundations up, in suit, from the rank of the first card played in the foundation,
untill all cards of the suit have been played, wrapping from king to ace as necessary.

| PLAY:

The reserve is dealt 14 cards to begin with. Empty spaces in columns are filled automatically
from the reserve. If there are no cards left in the reserve, empty spaces of columns can be
filled with any available card.

Build columns down and in suit, wrapping as necessary. There is a 3 card maximum for colums.
Cards from the reserve, waste pile, and packed cards from other columns may be moved to a column.

There is one redeal.

| HARD MODE:

Easy - 14 cards in the reserve pile.

Hard - 17 cards in the reserve pile.\
`

mode.newGame = function () {
    this.state = {
        hard: this.hard,
        draw: {
            pos: "middle",
            redeals: 1,
            cards: []
        },
        selection: {
            type: "none",
            outerIndex: 0,
            innerIndex: 0
        },
        pile: {
            show: 1,
            cards: []
        },
        foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE],
        work: [],
        reserve: {
            pos: "middle",
            cols: [[]]
        }
    }

    const deck = cardutils.shuffle(cardutils.range(0, 52))

    for (let columnIndex = 0; columnIndex < 8; ++columnIndex) {
        this.state.work[columnIndex] = [deck.shift()]
    }

    const reserveCount = this.hard ? 17 : 14
    for (let columnIndex = 0; columnIndex < reserveCount; ++columnIndex) {
        this.state.reserve.cols[0].push(deck.shift())
    }

    this.state.foundations[0] = deck.shift()
    const foundationInfo = cardutils.info(this.state.foundations[0])
    this.state.foundationBase = foundationInfo.value
    this.state.centerDisplay = foundationInfo.valueName
    this.state.draw.cards = deck
}

mode.eagleDealReserve = function () {
    for (let workIndex = 0; workIndex < this.state.work.length; ++workIndex) {
        let work = this.state.work[workIndex]
        if (this.state.reserve.cols[0].length < 1) {
            break
        }
        if (work.length == 0) {
            work.push(this.state.reserve.cols[0].pop())
        }
    }
}

mode.click = function (type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    if (isRightClick) {
        if (!isMouseUp) {
            this.sendHome(type, outerIndex, innerIndex)
            this.eagleDealReserve()
        }
        this.select("none")
        return
    }

    switch (type) {
        // -------------------------------------------------------------------------------------------
        case "draw":
            // Draw some cards
            if (!this.state.hard && this.state.draw.cards.length == 0) {
                if (this.state.draw.redeals > 0) {
                    this.state.draw.redeals -= 1
                    this.state.draw.cards = this.state.pile.cards
                    this.state.pile.cards = []
                }
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
        case "reserve":
            // Selecting the top card on the draw pile
            this.select("reserve", 0, this.state.reserve.cols[0].length - 1)
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
                        if (srcInfo.value != this.state.foundationBase) {
                            break
                        }
                    } else {
                        let dstInfo = cardutils.info(this.state.foundations[outerIndex])
                        if (srcInfo.suit != dstInfo.suit) {
                            break
                        }
                        if (srcInfo.value != dstInfo.value + 1 && srcInfo.value != dstInfo.value - 12) {
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
                    if (dst.length + src.length <= 3) {
                        // Eagle Wing has a pile max of 3
                        if (
                            dst.length == 0 ||
                            cardutils.validMove(
                                src,
                                dst,
                                cardutils.VALIDMOVE_DESCENDING_WRAP |
                                    cardutils.VALIDMOVE_MATCHING_SUIT |
                                    cardutils.VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE,
                                this.state.foundationBase
                            )
                        ) {
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

    this.eagleDealReserve()
}

mode.won = function () {
    return (
        this.state.draw.cards.length == 0 &&
        this.state.pile.cards.length == 0 &&
        this.state.reserve.cols[0].length == 0 &&
        this.workPileEmpty()
    )
}

export default mode
