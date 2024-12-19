/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from "../cardutils"

const mode = {
    name: "Emperor",
    help: `\
| GOAL:

Build the foundations up in suit from ace to king (2 decks).

| PLAY:

Cards are flipped 1 at a time to a waste pile. Columns are built down, in
alternating colors.

The topmost card of any column or the waste pile may be moved to a
foundation. The top card of the waste pile may also be moved to a column
if desired, thus making the card below it playable also. Spaces in
columns may be filled with any card.

No redeals.

| HARD MODE:

Easy - Any number of packed cards may be moved together. (modern rules)

Hard - Only one card may be moved at a time. (original rules)\
`,

    newGame() {
        this.state = {
            hard: this.hard,
            draw: {
                pos: "top",
                redeals: 0,
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
            foundations: [
                cardutils.GUIDE,
                cardutils.GUIDE,
                cardutils.GUIDE,
                cardutils.GUIDE,
                cardutils.GUIDE,
                cardutils.GUIDE,
                cardutils.GUIDE,
                cardutils.GUIDE
            ],
            work: []
        }

        const deck = cardutils.shuffle(__range__(0, 52, false).concat(__range__(0, 52, false)))
        for (let columnIndex = 0; columnIndex < 10; columnIndex++) {
            var col = []
            for (var i = 0; i < 3; i++) {
                col.push(deck.shift() | cardutils.FLIP_FLAG)
            }
            col.push(deck.shift())
            this.state.work.push(col)
        }

        return (this.state.draw.cards = deck)
    },

    click(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
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
                if (this.state.draw.cards.length > 0) {
                    let cardsToDraw = this.state.pile.show
                    if (cardsToDraw > this.state.draw.cards.length) {
                        cardsToDraw = this.state.draw.cards.length
                    }
                    for (let i = 0, end = cardsToDraw, asc = 0 <= end; asc ? i < end : i > end; asc ? i++ : i--) {
                        this.state.pile.cards.push(this.state.draw.cards.shift())
                    }
                }
                return this.select("none")

            // -------------------------------------------------------------------------------------------
            case "pile":
                // Selecting the top card on the draw pile
                return this.select("pile")

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
                    return this.select("none")

                    // ---------------------------------------------------------------------------------------
                } else {
                    // type == work
                    const sameWorkPile = this.state.selection.type === "work" && this.state.selection.outerIndex === outerIndex
                    if (src.length > 0 && !sameWorkPile) {
                        // Moving into work

                        const dst = this.state.work[outerIndex]
                        if (
                            cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR)
                        ) {
                            for (var c of Array.from(src)) {
                                dst.push(c)
                            }
                            this.eatSelection()
                        }

                        return this.select("none")
                    } else if (sameWorkPile && isMouseUp) {
                        return this.select("none")
                    } else {
                        // Selecting a fresh column
                        const col = this.state.work[outerIndex]

                        if (col.length < 1) {
                            this.select("none")
                        } else if (this.state.hard) {
                            innerIndex = col.length - 1
                        } else {
                            while (innerIndex < col.length && col[innerIndex] & cardutils.FLIP_FLAG) {
                                // Don't select face down cards
                                innerIndex += 1
                            }
                        }

                        return this.select(type, outerIndex, innerIndex)
                    }
                }

            // -------------------------------------------------------------------------------------------
            default:
                // Probably a background click, just forget the selection
                return this.select("none")
        }
    },

    won() {
        return this.state.draw.cards.length === 0 && this.state.pile.cards.length === 0 && this.workPileEmpty()
    }
}

export default mode

function __range__(left, right, inclusive) {
    let range = []
    let ascending = left < right
    let end = !inclusive ? right : ascending ? right + 1 : right - 1
    for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
        range.push(i)
    }
    return range
}
