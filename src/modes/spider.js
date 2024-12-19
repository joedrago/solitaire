/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import * as cardutils from "../cardutils"

const mode = {
    name: "Spider",
    help: `\
| GOAL:

Remove all 104 cards from the tableau by building eight sets of cards in
suit from king to ace. The completed sets are removed from the tableau
immediately.

| PLAY:

Build columns down regardless of suit. Either the topmost card or all
packed cards of the same suit may be moved to another column which meets
the build requirements.

When play comes to a standstill (or sooner if desired), deal the next
group of 10 cards, 1 to each column, then play again if possible. Spaces
in columns may be filled with any available card or build.

There is no redeal.

| HARD MODE:

Easy - Only two suits are represented (52 hearts, 52 spades).

Hard - Two full decks are used (all four suits). Very hard!\
`,

    newGame() {
        let deck
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

        if (this.hard) {
            deck = cardutils.shuffle(__range__(0, 52, false).concat(__range__(0, 52, false)))
        } else {
            const blacks = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
                .concat([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
                .concat([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
                .concat([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
            const reds = [39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51]
                .concat([39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51])
                .concat([39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51])
                .concat([39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51])
            deck = cardutils.shuffle(reds.concat(blacks))
        }
        for (let columnIndex = 0; columnIndex < 10; columnIndex++) {
            var col = []
            for (var i = 0; i < 4; i++) {
                col.push(deck.shift() | cardutils.FLIP_FLAG)
            }
            col.push(deck.shift())
            this.state.work.push(col)
        }

        return (this.state.draw.cards = deck)
    },

    spiderRemoveSets() {
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
                    var kingInfo = null
                    for (var rawIndex = 0; rawIndex < work.length; rawIndex++) {
                        var raw = work[rawIndex]
                        var info = cardutils.info(raw)
                        if (kingPos >= 0) {
                            if (info.value !== 12 - rawIndex + kingPos || info.suit !== kingInfo.suit) {
                                kingPos = -1
                                kingInfo = null
                            }
                        }

                        if (kingPos < 0) {
                            if (info.value === 12 && !info.flip) {
                                kingPos = rawIndex
                                kingInfo = info
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

    spiderDeal() {
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
            //   @spiderDeal()
            return
        }

        switch (type) {
            // -------------------------------------------------------------------------------------------
            case "draw":
                this.spiderDeal()
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
                        if (lowerInfo.value !== upperInfo.value - 1 || lowerInfo.suit !== upperInfo.suit) {
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

        return this.spiderRemoveSets()
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
