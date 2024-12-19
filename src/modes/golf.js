import * as cardutils from "../cardutils"

const mode = {}

mode.name = "Golf"
mode.help = `\
| GOAL:

Move all cards from the tableau into the foundation pile as fast as possible.

| PLAY:

Choose any card from a column to start the single foundation. Build the foundation pile up OR
down regardless of suit, including wrapping (Aces can stack on Kings and vice versa). Any card
completely exposed may be built on the foundation.

When play comes to a standstill, flip 1 card from the stock to the foundation, then continue if
possible. Repeat until no cards remain in the stock.

There is no redeal.

| HARD MODE:

Easy - 7 columns of 5 cards each.

Hard - 6 columns of 6 cards each.\
`

mode.newGame = function () {
    let cardCount, columnCount
    this.state = {
        hard: this.hard,
        draw: {
            pos: "middle",
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
        work: [],
        timerStart: null,
        timerEnd: null,
        timerColor: "#fff"
    }

    const deck = cardutils.shuffle(cardutils.range(0, 52))

    if (this.hard) {
        columnCount = 6
        cardCount = 6
    } else {
        columnCount = 7
        cardCount = 5
    }
    const faceDownCount = this.hard ? 3 : 2
    for (
        let columnIndex = 0, end = columnCount, asc = 0 <= end;
        asc ? columnIndex < end : columnIndex > end;
        asc ? columnIndex++ : columnIndex--
    ) {
        var col = []
        for (var i = 0, end1 = cardCount, asc1 = 0 <= end1; asc1 ? i < end1 : i > end1; asc1 ? i++ : i--) {
            col.push(deck.shift())
        }
        this.state.work.push(col)
    }

    this.state.draw.cards = deck
}

mode.golfCanPlay = function (raw) {
    if (this.state.pile.cards.length == 0) {
        return true
    } else {
        const srcInfo = cardutils.info(raw)
        const dstInfo = cardutils.info(this.state.pile.cards[this.state.pile.cards.length - 1])
        if (Math.abs(srcInfo.value - dstInfo.value) == 1) {
            return true
        } else if (Math.abs(srcInfo.value - dstInfo.value) == 12) {
            // Wrapping
            return true
        }
    }
    return false
}

mode.golfHasPlays = function () {
    for (let colIndex = 0; colIndex < this.state.work.length; colIndex++) {
        var col = this.state.work[colIndex]
        if (col.length > 0 && this.golfCanPlay(col[col.length - 1])) {
            return true
        }
    }
    return false
}

mode.click = function (type, outerIndex, innerIndex, isRightClick, isMouseUp) {
    this.select("none")

    const pileWasEmpty = this.state.pile.cards.length == 0

    switch (type) {
        // -------------------------------------------------------------------------------------------
        case "draw":
            if (this.state.draw.cards.length > 0) {
                this.state.pile.cards.push(this.state.draw.cards.shift())
            }
            break

        // -------------------------------------------------------------------------------------------
        case "work":
            var col = this.state.work[outerIndex]
            if (col.length > 0) {
                const src = col[col.length - 1]
                if (this.golfCanPlay(src)) {
                    this.state.pile.cards.push(col.pop())
                }
            }
            break
    }

    // -------------------------------------------------------------------------------------------

    if (pileWasEmpty && this.state.pile.cards.length > 0) {
        this.state.timerStart = cardutils.now()
    } else if (this.state.timerEnd == null) {
        if (this.workPileEmpty()) {
            this.state.timerEnd = cardutils.now()
            this.state.timerColor = "#3f3"
        } else if (this.state.draw.cards.length == 0 && !this.golfHasPlays()) {
            this.state.timerEnd = cardutils.now()
            this.state.timerColor = "#ff0"
        }
    }
}

mode.won = function () {
    return this.workPileEmpty()
}

mode.lost = function () {
    return this.state.timerEnd != null && !this.workPileEmpty()
}

export default mode
