/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS202: Simplify dynamic range loops
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from "../cardutils"

const mode = {}

mode.name = "Freecell"
mode.help = `\
| GOAL:

Build the foundations up in suit from ace to king.

| PLAY:

Columns are built down in alternating colors. Cards on the bottom of a
column can be moved to a cell to gain access to cards below it, but at a
cost.

Cards that are descending and in suit may be moved all at once, but the
max count of cards that can be moved at a single time is based on how
many cells are free and how many columns are empty. You're always allowed
to move a single card (1) plus an additional card for every free cell.
This number is then doubled for every empty column.

The max count able to be moved is displayed between the cells and
foundations for your convenience.

The topmost card of any column or cell may be moved to a foundation. Cards
in a cell may also be moved to a foundation.

| HARD MODE:

Easy - There are four cells.

Hard - There are only two cells.\
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
        work: [],
        reserve: {
            pos: "top",
            cols: []
        }
    }

    let cellCount = 4
    if (this.hard) {
        cellCount = 2
    }
    for (let c = 0; c < cellCount; ++c) {
        this.state.reserve.cols.push([])
    }

    const deck = cardutils.shuffle(cardutils.range(0, 52))
    for (let columnIndex = 0; columnIndex < 8; ++columnIndex) {
        var col = []
        var colCount = 6
        if (columnIndex < 4) {
            colCount += 1
        }
        for (var i = 0; i < colCount; ++i) {
            col.push(deck.shift())
        }
        this.state.work.push(col)
    }

    this.state.draw.cards = deck
    this.freecellUpdateCount()
}

mode.freecellUpdateCount = function () {
    let col
    let count = 1
    for (col of this.state.reserve.cols) {
        if (col.length == 0) {
            count += 1
        }
    }

    for (col of this.state.work) {
        if (col.length == 0) {
            count *= 2
        }
    }

    if (count > 52) {
        count = 52
    }

    this.state.centerDisplay = `${count}`
    return count
}

mode.click = function (type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    let col
    if (isRightClick) {
        if (!isMouseUp) {
            this.sendHome(type, outerIndex, innerIndex)
            this.freecellUpdateCount()
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
            var src = this.getSelection()

            while (true) {
                // create a gauntlet of breaks. if we survive them all, move the card
                if (src.length != 1) {
                    break
                }
                var srcInfo = cardutils.info(src[0])
                if (this.state.foundations[outerIndex] < 0) {
                    // empty
                    if (srcInfo.value != 0) {
                        // Ace
                        break
                    }
                } else {
                    var dstInfo = cardutils.info(this.state.foundations[outerIndex])
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
            break

        // -----------------------------------------------------------------------------------------
        case "reserve":
            src = this.getSelection()

            var srcIsDest = this.state.selection.type == "reserve" && this.state.selection.outerIndex == outerIndex
            if (src.length > 0 && !srcIsDest) {
                // Moving into reserve
                if (src.length == 1 && this.state.reserve.cols[outerIndex].length == 0) {
                    this.state.reserve.cols[outerIndex].push(src[0])
                    this.eatSelection()
                }
                this.select("none")
            } else {
                // Selecting a reserve card
                col = this.state.reserve.cols[outerIndex]
                if (col.length > 0) {
                    this.select("reserve", outerIndex, col.length - 1)
                } else {
                    this.select("none")
                }
            }
            break

        // ---------------------------------------------------------------------------------------
        case "work":
            src = this.getSelection()

            srcIsDest = this.state.selection.type == "work" && this.state.selection.outerIndex == outerIndex
            if (src.length > 0 && !srcIsDest) {
                // Moving into work

                if (this.state.selection.foundationOnly) {
                    this.select("none")
                    return
                }

                const dst = this.state.work[outerIndex]
                if (cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR)) {
                    for (var c of src) {
                        dst.push(c)
                    }
                    this.eatSelection()
                }

                this.select("none")
            } else if (srcIsDest && isMouseUp) {
                this.select("none")
            } else {
                // Selecting a fresh column
                col = this.state.work[outerIndex]

                const stopIndex = innerIndex
                innerIndex = col.length - 1
                while (innerIndex > stopIndex) {
                    var lowerInfo = cardutils.info(col[innerIndex])
                    var upperInfo = cardutils.info(col[innerIndex - 1])
                    if (lowerInfo.value != upperInfo.value - 1 || lowerInfo.red == upperInfo.red) {
                        break
                    }
                    innerIndex -= 1
                }

                const maxCount = this.freecellUpdateCount()
                while (col.length - innerIndex > maxCount) {
                    innerIndex += 1
                }

                this.select(type, outerIndex, innerIndex)
            }
            break

        // -------------------------------------------------------------------------------------------
        default:
            // Probably a background click, just forget the selection
            this.select("none")
    }

    this.freecellUpdateCount()
}

mode.won = function () {
    return this.workPileEmpty() && this.reserveEmpty()
}

export default mode
