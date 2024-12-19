import React, { Component } from "react"
import { el } from "./reactutils"
import * as render from "./render"
import * as cardutils from "./cardutils"

import IconButton from "@mui/material/IconButton"
import PlayIcon from "@mui/icons-material/PlayCircle"

const UNIT = render.CARD_HEIGHT
const PILE_CARD_OVERLAP = 0.105
const WORK_CARD_OVERLAP = 0.25
const CENTER_CARD_MARGIN = (0.5 * (render.CARD_HEIGHT - render.CARD_WIDTH)) / render.CARD_HEIGHT
const CARD_HALF_WIDTH = render.CARD_WIDTH / render.CARD_HEIGHT / 2

const AUTOWIN_RATE_MS = 200

// Coefficient for the height of the card
const TOO_CLOSE_TO_DRAG_NORMALIZED = 0.2

// this represents the *minimum* height the game will scale to
const MINIMUM_SCALE_IN_CARD_HEIGHTS = 12
let tmpMinScale = cardutils.qs("min")
if (tmpMinScale != null) {
    tmpMinScale = parseInt(tmpMinScale)
    if (tmpMinScale >= 1) {
        MINIMUM_SCALE_IN_CARD_HEIGHTS = tmpMinScale
    }
}

const noop = () => {}

class SolitaireView extends Component {
    constructor() {
        super()
        this.state = {
            selectStartX: -1,
            selectStartY: -1,
            selectOffsetX: 0,
            selectOffsetY: 0,
            selectAdditionalOffsetX: 0,
            selectAdditionalOffsetY: 0,
            selectMaxOffsetX: 0,
            selectMaxOffsetY: 0,
            now: 0,
            lastSendAny: 0,
            sent: null
        }

        this.timer = null
        this.autowinInterval = false
    }

    tooCloseToDrag() {
        const dragDistanceSquared =
            this.state.selectMaxOffsetX * this.state.selectMaxOffsetX + this.state.selectMaxOffsetY * this.state.selectMaxOffsetY
        const tooClose = TOO_CLOSE_TO_DRAG_NORMALIZED * this.renderScalePixels
        const tooCloseSquared = tooClose * tooClose
        // console.log "dragDistance: #{Math.sqrt(dragDistanceSquared).toFixed(2)}, tooClose: #{tooClose}"
        return dragDistanceSquared < tooCloseSquared
    }

    forgetCards() {
        this.renderedCards = []
        this.cardInfos = {}
    }

    cardKey(type, outerIndex, innerIndex) {
        return `${type}/${innerIndex}/${outerIndex}`
    }

    renderCard(cardInfo, renderInfo, listenerInfo) {
        this.renderedCards.push(render.card(cardInfo, renderInfo, listenerInfo))
        this.cardInfos[this.cardKey(cardInfo.type, cardInfo.outerIndex, cardInfo.innerIndex)] = cardInfo
    }

    resetSelectState() {
        this.setState({
            selectStartX: -1,
            selectStartY: -1,
            selectOffsetX: 0,
            selectOffsetY: 0,
            selectAdditionalOffsetX: 0,
            selectAdditionalOffsetY: 0,
            selectMaxOffsetX: 0,
            selectMaxOffsetY: 0
        })
    }

    cardClick(type, outerIndex, innerIndex, x, y, isRightClick, isMouseUp) {
        if (isMouseUp) {
            this.resetSelectState()
            if (this.tooCloseToDrag() || this.props.gameState.selection.type == "none") {
                return
            }
        }

        this.props.app.gameClick(type, outerIndex, innerIndex, isRightClick, isMouseUp)

        if (!isMouseUp) {
            ;({ type } = this.props.app.state.gameState.selection)
            if (type != "none") {
                // console.log "gamestate ", @props.app.state.gameState
                ;({ innerIndex } = this.props.app.state.gameState.selection)
                ;({ outerIndex } = this.props.app.state.gameState.selection)

                let selectAdditionalOffsetX = 0
                let selectAdditionalOffsetY = 0
                const cardInfo = this.cardInfos[this.cardKey(type, outerIndex, innerIndex)]
                if (cardInfo != null) {
                    selectAdditionalOffsetX = x - cardInfo.x - this.renderScalePixels * CARD_HALF_WIDTH
                    selectAdditionalOffsetY = y - cardInfo.y - this.renderScalePixels * WORK_CARD_OVERLAP * 0.5
                }

                this.setState({
                    selectStartX: x,
                    selectStartY: y,
                    selectOffsetX: 0,
                    selectOffsetY: 0,
                    selectAdditionalOffsetX,
                    selectAdditionalOffsetY,
                    selectMaxOffsetX: 0,
                    selectMaxOffsetY: 0
                })
            }
        }
    }

    onMouseMove(x, y) {
        if (this.state.selectStartX < 0 || this.state.selectStartY < 0) {
            return
        }
        const newOffSetX = x - this.state.selectStartX
        const newOffSetY = y - this.state.selectStartY
        const newMaxX = Math.max(Math.abs(newOffSetX), this.state.selectMaxOffsetX)
        const newMaxY = Math.max(Math.abs(newOffSetY), this.state.selectMaxOffsetY)
        this.setState({
            selectOffsetX: newOffSetX,
            selectOffsetY: newOffSetY,
            selectMaxOffsetX: newMaxX,
            selectMaxOffsetY: newMaxY
        })
    }

    onBackground(isRightClick) {
        this.resetSelectState()
        this.props.app.gameClick("background", 0, 0, isRightClick, false)
    }

    adjustTimer(gameState) {
        if (gameState.timerStart != null && gameState.timerEnd == null) {
            if (this.timer == null) {
                this.timer = setInterval(() => {
                    this.setState({
                        now: cardutils.now()
                    })
                }, 500)
            }
        } else {
            if (this.timer != null) {
                clearInterval(this.timer)
                this.timer = null
            }
        }
    }

    prettyTime(t, showMS) {
        if (showMS == null) {
            showMS = false
        }
        const zp = (t) => {
            if (t < 10) {
                return "0" + t
            }
            return String(t)
        }
        const zpp = (t) => {
            if (t < 10) {
                return "00" + t
            }
            if (t < 100) {
                return "0" + t
            }
            return String(t)
        }

        const minutes = Math.floor(t / 60000)
        t -= minutes * 60000
        const seconds = Math.floor(t / 1000)
        t -= seconds * 1000
        if (showMS) {
            return `${zp(minutes)}:${zp(seconds)}.${zpp(t)}`
        }
        return `${zp(minutes)}:${zp(seconds)}`
    }

    onAutowin() {
        const now = cardutils.now()
        if (now > this.state.lastSendAny + AUTOWIN_RATE_MS) {
            const sent = this.props.app.sendAny()
            if (sent != null) {
                const cardInfo = this.cardInfos[this.cardKey("work", sent.prevOuterIndex, sent.prevInnerIndex)]
                if (cardInfo != null) {
                    sent.x = cardInfo.x
                    sent.y = cardInfo.y
                } else {
                    sent.x = -1
                    sent.y = -1
                }
                console.log("Sent: ", sent)
            } else if (this.autowinInterval) {
                this.toggleAutowin()
                return
            }
            this.setState({
                lastSendAny: now,
                now,
                sent
            })
        } else {
            this.setState({
                now
            })
        }

        if (this.autowinInterval) {
            window.requestAnimationFrame(this.onAutowin.bind(this))
        }
    }

    toggleAutowin() {
        this.autowinInterval = !this.autowinInterval

        if (this.autowinInterval) {
            window.requestAnimationFrame(this.onAutowin.bind(this))
        }

        this.setState({
            now: cardutils.now(),
            sent: null
        })
    }

    render() {
        let cardInfo, drawCard, drawOffsetL, drawOffsetT, isSelected, renderOffsetL, renderScale
        const { gameState } = this.props
        this.adjustTimer(gameState)

        // Calculate necessary table extents, pretending a card is 1.0 units tall
        // "top area"  = top draw pile, foundation piles (both can be absent)
        // "work area" = work piles

        let largestWork = 3
        if (!this.props.useTouch) {
            largestWork = MINIMUM_SCALE_IN_CARD_HEIGHTS
        }
        for (let w of gameState.work) {
            if (largestWork < w.length) {
                largestWork = w.length
            }
        }

        let topWidth = gameState.foundations.length
        const foundationOffsetL = gameState.work.length - gameState.foundations.length
        topWidth += foundationOffsetL

        const workWidth = gameState.work.length

        let workTop = 0
        if (gameState.draw.pos == "top" || gameState.foundations.length > 0) {
            workTop = 1.25
        }
        let workBottom = workTop + 1 + (largestWork - 1) * WORK_CARD_OVERLAP
        if (
            workBottom < 4.1 &&
            (gameState.draw.pos == "middle" || (gameState.reserve != null && gameState.reserve.pos == "middle"))
        ) {
            // Leave room for draw/reserve at the bottom of the screen
            workBottom = 4.1
        }

        let maxWidth = topWidth
        if (maxWidth < workWidth) {
            maxWidth = workWidth
        }
        const maxHeight = workBottom
        const maxAspectRatio = maxWidth / maxHeight
        const boardAspectRatio = this.props.width / this.props.height

        const maxWidthPixels = maxWidth * UNIT
        const maxHeightPixels = maxHeight * UNIT

        if (maxAspectRatio < boardAspectRatio) {
            // use height for scaling
            renderScale = this.props.height / maxHeightPixels
            renderOffsetL = (this.props.width - maxWidthPixels * renderScale) / 2
        } else {
            // use width for scaling
            renderScale = this.props.width / maxWidthPixels
            renderOffsetL = 0
        }
        this.renderScalePixels = renderScale * UNIT
        const renderOffsetT = this.renderScalePixels * 0.1

        let sentPerc = (this.state.now - this.state.lastSendAny) / AUTOWIN_RATE_MS
        if (sentPerc < 0) {
            sentPerc = 0
        } else if (sentPerc > 1) {
            sentPerc = 1
        }
        const renderInfo = {
            view: this,
            scale: renderScale,
            dragSnapPixels: Math.floor(this.renderScalePixels * 0.1),
            sent: this.state.sent,
            sentPerc
        }
        const listenerInfo = {
            onClick: this.cardClick.bind(this),
            onOther: this.onBackground.bind(this)
        }
        const listenerInfoNoop = {
            onClick: noop,
            onOther: this.onBackground.bind(this)
        }

        this.forgetCards()
        if (gameState.draw.pos == "top" || gameState.draw.pos == "middle") {
            if (gameState.draw.pos == "top") {
                drawOffsetL = 0
                drawOffsetT = 0
            } else if (gameState.reserve != null && gameState.reserve.pos == "middle") {
                drawOffsetL = 1 * this.renderScalePixels
                drawOffsetT = 3 * this.renderScalePixels
            } else {
                drawOffsetL = (maxWidth / 2 - 1) * this.renderScalePixels
                drawOffsetT = 2.3 * this.renderScalePixels
            }
            // Top Left Draw Pile
            drawCard = cardutils.BACK
            if (gameState.draw.cards.length == 0) {
                drawCard = cardutils.READY
                if (gameState.draw.redeals == 0) {
                    drawCard = cardutils.DEAD
                }
            }
            cardInfo = {
                key: "draw",
                raw: drawCard,
                x: drawOffsetL + renderOffsetL + this.renderScalePixels * CENTER_CARD_MARGIN,
                y: drawOffsetT + renderOffsetT,
                selected: false,
                type: "draw",
                outerIndex: 0,
                innerIndex: 0
            }
            this.renderCard(cardInfo, renderInfo, listenerInfo)

            let pileRenderCount = gameState.pile.cards.length
            if (pileRenderCount > gameState.pile.show) {
                pileRenderCount = gameState.pile.show
            }
            const startPileIndex = gameState.pile.cards.length - pileRenderCount

            if (startPileIndex > 0) {
                cardInfo = {
                    key: "pileundercard",
                    raw: gameState.pile.cards[startPileIndex - 1],
                    x: drawOffsetL + renderOffsetL + (1 + CENTER_CARD_MARGIN) * this.renderScalePixels,
                    y: drawOffsetT + renderOffsetT,
                    selected: isSelected,
                    type: "pile",
                    outerIndex: 0,
                    innerIndex: 0
                }
            } else {
                cardInfo = {
                    key: "pileguide",
                    raw: cardutils.GUIDE,
                    x: drawOffsetL + renderOffsetL + (1 + CENTER_CARD_MARGIN) * this.renderScalePixels,
                    y: drawOffsetT + renderOffsetT,
                    selected: false,
                    type: "pile",
                    outerIndex: 0,
                    innerIndex: 0
                }
            }
            this.renderCard(cardInfo, renderInfo, listenerInfoNoop)

            for (
                let pileIndex = startPileIndex, end = gameState.pile.cards.length, asc = startPileIndex <= end;
                asc ? pileIndex < end : pileIndex > end;
                asc ? pileIndex++ : pileIndex--
            ) {
                let pile = gameState.pile.cards[pileIndex]
                isSelected = false
                if (gameState.selection.type == "pile" && pileIndex == gameState.pile.cards.length - 1) {
                    isSelected = true
                }
                ;((pile, pileIndex, isSelected) => {
                    cardInfo = {
                        key: `pile${pileIndex}`,
                        raw: pile,
                        x:
                            drawOffsetL +
                            renderOffsetL +
                            (1 + CENTER_CARD_MARGIN + (pileIndex - startPileIndex) * PILE_CARD_OVERLAP) * this.renderScalePixels,
                        y: drawOffsetT + renderOffsetT,
                        selected: isSelected,
                        type: "pile",
                        outerIndex: pileIndex,
                        innerIndex: 0
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(pile, pileIndex, isSelected)
            }
        }

        let currentL = renderOffsetL + CENTER_CARD_MARGIN * this.renderScalePixels
        for (let workColumnIndex = 0; workColumnIndex < gameState.work.length; workColumnIndex++) {
            let workIndex = 0
            let workColumn = gameState.work[workColumnIndex]
            ;((workColumnIndex, workIndex) => {
                cardInfo = {
                    key: `workguide${workColumnIndex}_${workIndex}`,
                    raw: cardutils.GUIDE,
                    x: currentL,
                    y: workTop * this.renderScalePixels,
                    selected: false,
                    type: "work",
                    outerIndex: workColumnIndex,
                    innerIndex: -1
                }
                this.renderCard(cardInfo, renderInfo, listenerInfo)
            })(workColumnIndex, workIndex)
            for (workIndex = 0; workIndex < workColumn.length; workIndex++) {
                let work = workColumn[workIndex]
                isSelected = false
                if (
                    gameState.selection.type == "work" &&
                    workColumnIndex == gameState.selection.outerIndex &&
                    workIndex >= gameState.selection.innerIndex
                ) {
                    isSelected = true
                    if (gameState.selection.foundationOnly) {
                        isSelected = "foundationOnly"
                    }
                }
                ;((work, workColumnIndex, workIndex, isSelected) => {
                    cardInfo = {
                        key: `work${workColumnIndex}_${workIndex}`,
                        raw: work,
                        x: currentL,
                        y: (workTop + workIndex * WORK_CARD_OVERLAP) * this.renderScalePixels,
                        selected: isSelected,
                        type: "work",
                        outerIndex: workColumnIndex,
                        innerIndex: workIndex
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(work, workColumnIndex, workIndex, isSelected)
            }
            currentL += this.renderScalePixels
        }

        currentL = renderOffsetL + (foundationOffsetL + CENTER_CARD_MARGIN) * this.renderScalePixels
        for (let foundationIndex = 0; foundationIndex < gameState.foundations.length; foundationIndex++) {
            let foundation = gameState.foundations[foundationIndex]
            ;((foundation, foundationIndex) => {
                cardInfo = {
                    key: `foundguide${foundationIndex}`,
                    raw: cardutils.GUIDE,
                    x: currentL,
                    y: renderOffsetT,
                    selected: false,
                    type: "foundation",
                    outerIndex: foundationIndex,
                    innerIndex: 0
                }
                this.renderCard(cardInfo, renderInfo, listenerInfo)
            })(foundation, foundationIndex)
            if (
                this.state.sent != null &&
                this.state.sent.foundationIndex == foundationIndex &&
                this.state.sent.prevFoundationRaw >= 0
            ) {
                ;((foundation, foundationIndex) => {
                    cardInfo = {
                        key: `foundunder${foundationIndex}`,
                        raw: this.state.sent.prevFoundationRaw,
                        x: currentL,
                        y: renderOffsetT,
                        selected: false,
                        type: "foundation",
                        outerIndex: foundationIndex,
                        innerIndex: 0
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(foundation, foundationIndex)
            }
            if (foundation != cardutils.GUIDE) {
                ;((foundation, foundationIndex) => {
                    cardInfo = {
                        key: `found${foundationIndex}`,
                        raw: foundation,
                        x: currentL,
                        y: renderOffsetT,
                        selected: false,
                        type: "foundation",
                        outerIndex: foundationIndex,
                        innerIndex: 0
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(foundation, foundationIndex)
            }
            currentL += this.renderScalePixels
        }

        if (gameState.draw.pos == "bottom") {
            // Bottom Left Draw Pile
            drawCard = cardutils.BACK
            if (gameState.draw.cards.length == 0) {
                drawCard = cardutils.GUIDE
            }

            cardInfo = {
                key: "draw",
                raw: drawCard,
                x: renderOffsetL,
                y: this.props.height - 0.35 * this.renderScalePixels,
                selected: false,
                type: "draw",
                outerIndex: 0,
                innerIndex: 0
            }
            this.renderCard(cardInfo, renderInfo, listenerInfo)
        }

        if (gameState.reserve != null) {
            if (gameState.reserve.pos == "middle") {
                drawOffsetL = (maxWidth / 2 - 0.5) * this.renderScalePixels
                drawOffsetT = 3 * this.renderScalePixels
            } else {
                drawOffsetL = 0
                drawOffsetT = 0
            }

            for (let colIndex = 0; colIndex < gameState.reserve.cols.length; colIndex++) {
                let col = gameState.reserve.cols[colIndex]
                drawCard = cardutils.RESERVE
                if (col.length > 1) {
                    drawCard = col[col.length - 2]
                }
                cardInfo = {
                    key: `reserveguide${colIndex}`,
                    raw: drawCard,
                    x: drawOffsetL + renderOffsetL + this.renderScalePixels * (colIndex + CENTER_CARD_MARGIN),
                    y: drawOffsetT + renderOffsetT,
                    selected: false,
                    type: "reserve",
                    outerIndex: colIndex,
                    innerIndex: -1
                }
                this.renderCard(cardInfo, renderInfo, listenerInfo)

                if (col.length > 0) {
                    let reserveIndex = col.length - 1
                    isSelected = false
                    if (
                        gameState.selection.type == "reserve" &&
                        colIndex == gameState.selection.outerIndex &&
                        reserveIndex >= gameState.selection.innerIndex
                    ) {
                        isSelected = true
                    }
                    cardInfo = {
                        key: `reserve${colIndex}`,
                        raw: col[reserveIndex],
                        x: drawOffsetL + renderOffsetL + this.renderScalePixels * (colIndex + CENTER_CARD_MARGIN),
                        y: drawOffsetT + renderOffsetT,
                        selected: isSelected,
                        type: "reserve",
                        outerIndex: colIndex,
                        innerIndex: reserveIndex
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)
                }
            }
        }

        if (gameState.timerStart != null && gameState.timerColor != null) {
            let endTime = gameState.timerEnd
            if (endTime == null) {
                endTime = cardutils.now()
            }
            const timeToShow = endTime - gameState.timerStart
            this.renderedCards.push(
                el(
                    "div",
                    {
                        key: "timer",
                        style: {
                            position: "fixed",
                            textAlign: "center",
                            left: "0px",
                            width: "100%",
                            top: `${3.5 * this.renderScalePixels}px`,
                            fontFamily: "monospace",
                            fontSize: `${this.renderScalePixels * 0.1}px`,
                            color: gameState.timerColor,
                            textShadow: "2px 2px #000",
                            pointerEvents: "none"
                        }
                    },
                    [this.prettyTime(timeToShow, gameState.timerEnd != null)]
                )
            )
        }

        if (gameState.centerDisplay != null) {
            this.renderedCards.push(
                el(
                    "div",
                    {
                        key: "centerdisplay",
                        style: {
                            position: "fixed",
                            textAlign: "center",
                            left: "0px",
                            width: "100%",
                            top: `${0.5 * this.renderScalePixels}px`,
                            fontFamily: "monospace",
                            fontSize: `${this.renderScalePixels * 0.2}px`,
                            color: "#6a6",
                            textShadow: "2px 2px #000",
                            pointerEvents: "none"
                        }
                    },
                    [gameState.centerDisplay]
                )
            )
        }

        if (this.autowinInterval || this.props.canAutoWin) {
            this.renderedCards.push(
                el(
                    IconButton,
                    {
                        key: "autowinButton",
                        size: "large",
                        style: {
                            position: "fixed",
                            top: "10px",
                            left: "10px",
                            color: this.autowinInterval ? "#afa" : "#aaa"
                        },
                        onClick: () => {
                            this.toggleAutowin()
                        }
                    },
                    [el(PlayIcon, { key: "autowinIcon" })]
                )
            )
        }

        const bgProps = {
            key: "bg",
            style: {
                zIndex: -1,
                backgroundColor: "#363",
                width: this.props.width,
                height: this.props.height
            }
        }

        if (this.props.useTouch) {
            bgProps.onTouchStart = (e) => {
                if (e.touches.length == 1) {
                    this.onBackground(false)
                }
            }
            bgProps.onTouchEnd = (e) => {
                if (e.touches.length == 0) {
                    this.onBackground(false)
                }
            }
            bgProps.onTouchMove = (e) => {
                if (e.touches.length == 1) {
                    this.onMouseMove(e.touches[0].clientX, e.touches[0].clientY)
                }
            }
        } else {
            bgProps.onContextMenu = (e) => {
                e.preventDefault()
                // @onBackground(true)
            }
            bgProps.onMouseDown = () => {
                this.onBackground(false)
            }
            bgProps.onMouseUp = () => {
                this.onBackground(false)
            }
            bgProps.onMouseMove = (e) => {
                this.onMouseMove(e.clientX, e.clientY)
            }
        }

        return el("div", bgProps, this.renderedCards)
    }
}

export default SolitaireView
