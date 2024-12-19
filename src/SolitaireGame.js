import * as cardutils from "./cardutils"

// -------------------------------------------------------------------------------------------------

class SolitaireGame {
    constructor() {
        this.saveTimeout = null
        this.state = null
        this.mode = "klondike"
        this.hard = false // this is the toggle for the *next* game. Check @state.hard to see if *this* game is hard
        this.undoStack = []

        this.modes = {}
        this.loadMode("baker")
        this.loadMode("eagle")
        this.loadMode("emperor")
        this.loadMode("freecell")
        this.loadMode("golf")
        this.loadMode("klondike")
        this.loadMode("scorpion")
        this.loadMode("spider")
        this.loadMode("spiderette")
        this.loadMode("yukon")

        if (!this.load()) {
            this.newGame()
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Mode Manipulation

    loadMode(modeName) {
        const modeFuncs = {
            newGame: true,
            click: true,
            won: true,
            lost: true
        }

        const modeProps = {
            name: true,
            help: true
        }

        const m = require(`./modes/${modeName}`).default
        this.modes[modeName] = {}

        for (let key in m) {
            let val = m[key]
            if (modeFuncs[key]) {
                this.modes[modeName][key] = val.bind(this)
            } else if (modeProps[key]) {
                this.modes[modeName][key] = val
            } else {
                this[key] = val.bind(this)
            }
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Generic input handlers

    load() {
        // return false

        let payload
        const rawPayload = localStorage.getItem("save")
        if (rawPayload == null) {
            return false
        }

        try {
            payload = JSON.parse(rawPayload)
        } catch (error) {
            return false
        }

        this.mode = payload.mode
        this.hard = payload.hard == true
        this.state = payload.state
        this.undoStack = []
        console.log("Loaded.")
        return true
    }

    save() {
        // return

        const payload = {
            mode: this.mode,
            hard: this.hard,
            state: this.state
        }
        localStorage.setItem("save", JSON.stringify(payload))
        // console.log "Saved."
    }

    queueSave() {
        // Don't bother queueing, just save immediately
        this.save()

        // if @saveTimeout?
        //   clearTimeout(@saveTimeout)
        // @saveTimeout = setTimeout =>
        //   @save()
        //   @saveTimeout = null
        // , 3000
    }

    // -----------------------------------------------------------------------------------------------
    // Undo

    canUndo() {
        return this.undoStack.length > 0
    }

    pushUndo() {
        this.undoStack.push(JSON.stringify(this.state))
    }

    undo() {
        if (this.undoStack.length > 0) {
            this.state = JSON.parse(this.undoStack.pop())
            this.queueSave()
        }
    }

    // -----------------------------------------------------------------------------------------------
    // Generic input handlers

    newGame(newMode = null) {
        if (newMode != null && this.modes[newMode] != null) {
            this.mode = newMode
        }
        if (this.modes[this.mode] != null) {
            this.modes[this.mode].newGame()
            this.undoStack = []
            this.save()
        }
    }

    click(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
        if (outerIndex == null) {
            outerIndex = 0
        }
        if (innerIndex == null) {
            innerIndex = 0
        }
        if (isRightClick == null) {
            isRightClick = false
        }
        if (isMouseUp == null) {
            isMouseUp = false
        }
        console.log(`game.click(${type}, ${outerIndex}, ${innerIndex}, ${isRightClick}, ${isMouseUp})`)
        if (this.modes[this.mode] != null) {
            if (!isMouseUp) {
                this.pushUndo()
            }
            this.modes[this.mode].click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
            this.queueSave()
        }
    }

    won() {
        if (this.modes[this.mode] != null) {
            return this.modes[this.mode].won()
        }
        return false
    }

    lost() {
        if (this.modes[this.mode] != null && this.modes[this.mode].lost != null) {
            return this.modes[this.mode].lost()
        }
        return false
    }

    // -----------------------------------------------------------------------------------------------
    // Generic helpers

    findFoundationSuitIndex(raw) {
        let f, fIndex
        if (this.state.foundations.length == 0) {
            return -1
        }

        // find a matching suit
        const srcInfo = cardutils.info(raw)
        for (fIndex = 0; fIndex < this.state.foundations.length; ++fIndex) {
            f = this.state.foundations[fIndex]
            if (f >= 0) {
                let dstInfo = cardutils.info(f)
                if (srcInfo.suit == dstInfo.suit && (srcInfo.value == dstInfo.value + 1 || srcInfo.value == dstInfo.value - 12)) {
                    return fIndex
                }
            }
        }

        // find a free slot
        for (fIndex = 0; fIndex < this.state.foundations.length; ++fIndex) {
            f = this.state.foundations[fIndex]
            if (f < 0) {
                return fIndex
            }
        }

        return -1
    }

    dumpCards(prefix, cards) {
        const infos = []
        for (let card of cards) {
            infos.push(cardutils.info(card))
        }
        console.log(prefix, infos)
    }

    workPileEmpty() {
        for (let work of this.state.work) {
            if (work.length > 0) {
                return false
            }
        }
        return true
    }

    reserveEmpty() {
        if (this.state.reserve == null) {
            return true
        }
        for (let cols of this.state.reserve.cols) {
            if (cols.length > 0) {
                return false
            }
        }
        return true
    }

    canAutoWin() {
        let col
        if (this.won()) {
            // console.log "canAutoWin: false (won)"
            return false
        }
        if (this.state.foundations.length == 0) {
            // console.log "canAutoWin: false (no foundations)"
            return false
        }
        if (this.state.draw.cards.length > 0) {
            // console.log "canAutoWin: false (has draw)"
            return false
        }
        if (this.state.pile.cards.length > 0) {
            // console.log "canAutoWin: false (has pile)"
            return false
        }
        if (this.state.reserve != null) {
            for (col of this.state.reserve.cols) {
                if (col.length > 0) {
                    // console.log "canAutoWin: false (has reserves)"
                    return false
                }
            }
        }
        for (let colIndex = 0; colIndex < this.state.work.length; ++colIndex) {
            col = this.state.work[colIndex]
            let last = 100
            for (let raw of col) {
                if (raw & cardutils.FLIP_FLAG) {
                    // console.log "canAutoWin: false (has flip)"
                    return false
                }
                let info = cardutils.info(raw)
                if (info.value > last) {
                    // console.log "canAutoWin: false (not descending #{colIndex})"
                    return false
                }
                last = info.value
            }
        }
        // console.log "canAutoWin: true"
        return true
    }

    sendHome(type, outerIndex, innerIndex) {
        let srcCol
        let src = null
        switch (type) {
            case "pile":
                if (this.state.pile.cards.length > 0) {
                    src = this.state.pile.cards[this.state.pile.cards.length - 1]
                }
                break
            case "reserve":
                if (
                    this.state.reserve != null &&
                    this.state.reserve.cols.length > outerIndex &&
                    this.state.reserve.cols[outerIndex].length > 0
                ) {
                    src = this.state.reserve.cols[outerIndex][this.state.reserve.cols[outerIndex].length - 1]
                }
                break
            case "work":
                srcCol = this.state.work[outerIndex]
                if (innerIndex != srcCol.length - 1) {
                    return false
                }
                src = srcCol[innerIndex]
                break
        }

        if (src == null) {
            return null
        }

        const srcInfo = cardutils.info(src)
        const dstIndex = this.findFoundationSuitIndex(src)
        if (dstIndex >= 0) {
            let sendHome = false
            if (this.state.foundations[dstIndex] >= 0) {
                const dstInfo = cardutils.info(this.state.foundations[dstIndex])
                if (srcInfo.value == dstInfo.value + 1 || srcInfo.value == dstInfo.value - 12) {
                    sendHome = true
                }
            } else {
                let foundationBase = 0 // Ace
                if (this.state.foundationBase != null) {
                    ;({ foundationBase } = this.state)
                }
                if (srcInfo.value == foundationBase) {
                    sendHome = true
                }
            }

            if (sendHome) {
                const prevFoundationRaw = this.state.foundations[dstIndex]
                this.state.foundations[dstIndex] = src
                switch (type) {
                    case "pile":
                        this.state.pile.cards.pop()
                        break
                    case "reserve":
                        this.state.reserve.cols[outerIndex].pop()
                        break
                    case "work":
                        srcCol.pop()
                        if (srcCol.length > 0) {
                            // reveal any face down cards
                            srcCol[srcCol.length - 1] = srcCol[srcCol.length - 1] & ~cardutils.FLIP_FLAG
                        }
                        break
                }
                this.select("none")
                return {
                    raw: src,
                    prevOuterIndex: outerIndex,
                    prevInnerIndex: innerIndex,
                    foundationIndex: dstIndex,
                    prevFoundationRaw
                }
            }
        }
        return null
    }

    sendAny() {
        if (!this.canAutoWin()) {
            return null
        }
        for (let workIndex = 0; workIndex < this.state.work.length; ++workIndex) {
            let work = this.state.work[workIndex]
            if (work.length > 0) {
                let sent = this.sendHome("work", workIndex, work.length - 1)
                if (sent != null) {
                    this.queueSave()
                    return sent
                }
            }
        }
        return null
    }

    // -----------------------------------------------------------------------------------------------
    // Selection

    select(type, outerIndex, innerIndex) {
        if (outerIndex == null) {
            outerIndex = 0
        }
        if (innerIndex == null) {
            innerIndex = 0
        }
        if (
            this.state.selection.type == type &&
            this.state.selection.outerIndex == outerIndex &&
            this.state.selection.innerIndex == innerIndex
        ) {
            // Toggle
            type = "none"
            outerIndex = 0
            innerIndex = 0
        }

        this.state.selection = {
            type,
            outerIndex,
            innerIndex
        }
    }

    eatSelection() {
        switch (this.state.selection.type) {
            case "pile":
                this.state.pile.cards.pop()
                break
            case "reserve":
                if (this.state.reserve != null) {
                    this.state.reserve.cols[this.state.selection.outerIndex].pop()
                }
                break
            case "work":
                let srcCol = this.state.work[this.state.selection.outerIndex]
                if (this.state.selection.innerIndex >= 0) {
                    while (this.state.selection.innerIndex < srcCol.length) {
                        srcCol.pop()
                    }
                }
                if (srcCol.length > 0) {
                    // reveal any face down cards
                    srcCol[srcCol.length - 1] = srcCol[srcCol.length - 1] & ~cardutils.FLIP_FLAG
                }
                break
        }
        this.select("none")
    }

    getSelection() {
        const selectedCards = []
        switch (this.state.selection.type) {
            case "pile":
                if (this.state.pile.cards.length > 0) {
                    selectedCards.push(this.state.pile.cards[this.state.pile.cards.length - 1])
                }
                break
            case "reserve":
                if (this.state.reserve != null) {
                    const col = this.state.reserve.cols[this.state.selection.outerIndex]
                    if (col.length > 0) {
                        selectedCards.push(col[col.length - 1])
                    }
                }
                break
            case "work":
                if (this.state.selection.outerIndex >= 0 && this.state.selection.innerIndex >= 0) {
                    const srcCol = this.state.work[this.state.selection.outerIndex]
                    let index = this.state.selection.innerIndex
                    while (index < srcCol.length) {
                        selectedCards.push(srcCol[index])
                        index += 1
                    }
                }
                break
        }

        return selectedCards
    }
}

// -----------------------------------------------------------------------------------------------

export default SolitaireGame
