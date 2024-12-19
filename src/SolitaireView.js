/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
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
let MINIMUM_SCALE_IN_CARD_HEIGHTS = 12
let tmpMinScale = cardutils.qs("min")
if (tmpMinScale != null) {
    tmpMinScale = parseInt(tmpMinScale)
    if (tmpMinScale >= 1) {
        MINIMUM_SCALE_IN_CARD_HEIGHTS = tmpMinScale
    }
}

const noop = function () {}

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
        this.tweening = false
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
        return (this.cardInfos = {})
    }

    cardKey(type, outerIndex, innerIndex) {
        return `${type}/${innerIndex}/${outerIndex}`
    }

    renderCard(cardInfo, renderInfo, listenerInfo) {
        this.renderedCards.push(render.card(cardInfo, renderInfo, listenerInfo))
        return (this.cardInfos[this.cardKey(cardInfo.type, cardInfo.outerIndex, cardInfo.innerIndex)] = cardInfo)
    }

    resetSelectState() {
        return this.setState({
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
            if (this.tooCloseToDrag() || this.props.gameState.selection.type === "none") {
                return
            }
        }

        this.props.app.gameClick(type, outerIndex, innerIndex, isRightClick, isMouseUp)

        if (!isMouseUp) {
            ;({ type } = this.props.app.state.gameState.selection)
            if (type !== "none") {
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

                return this.setState({
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
        return this.setState({
            selectOffsetX: newOffSetX,
            selectOffsetY: newOffSetY,
            selectMaxOffsetX: newMaxX,
            selectMaxOffsetY: newMaxY
        })
    }

    onBackground(isRightClick) {
        this.resetSelectState()
        return this.props.app.gameClick("background", 0, 0, isRightClick, false)
    }

    adjustTimer(gameState) {
        if (gameState.timerStart != null && gameState.timerEnd == null) {
            if (this.timer == null) {
                return (this.timer = setInterval(() => {
                    return this.setState({
                        now: cardutils.now()
                    })
                }, 500))
            }
        } else {
            if (this.timer != null) {
                clearInterval(this.timer)
                return (this.timer = null)
            }
        }
    }

    prettyTime(t, showMS) {
        if (showMS == null) {
            showMS = false
        }
        const zp = function (t) {
            if (t < 10) {
                return "0" + t
            }
            return String(t)
        }
        const zpp = function (t) {
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
            return window.requestAnimationFrame(this.onAutowin.bind(this))
        }
    }

    toggleAutowin() {
        this.autowinInterval = !this.autowinInterval

        if (this.autowinInterval) {
            window.requestAnimationFrame(this.onAutowin.bind(this))
        }

        return this.setState({
            now: cardutils.now(),
            sent: null
        })
    }

    onTween() {
        // console.log "onTween #{cardutils.now()}"
        this.setState({
            now: cardutils.now()
        })
        if (this.props.app.tweens && this.props.app.tweens.length > 0) {
            return window.requestAnimationFrame(this.onTween.bind(this))
        } else {
            return (this.tweening = false)
        }
    }

    calcArrowAngle(srcX, srcY, dstX, dstY) {
        const dx = dstX - srcX
        const dy = dstY - srcY

        if (dx === -1 && dy === 0) {
            return 180
        }
        if (dx === -1 && dy === -1) {
            return -135
        }
        if (dx === 0 && dy === -1) {
            return -90
        }
        if (dx === 1 && dy === -1) {
            return -45
        }
        if (dx === 1 && dy === 0) {
            return 0
        }
        if (dx === 1 && dy === 1) {
            return 45
        }
        if (dx === 0 && dy === 1) {
            return 90
        }
        if (dx === -1 && dy === 1) {
            return 135
        }
        return null
    }

    render() {
        let cardInfo,
            colIndex,
            drawCard,
            drawOffsetL,
            drawOffsetT,
            grid,
            isSelected,
            raw,
            renderOffsetL,
            renderScale,
            rowIndex,
            wideGrid
        const { gameState } = this.props
        this.adjustTimer(gameState)

        // Calculate necessary table extents, pretending a card is 1.0 units tall
        // "top area"  = top draw pile, foundation piles (both can be absent)
        // "work area" = work piles

        let largestWork = 3
        if (!this.props.useTouch) {
            largestWork = MINIMUM_SCALE_IN_CARD_HEIGHTS
        }
        for (var w of Array.from(gameState.work)) {
            if (largestWork < w.length) {
                largestWork = w.length
            }
        }

        let topWidth = gameState.foundations.length
        const foundationOffsetL = gameState.work.length - gameState.foundations.length
        topWidth += foundationOffsetL

        const workWidth = gameState.work.length

        let workTop = 0
        if (gameState.draw.pos === "top" || gameState.foundations.length > 0) {
            workTop = 1.25
        }
        let workBottom = workTop + 1 + (largestWork - 1) * WORK_CARD_OVERLAP
        if (
            workBottom < 4.1 &&
            (gameState.draw.pos === "middle" || (gameState.reserve != null && gameState.reserve.pos === "middle"))
        ) {
            // Leave room for draw/reserve at the bottom of the screen
            workBottom = 4.1
        }

        let maxWidth = topWidth
        if (maxWidth < workWidth) {
            maxWidth = workWidth
        }
        let maxHeight = workBottom

        const boardAspectRatio = this.props.width / this.props.height
        if (gameState.grid != null) {
            maxWidth = 6.8
            maxHeight = 5.5

            if (boardAspectRatio > 1.45) {
                // arbitrary, pick something better, probs based on the post-add ratio
                wideGrid = true
                maxWidth += 3
            } else {
                wideGrid = false
                maxHeight += 1
            }

            console.log(`boardAspectRatio: ${boardAspectRatio}, wideGrid: ${wideGrid}`)
        }
        const maxAspectRatio = maxWidth / maxHeight

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
        let renderOffsetT = this.renderScalePixels * 0.1

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
        if (gameState.draw.pos === "top" || gameState.draw.pos === "middle") {
            if (gameState.draw.pos === "top") {
                drawOffsetL = 0
                drawOffsetT = 0
            } else if (gameState.reserve != null && gameState.reserve.pos === "middle") {
                drawOffsetL = 1 * this.renderScalePixels
                drawOffsetT = 3 * this.renderScalePixels
            } else {
                drawOffsetL = (maxWidth / 2 - 1) * this.renderScalePixels
                drawOffsetT = 2.3 * this.renderScalePixels
            }
            // Top Left Draw Pile
            drawCard = cardutils.BACK
            if (gameState.draw.cards.length === 0) {
                drawCard = cardutils.READY
                if (gameState.draw.redeals === 0) {
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
                var pile = gameState.pile.cards[pileIndex]
                isSelected = false
                if (gameState.selection.type === "pile" && pileIndex === gameState.pile.cards.length - 1) {
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
                    return this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(pile, pileIndex, isSelected)
            }
        }

        let currentL = renderOffsetL + CENTER_CARD_MARGIN * this.renderScalePixels
        for (let workColumnIndex = 0; workColumnIndex < gameState.work.length; workColumnIndex++) {
            var workColumn = gameState.work[workColumnIndex]
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
                return this.renderCard(cardInfo, renderInfo, listenerInfo)
            })(workColumnIndex, workIndex)
            for (var workIndex = 0; workIndex < workColumn.length; workIndex++) {
                var work = workColumn[workIndex]
                isSelected = false
                if (
                    gameState.selection.type === "work" &&
                    workColumnIndex === gameState.selection.outerIndex &&
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
                    return this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(work, workColumnIndex, workIndex, isSelected)
            }
            currentL += this.renderScalePixels
        }

        currentL = renderOffsetL + (foundationOffsetL + CENTER_CARD_MARGIN) * this.renderScalePixels
        for (let foundationIndex = 0; foundationIndex < gameState.foundations.length; foundationIndex++) {
            var foundation = gameState.foundations[foundationIndex]
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
                return this.renderCard(cardInfo, renderInfo, listenerInfo)
            })(foundation, foundationIndex)
            if (
                this.state.sent != null &&
                this.state.sent.foundationIndex === foundationIndex &&
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
                    return this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(foundation, foundationIndex)
            }
            if (foundation !== cardutils.GUIDE) {
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
                    return this.renderCard(cardInfo, renderInfo, listenerInfo)
                })(foundation, foundationIndex)
            }
            currentL += this.renderScalePixels
        }

        if (gameState.draw.pos === "bottom") {
            // Bottom Left Draw Pile
            drawCard = cardutils.BACK
            if (gameState.draw.cards.length === 0) {
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
            if (gameState.reserve.pos === "middle") {
                drawOffsetL = (maxWidth / 2 - 0.5) * this.renderScalePixels
                drawOffsetT = 3 * this.renderScalePixels
            } else {
                drawOffsetL = 0
                drawOffsetT = 0
            }

            for (colIndex = 0; colIndex < gameState.reserve.cols.length; colIndex++) {
                var col = gameState.reserve.cols[colIndex]
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
                    var reserveIndex = col.length - 1
                    isSelected = false
                    if (
                        gameState.selection.type === "reserve" &&
                        colIndex === gameState.selection.outerIndex &&
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
                            return this.toggleAutowin()
                        }
                    },
                    [el(PlayIcon, { key: "autowinIcon" })]
                )
            )
        }

        if (gameState.grid != null) {
            let asc1, end1
            let asc2, end2
            let asc3, end3
            if (gameState.log != null && gameState.log.length > 0) {
                let logL, logT
                const logTextSize = this.renderScalePixels * 0.13
                if (wideGrid) {
                    logL = renderOffsetL + this.renderScalePixels * 6.1
                    logT =
                        renderOffsetT +
                        this.renderScalePixels * ((render.CARD_HEIGHT - render.CARD_WIDTH) / render.CARD_HEIGHT) +
                        logTextSize
                } else {
                    logL = renderOffsetL
                    logT = renderOffsetT + (cardutils.MAXLOG - gameState.log.length) * logTextSize
                }
                for (let logIndex = 0; logIndex < gameState.log.length; logIndex++) {
                    var logEntry = gameState.log[logIndex]
                    this.renderedCards.push(
                        el(
                            "div",
                            {
                                key: `logEntry${logIndex}`,
                                style: {
                                    color: logEntry.color,
                                    position: "fixed",
                                    left: logL + (this.renderScalePixels * render.CARD_WIDTH) / render.CARD_HEIGHT,
                                    top: logT + logIndex * logTextSize,
                                    fontSize: `${logTextSize}px`,
                                    fontWeight: 900,
                                    fontFamily: "monospace",
                                    pointerEvents: "none"
                                }
                            },
                            [`* ${logEntry.text}`]
                        )
                    )
                }
            }

            // hack: how bad is this?
            if (!wideGrid) {
                renderOffsetT += this.renderScalePixels
            }

            ;({ grid } = gameState)
            if (this.props.app.tweens != null && this.props.app.tweens.length > 0 && this.props.app.tweens[0].grid != null) {
                // The fake grid snapshot from the past, for animations
                ;({ grid } = this.props.app.tweens[0])
            }
            for (
                colIndex = 0, end1 = grid.length, asc1 = 0 <= end1;
                asc1 ? colIndex < end1 : colIndex > end1;
                asc1 ? colIndex++ : colIndex--
            ) {
                cardInfo = {
                    key: `gridcolguide${colIndex}`,
                    raw: cardutils.ROAD,
                    x: renderOffsetL + this.renderScalePixels * (colIndex + 1 - CENTER_CARD_MARGIN),
                    y: renderOffsetT + this.renderScalePixels * CENTER_CARD_MARGIN * 2,
                    selected: false,
                    type: "background",
                    outerIndex: 0,
                    innerIndex: 0,
                    rotate: 90
                }
                this.renderCard(cardInfo, renderInfo, listenerInfo)
            }
            for (
                rowIndex = 0, end2 = grid[0].length, asc2 = 0 <= end2;
                asc2 ? rowIndex < end2 : rowIndex > end2;
                asc2 ? rowIndex++ : rowIndex--
            ) {
                raw = cardutils.ROAD
                if (gameState.tank[rowIndex]) {
                    raw = cardutils.TANK
                }
                cardInfo = {
                    key: `gridrowguide${rowIndex}`,
                    raw,
                    x: renderOffsetL - this.renderScalePixels * 0.01,
                    y: renderOffsetT + this.renderScalePixels * (rowIndex + 1 + CENTER_CARD_MARGIN),
                    selected: false,
                    type: "background",
                    outerIndex: 0,
                    innerIndex: 0
                }
                this.renderCard(cardInfo, renderInfo, listenerInfo)
            }

            for (
                colIndex = 0, end3 = grid.length, asc3 = 0 <= end3;
                asc3 ? colIndex < end3 : colIndex > end3;
                asc3 ? colIndex++ : colIndex--
            ) {
                var asc4, end4
                for (
                    rowIndex = 0, end4 = grid[0].length, asc4 = 0 <= end4;
                    asc4 ? rowIndex < end4 : rowIndex > end4;
                    asc4 ? rowIndex++ : rowIndex--
                ) {
                    if (grid[colIndex][rowIndex].flare) {
                        cardInfo = {
                            key: `gridflarebg${colIndex}${rowIndex}`,
                            raw: cardutils.FLAREBG,
                            x: renderOffsetL + this.renderScalePixels * (colIndex + 1 - CENTER_CARD_MARGIN),
                            y: renderOffsetT + this.renderScalePixels * (rowIndex + 1 + CENTER_CARD_MARGIN),
                            selected: false,
                            type: "grid",
                            outerIndex: colIndex,
                            innerIndex: rowIndex
                        }
                        this.renderCard(cardInfo, renderInfo, listenerInfo)
                    }
                    isSelected = false
                    if (
                        gameState.selection.type === "grid" &&
                        colIndex === gameState.selection.outerIndex &&
                        rowIndex === gameState.selection.innerIndex
                    ) {
                        isSelected = true
                    }
                    raw = cardutils.GRID
                    cardInfo = {
                        key: `grid${colIndex}${rowIndex}`,
                        raw: cardutils.GRID,
                        x: renderOffsetL + this.renderScalePixels * (colIndex + 1 - CENTER_CARD_MARGIN),
                        y: renderOffsetT + this.renderScalePixels * (rowIndex + 1 + CENTER_CARD_MARGIN),
                        selected: isSelected,
                        type: "grid",
                        outerIndex: colIndex,
                        innerIndex: rowIndex
                    }
                    if (grid[colIndex][rowIndex].squad != null) {
                        cardInfo.raw = grid[colIndex][rowIndex].squad.raw
                        if (grid[colIndex][rowIndex].squad.tapped) {
                            cardInfo.rotate = 90
                        }
                        if (grid[colIndex][rowIndex].squad.down) {
                            cardInfo.filter = "hue-rotate(180deg)"
                        }
                    }
                    if (grid[colIndex][rowIndex].bad != null) {
                        cardInfo.raw = grid[colIndex][rowIndex].bad
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)

                    var sq = grid[colIndex][rowIndex].squad
                    if (sq != null && !isSelected && sq.tx >= 0) {
                        var arrowAngle = this.calcArrowAngle(colIndex, rowIndex, sq.tx, sq.ty)
                        if (arrowAngle != null) {
                            this.renderedCards.push(
                                el("img", {
                                    key: `gridarrow${colIndex}${rowIndex}`,
                                    src: render.arrow,
                                    style: {
                                        position: "fixed",
                                        left: cardInfo.x,
                                        width: renderScale * render.CARD_WIDTH,
                                        height: renderScale * render.CARD_WIDTH,
                                        transform: `rotate(${arrowAngle}deg)`,
                                        top: cardInfo.y,
                                        opacity: 0.7,
                                        pointerEvents: "none"
                                    }
                                })
                            )
                        }
                    }
                }
            }

            if (gameState.phase != null) {
                let phaseName = gameState.phase
                let phaseColor = "#fff"
                if (gameState.lastRound) {
                    phaseColor = "#ff0"
                }
                if (this.props.app.tweens != null && this.props.app.tweens.length > 0 && this.props.app.tweens[0].phase != null) {
                    phaseName = this.props.app.tweens[0].phase
                }
                this.renderedCards.push(
                    el(
                        "div",
                        {
                            key: "next",
                            style: {
                                position: "fixed",
                                textAlign: "center",
                                left: renderOffsetL,
                                width: renderScale * render.CARD_WIDTH,
                                height: renderScale * render.CARD_WIDTH,
                                lineHeight: `${renderScale * render.CARD_WIDTH}px`,
                                top:
                                    renderOffsetT +
                                    this.renderScalePixels * (1 + CENTER_CARD_MARGIN) -
                                    renderScale * render.CARD_WIDTH,
                                fontFamily: "monospace",
                                fontSize: `${this.renderScalePixels * 0.12}px`,
                                color: phaseColor,
                                textShadow: "2px 2px #000"
                            },
                            onMouseDown: (ev) => {
                                ev.stopPropagation()
                                return this.props.app.phase()
                            },
                            onMouseUp(ev) {
                                return ev.stopPropagation()
                            }
                        },
                        [phaseName]
                    )
                )
            }
        }

        if (this.props.app.tweens != null && this.props.app.tweens.length > 0) {
            let tween
            if (!this.tweening) {
                this.tweening = true
                window.requestAnimationFrame(this.onTween.bind(this))
            }
            const processID = this.props.app.tweens[0].id
            for (let tweenIndex = 0; tweenIndex < this.props.app.tweens.length; tweenIndex++) {
                tween = this.props.app.tweens[tweenIndex]
                if (tween.id !== processID) {
                    break
                }
                if (tween.start == null) {
                    tween.start = cardutils.now()
                }
                var now = cardutils.now()
                var p = 1 - (tween.start + tween.d - now) / tween.d
                if (p > 1) {
                    console.log("Tween finished:", tween)
                    tween.done = true
                } else {
                    // render tween!
                    var o, r
                    var sx = renderOffsetL + this.renderScalePixels * (tween.sx + 1 - CENTER_CARD_MARGIN)
                    var sy = renderOffsetT + this.renderScalePixels * (tween.sy + 1 + CENTER_CARD_MARGIN)
                    var dx = renderOffsetL + this.renderScalePixels * (tween.dx + 1 - CENTER_CARD_MARGIN)
                    var dy = renderOffsetT + this.renderScalePixels * (tween.dy + 1 + CENTER_CARD_MARGIN)

                    var px = sx + (dx - sx) * p
                    var py = sy + (dy - sy) * p

                    if (tween.sr != null && tween.dr != null) {
                        r = tween.sr + (tween.dr - tween.sr) * p
                    } else {
                        r = null
                    }
                    if (tween.so != null && tween.do != null) {
                        o = tween.so + (tween.do - tween.so) * p
                    } else {
                        o = null
                    }

                    cardInfo = {
                        key: `twen${processID}${tweenIndex}`,
                        raw: tween.raw,
                        x: px,
                        y: py,
                        selected: isSelected,
                        type: "grid",
                        outerIndex: colIndex,
                        innerIndex: rowIndex
                    }
                    if (r != null) {
                        cardInfo.rotate = r
                    }
                    if (o != null) {
                        cardInfo.opacity = o
                    }
                    this.renderCard(cardInfo, renderInfo, listenerInfo)
                }
            }

            const remainingTweens = []
            for (tween of Array.from(this.props.app.tweens)) {
                if (!tween.done) {
                    remainingTweens.push(tween)
                }
            }
            this.props.app.tweens = remainingTweens
        }

        let bgColor = "#363"
        if (gameState.grid != null) {
            bgColor = "#666"
        }

        const bgProps = {
            key: "bg",
            style: {
                zIndex: -1,
                backgroundColor: bgColor,
                width: this.props.width,
                height: this.props.height
            }
        }

        if (this.props.useTouch) {
            bgProps.onTouchStart = (e) => {
                if (e.touches.length === 1) {
                    return this.onBackground(false)
                }
            }
            bgProps.onTouchEnd = (e) => {
                if (e.touches.length === 0) {
                    return this.onBackground(false)
                }
            }
            bgProps.onTouchMove = (e) => {
                if (e.touches.length === 1) {
                    return this.onMouseMove(e.touches[0].clientX, e.touches[0].clientY)
                }
            }
        } else {
            bgProps.onContextMenu = (e) => {
                return e.preventDefault()
            }
            // @onBackground(true)
            bgProps.onMouseDown = () => {
                return this.onBackground(false)
            }
            bgProps.onMouseUp = () => {
                return this.onBackground(false)
            }
            bgProps.onMouseMove = (e) => {
                return this.onMouseMove(e.clientX, e.clientY)
            }
        }

        return el("div", bgProps, this.renderedCards)
    }
}

export default SolitaireView
