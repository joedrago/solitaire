/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from "../cardutils"

const mode = {
    name: "Spiderette",
    help: `\
| GOAL:

Remove all cards from the tableau by building four sets of cards from king
to ace regardless of suit. The completed sets are removed from the
tableau immediately.

| PLAY:

Build columns down regardless of suit. Either the topmost card or all
packed cards of a column may be moved to another column which meets the
build requirements.

When play comes to a standstill (or sooner if desired), deal the next
group of 7 cards, 1 to each column, then play again if possible. Spaces
in columns may be filled with any available card or build.

There is no redeal.

| HARD MODE:

Easy - 2 cards are dealt face down to columns.

Hard - 3 cards are dealt face down to columns.\
`,

    newGame() {
        this.state = {
            hard: this.hard,
            draw: {
                pos: "bottom",
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
            foundations: [],
            work: []
        }

        const deck = cardutils.shuffle(__range__(0, 52, false))
        const faceDownCount = this.hard ? 3 : 2
        for (let columnIndex = 0; columnIndex < 7; columnIndex++) {
            var col = []
            for (var i = 0, end = faceDownCount, asc = 0 <= end; asc ? i < end : i > end; asc ? i++ : i--) {
                col.push(deck.shift() | cardutils.FLIP_FLAG)
            }
            col.push(deck.shift())
            this.state.work.push(col)
        }

        // @state.work[0] = [18,23,12,11,10,9,8,7,6,5,4,3,2,1]
        // @state.work[1] = [0]

        return (this.state.draw.cards = deck)
    },

    spideretteRemoveSets() {
        return (() => {
            const result = []
            while (true) {
                var foundOne = false
                for (var workIndex = 0; workIndex < this.state.work.length; workIndex++) {
                    var work = this.state.work[workIndex]
                    if (work.length < 13) {
                        // optimization: this can't have a full set in it
                        continue
                    }

                    var kingPos = -1
                    for (var rawIndex = 0; rawIndex < work.length; rawIndex++) {
                        var raw = work[rawIndex]
                        var info = cardutils.info(raw)
                        if (kingPos >= 0) {
                            if (info.value !== 12 - rawIndex + kingPos) {
                                kingPos = -1
                            }
                        }

                        if (kingPos < 0) {
                            if (info.value === 12 && !info.flip) {
                                kingPos = rawIndex
                            }
                        }

                        if (kingPos >= 0 && rawIndex - kingPos === 12) {
                            foundOne = true
                            // @dumpCards "BEFORE REMOVE: ", @state.work[workIndex]
                            this.state.work[workIndex].splice(kingPos, 13)
                            // @dumpCards "AFTER REMOVE: ", @state.work[workIndex]

                            if (this.state.work[workIndex].length > 0) {
                                this.state.work[workIndex][this.state.work[workIndex].length - 1] &= ~cardutils.FLIP_FLAG
                            }
                            break
                        }
                    }
                }

                if (!foundOne) {
                    break
                } else {
                    result.push(undefined)
                }
            }
            return result
        })()
    },

    spideretteDeal() {
        for (let workIndex = 0; workIndex < this.state.work.length; workIndex++) {
            var work = this.state.work[workIndex]
            if (this.state.draw.cards.length === 0) {
                break
            }
            work.push(this.state.draw.cards.pop())
        }

        return this.select("none")
    },

    click(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
        if (isRightClick) {
            //   @spideretteDeal()
            return
        }

        switch (type) {
            // -------------------------------------------------------------------------------------------
            case "draw":
                this.spideretteDeal()
                break

            // -------------------------------------------------------------------------------------------
            case "work":
                // Potential selections or destinations
                var src = this.getSelection()

                var sameWorkPile = this.state.selection.type === "work" && this.state.selection.outerIndex === outerIndex
                if (src.length > 0 && !sameWorkPile) {
                    // Moving into work
                    const dst = this.state.work[outerIndex]

                    if (cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING)) {
                        for (var c of Array.from(src)) {
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
                    if (innerIndex !== col.length - 1) {
                        innerIndex = 0
                    }
                    while (innerIndex < col.length && col[innerIndex] & cardutils.FLIP_FLAG) {
                        // Don't select face down cards
                        innerIndex += 1
                    }

                    const stopIndex = innerIndex
                    innerIndex = col.length - 1
                    while (innerIndex > stopIndex) {
                        var lowerInfo = cardutils.info(col[innerIndex])
                        var upperInfo = cardutils.info(col[innerIndex - 1])
                        if (lowerInfo.value !== upperInfo.value - 1) {
                            break
                        }
                        innerIndex -= 1
                    }

                    this.select(type, outerIndex, innerIndex)
                }
                break

            // -------------------------------------------------------------------------------------------
            default:
                // Probably a background click, just forget the selection
                this.select("none")
        }

        return this.spideretteRemoveSets()
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
