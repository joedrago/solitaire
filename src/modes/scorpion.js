import * as cardutils from "../cardutils"

const mode = {}
mode.name = "Scorpion"
mode.help = `\
| GOAL:

Arrange four sets of cards in suit, from, king down to ace.

| PLAY:

Build columns down and in suit. Any face up card may be moved, along
with all other cards on top of it, to a completely exposed card which
meets the build requirements. Flip face down cards which become exposed
face up.

When play comes to a standstill (or sooner if desired), deal the three
remaining cards of the stock to the first three columns, then continue if
possible. Empty spaces in columns may be filled with any cards.

There is no redeal.

| HARD MODE:

Easy - 2 cards face down in the first 4 columns. Fill empties with any cards.

Hard - 3 cards face down in the first 4 columns. Fill empties with Kings only.\
`

mode.newGame = function () {
    let faceDownCount, faceUpCount
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

    const deck = cardutils.shuffle(cardutils.range(0, 52))
    if (this.hard) {
        faceDownCount = 3
        faceUpCount = 4
    } else {
        faceDownCount = 2
        faceUpCount = 5
    }
    for (let columnIndex = 0; columnIndex < 7; ++columnIndex) {
        var i
        var col = []
        if (columnIndex < 4) {
            for (i = 0; i < faceDownCount; ++i) {
                col.push(deck.shift() | cardutils.FLIP_FLAG)
            }
            for (i = 0; i < faceUpCount; ++i) {
                col.push(deck.shift())
            }
        } else {
            for (i = 0; i < 7; ++i) {
                col.push(deck.shift())
            }
        }
        this.state.work.push(col)
    }

    this.state.draw.cards = deck
}

mode.scorpionDeal = function () {
    for (let workIndex = 0; workIndex < this.state.work.length; ++workIndex) {
        var work = this.state.work[workIndex]
        if (this.state.draw.cards.length == 0) {
            break
        }
        work.push(this.state.draw.cards.pop())
    }

    this.select("none")
}

mode.click = function (type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    if (isRightClick) {
        //   @scorpionDeal()
        return
    }

    switch (type) {
        // -------------------------------------------------------------------------------------------
        case "draw":
            this.scorpionDeal()
            break

        // -------------------------------------------------------------------------------------------
        case "work":
            // Potential selections or destinations
            var src = this.getSelection()

            var sameWorkPile = this.state.selection.type == "work" && this.state.selection.outerIndex == outerIndex
            if (src.length > 0 && !sameWorkPile) {
                // Moving into work
                const dst = this.state.work[outerIndex]

                let validFlags = cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_MATCHING_SUIT
                if (this.state.hard) {
                    validFlags |= cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
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
            break

        // -------------------------------------------------------------------------------------------
        default:
            // Probably a background click, just forget the selection
            this.select("none")
    }
}

mode.won = function () {
    if (this.state.draw.cards.length > 0) {
        return false
    }

    // each work must either be empty or have a perfect 13 card run of same-suit in it
    for (let workIndex = 0; workIndex < this.state.work.length; ++workIndex) {
        var work = this.state.work[workIndex]
        if (work.length == 0) {
            continue
        }
        if (work.length != 13) {
            // console.log "column #{workIndex} isnt 13 cards"
            return false
        }
        for (var cIndex = 0; cIndex < work.length; ++cIndex) {
            var c = work[cIndex]
            var info = cardutils.info(c)
            if (info.flip) {
                return false
            }
            if (info.value != 12 - cIndex) {
                // console.log "column #{workIndex} card #{cIndex} breaks the pattern"
                return false
            }
        }
    }
    return true
}

export default mode
