/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import { el } from "./reactutils"
import * as cardutils from "./cardutils"

// Vector Playing Cards 3.2
// https://totalnonsense.com/open-source-vector-playing-cards/
// Copyright 2011,2021 – Chris Aguilar – conjurenation@gmail.com
// Licensed under: LGPL 3.0 - https://www.gnu.org/licenses/lgpl-3.0.html
import card0 from "./cards/0.svg"
import card1 from "./cards/1.svg"
import card2 from "./cards/2.svg"
import card3 from "./cards/3.svg"
import card4 from "./cards/4.svg"
import card5 from "./cards/5.svg"
import card6 from "./cards/6.svg"
import card7 from "./cards/7.svg"
import card8 from "./cards/8.svg"
import card9 from "./cards/9.svg"
import card10 from "./cards/10.svg"
import card11 from "./cards/11.svg"
import card12 from "./cards/12.svg"
import card13 from "./cards/13.svg"
import card14 from "./cards/14.svg"
import card15 from "./cards/15.svg"
import card16 from "./cards/16.svg"
import card17 from "./cards/17.svg"
import card18 from "./cards/18.svg"
import card19 from "./cards/19.svg"
import card20 from "./cards/20.svg"
import card21 from "./cards/21.svg"
import card22 from "./cards/22.svg"
import card23 from "./cards/23.svg"
import card24 from "./cards/24.svg"
import card25 from "./cards/25.svg"
import card26 from "./cards/26.svg"
import card27 from "./cards/27.svg"
import card28 from "./cards/28.svg"
import card29 from "./cards/29.svg"
import card30 from "./cards/30.svg"
import card31 from "./cards/31.svg"
import card32 from "./cards/32.svg"
import card33 from "./cards/33.svg"
import card34 from "./cards/34.svg"
import card35 from "./cards/35.svg"
import card36 from "./cards/36.svg"
import card37 from "./cards/37.svg"
import card38 from "./cards/38.svg"
import card39 from "./cards/39.svg"
import card40 from "./cards/40.svg"
import card41 from "./cards/41.svg"
import card42 from "./cards/42.svg"
import card43 from "./cards/43.svg"
import card44 from "./cards/44.svg"
import card45 from "./cards/45.svg"
import card46 from "./cards/46.svg"
import card47 from "./cards/47.svg"
import card48 from "./cards/48.svg"
import card49 from "./cards/49.svg"
import card50 from "./cards/50.svg"
import card51 from "./cards/51.svg"
import cardBack from "./cards/back.svg"
import cardGuide from "./cards/guide.svg"
import cardReserve from "./cards/reserve.svg"
import cardDead from "./cards/dead.svg"
import cardReady from "./cards/ready.svg"

import cardRoad from "./cards/road.png"
import cardGrid from "./cards/grid.png"
import cardAnvil from "./cards/anvil.png"
import cardAthlete from "./cards/athlete.png"
import cardFlare from "./cards/flare.png"
import cardFlareBG from "./cards/flarebg.png"
import cardHammer from "./cards/hammer.png"
import cardInfantry1 from "./cards/infantry1.png"
import cardInfantry2 from "./cards/infantry2.png"
import cardJoker from "./cards/joker.png"
import cardLeader from "./cards/leader.png"
import cardMachinegun from "./cards/machinegun.png"
import cardMortar from "./cards/mortar.png"
import cardNatural from "./cards/natural.png"
import cardPacifist from "./cards/pacifist.png"
import cardTank from "./cards/tank.png"
import cardMouse from "./cards/mouse.png"

import arrowImg from "./cards/arrow.png"

const CARD_URLS = [
    card0,
    card1,
    card2,
    card3,
    card4,
    card5,
    card6,
    card7,
    card8,
    card9,
    card10,
    card11,
    card12,
    card13,
    card14,
    card15,
    card16,
    card17,
    card18,
    card19,
    card20,
    card21,
    card22,
    card23,
    card24,
    card25,
    card26,
    card27,
    card28,
    card29,
    card30,
    card31,
    card32,
    card33,
    card34,
    card35,
    card36,
    card37,
    card38,
    card39,
    card40,
    card41,
    card42,
    card43,
    card44,
    card45,
    card46,
    card47,
    card48,
    card49,
    card50,
    card51
]

const OTHER_CARDS = [cardBack, cardGuide, cardReserve, cardDead, cardReady]

window.solitairePreloadedImages = []
for (let preloadUrl of CARD_URLS.concat(OTHER_CARDS)) {
    // console.log "Preloading: #{preloadUrl}"
    var img = new Image()
    img.src = preloadUrl
    window.solitairePreloadedImages.push(img)
}

export const CARD_WIDTH = 119
export const CARD_HEIGHT = 162
export const CARD_ASPECT_RATIO = CARD_WIDTH / CARD_HEIGHT

export const arrow = arrowImg

const easeInOutQuad = function (x) {
    if (x < 0.5) {
        return 2 * x * x
    } else {
        return 1 - Math.pow(-2 * x + 2, 2) / 2
    }
}

export const card = function (cardInfo, renderInfo, listenerInfo) {
    let suit, url, val
    const { type } = cardInfo
    const { outerIndex } = cardInfo
    const { innerIndex } = cardInfo
    const { onClick } = listenerInfo
    const { onOther } = listenerInfo

    let isSelected = cardInfo.selected
    const foundationOnly = isSelected === "foundationOnly"
    if (foundationOnly) {
        isSelected = true
    }

    let { x } = cardInfo
    let { y } = cardInfo
    if (isSelected) {
        x -= 1
        y -= 1
        if (
            Math.abs(renderInfo.view.state.selectOffsetX) > renderInfo.dragSnapPixels ||
            Math.abs(renderInfo.view.state.selectOffsetY) > renderInfo.dragSnapPixels
        ) {
            x += renderInfo.view.state.selectOffsetX + renderInfo.view.state.selectAdditionalOffsetX
            y += renderInfo.view.state.selectOffsetY + renderInfo.view.state.selectAdditionalOffsetY
        }
    }

    let zIndex = null
    if (renderInfo.sent != null && renderInfo.sent.raw === cardInfo.raw && renderInfo.sent.x >= 0 && renderInfo.sent.y >= 0) {
        const p = easeInOutQuad(renderInfo.sentPerc)
        x += (renderInfo.sent.x - x) * (1 - p)
        y += (renderInfo.sent.y - y) * (1 - renderInfo.sentPerc)
        zIndex = 5
    }

    const cardStyle = {
        position: "fixed",
        left: `${x}px`,
        top: `${y}px`,
        width: CARD_WIDTH * renderInfo.scale,
        height: CARD_HEIGHT * renderInfo.scale,
        transformOrigin: "center"
    }

    if (zIndex != null) {
        cardStyle.zIndex = zIndex
    }

    if (cardInfo.raw === cardutils.GUIDE) {
        url = cardGuide
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.RESERVE) {
        url = cardReserve
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.DEAD) {
        url = cardDead
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.READY) {
        url = cardReady
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.ROAD) {
        url = cardRoad
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.ANVIL) {
        url = cardAnvil
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.ATHLETE) {
        url = cardAthlete
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.FLARE) {
        url = cardFlare
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.HAMMER) {
        url = cardHammer
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.INFANTRY1) {
        url = cardInfantry1
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.INFANTRY2) {
        url = cardInfantry2
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.JOKER) {
        url = cardJoker
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.LEADER) {
        url = cardLeader
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.MACHINEGUN) {
        url = cardMachinegun
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.MORTAR) {
        url = cardMortar
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.NATURAL) {
        url = cardNatural
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.PACIFIST) {
        url = cardPacifist
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.TANK) {
        url = cardTank
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.MOUSE) {
        url = cardMouse
        val = 0
        suit = 0
    } else if (cardInfo.raw === cardutils.GRID) {
        url = cardGrid
        val = 0
        suit = 0
        cardStyle.left = x - ((CARD_HEIGHT - CARD_WIDTH) * renderInfo.scale) / 2
        cardStyle.width = CARD_HEIGHT * renderInfo.scale
        cardStyle.height = CARD_HEIGHT * renderInfo.scale
    } else if (cardInfo.raw === cardutils.FLAREBG) {
        url = cardFlareBG
        val = 0
        suit = 0
        cardStyle.left = x - ((CARD_HEIGHT - CARD_WIDTH) * renderInfo.scale) / 2
        cardStyle.width = CARD_HEIGHT * renderInfo.scale
        cardStyle.height = CARD_HEIGHT * renderInfo.scale
    } else if (cardInfo.raw === cardutils.BACK || (cardInfo.raw & cardutils.FLIP_FLAG) === cardutils.FLIP_FLAG) {
        url = cardBack
        val = 0
        suit = 0
    } else {
        const raw = cardInfo.raw & ~cardutils.FLIP_FLAG
        url = CARD_URLS[raw]
        val = raw % 13
        suit = Math.floor(raw / 13)
        cardStyle.border = "1px solid rgba(0, 0, 0, 0.5)"
        cardStyle.borderRadius = "10px"
    }

    if (cardInfo.rotate != null) {
        cardStyle.transform = `rotate(${cardInfo.rotate}deg)`
    }
    if (cardInfo.opacity != null) {
        cardStyle.opacity = cardInfo.opacity
    }
    if (cardInfo.filter != null) {
        cardStyle.filter = cardInfo.filter
    }

    let stopPropagation = true
    if (isSelected) {
        cardStyle.zIndex = 5
        // cardStyle.filter = "invert(0.8)"
        cardStyle.border = "2px solid rgba(128, 128, 255, 1)"
        if (foundationOnly) {
            cardStyle.border = "2px solid rgba(255, 255, 0, 1)"
        }

        if (renderInfo.view.state.selectOffsetX !== 0 || renderInfo.view.state.selectOffsetY !== 0) {
            stopPropagation = false
            cardStyle.pointerEvents = "none"
        }
    }

    const imageProps = {
        key: cardInfo.key,
        src: url,
        "data-soltype": type,
        "data-solouter": outerIndex,
        "data-solinner": innerIndex,
        draggable: false,
        style: cardStyle
    }

    if (renderInfo.view.props.useTouch) {
        imageProps.onTouchStart = function (e) {
            e.stopPropagation()
            return onClick(type, outerIndex, innerIndex, e.changedTouches[0].pageX, e.changedTouches[0].pageY, false, false)
        }
        imageProps.onTouchEnd = function (e) {
            e.stopPropagation()
            const target = document.elementFromPoint(e.changedTouches[0].clientX, e.changedTouches[0].clientY)

            const dataType = target.dataset.soltype
            const dataOuterIndex = target.dataset.solouter
            const dataInnerIndex = target.dataset.solinner
            if (dataType != null && dataOuterIndex != null && dataInnerIndex != null) {
                return onClick(
                    dataType,
                    parseInt(dataOuterIndex),
                    parseInt(dataInnerIndex),
                    e.changedTouches[0].pageX,
                    e.changedTouches[0].pageY,
                    false,
                    true
                )
            } else {
                return onOther(false)
            }
        }
    } else {
        imageProps.onClick = function (e) {
            if (stopPropagation) {
                return e.stopPropagation()
            }
        }
        imageProps.onContextMenu = function (e) {
            e.preventDefault()
            return e.stopPropagation()
        }
        imageProps.onMouseDown = function (e) {
            if (stopPropagation) {
                e.stopPropagation()
            }
            return onClick(type, outerIndex, innerIndex, e.pageX, e.pageY, e.button === 2, false)
        }
        imageProps.onMouseUp = function (e) {
            if (stopPropagation) {
                e.stopPropagation()
            }
            return onClick(type, outerIndex, innerIndex, e.pageX, e.pageY, e.button === 2, true)
        }
    }

    return el("img", imageProps)
}
