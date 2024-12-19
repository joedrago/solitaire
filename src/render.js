import { el } from "./reactutils"
import * as cardutils from "./cardutils"

import * as deck_basic from "./deck_basic"
import * as deck_balatro from "./deck_balatro"
const DECKS = {
    basic: deck_basic,
    balatro: deck_balatro
}

let deckName = cardutils.qs("deck")
if (!deckName) {
    deckName = "basic"
}
const deck = DECKS[deckName]
const CARD_URLS = deck.urls
const OTHER_CARDS = deck.other
const cardBack = deck.back
const cardGuide = deck.guide
const cardReserve = deck.reserve
const cardDead = deck.dead
const cardReady = deck.ready

window.solitairePreloadedImages = []
for (let preloadUrl of CARD_URLS.concat(OTHER_CARDS)) {
    // console.log "Preloading: #{preloadUrl}"
    let img = new Image()
    img.src = preloadUrl
    window.solitairePreloadedImages.push(img)
}

export const CARD_WIDTH = 119
export const CARD_HEIGHT = 162
export const CARD_ASPECT_RATIO = CARD_WIDTH / CARD_HEIGHT

const easeInOutQuad = (x) => {
    if (x < 0.5) {
        return 2 * x * x
    } else {
        return 1 - Math.pow(-2 * x + 2, 2) / 2
    }
}

export const card = (cardInfo, renderInfo, listenerInfo) => {
    const { type } = cardInfo
    const { outerIndex } = cardInfo
    const { innerIndex } = cardInfo
    const { onClick } = listenerInfo
    const { onOther } = listenerInfo

    let isSelected = cardInfo.selected
    const foundationOnly = isSelected == "foundationOnly"
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
    if (renderInfo.sent != null && renderInfo.sent.raw == cardInfo.raw && renderInfo.sent.x >= 0 && renderInfo.sent.y >= 0) {
        const p = easeInOutQuad(renderInfo.sentPerc)
        x += (renderInfo.sent.x - x) * (1 - p)
        y += (renderInfo.sent.y - y) * (1 - renderInfo.sentPerc)
        zIndex = 5
    }

    const cardStyle = {
        position: "fixed",
        left: `${x}px`,
        top: `${y}px`,
        width: CARD_WIDTH,
        height: CARD_HEIGHT,
        transformOrigin: "top left",
        transform: `scale(${renderInfo.scale})`
    }

    if (zIndex != null) {
        cardStyle.zIndex = zIndex
    }

    let suit, url, val
    if (cardInfo.raw == cardutils.GUIDE) {
        url = cardGuide
        val = 0
        suit = 0
    } else if (cardInfo.raw == cardutils.RESERVE) {
        url = cardReserve
        val = 0
        suit = 0
    } else if (cardInfo.raw == cardutils.DEAD) {
        url = cardDead
        val = 0
        suit = 0
    } else if (cardInfo.raw == cardutils.READY) {
        url = cardReady
        val = 0
        suit = 0
    } else if (cardInfo.raw == cardutils.BACK || (cardInfo.raw & cardutils.FLIP_FLAG) == cardutils.FLIP_FLAG) {
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

    let stopPropagation = true
    if (isSelected) {
        cardStyle.zIndex = 5
        // cardStyle.filter = "invert(0.8)"
        cardStyle.border = "2px solid rgba(128, 128, 255, 1)"
        if (foundationOnly) {
            cardStyle.border = "2px solid rgba(255, 255, 0, 1)"
        }

        if (renderInfo.view.state.selectOffsetX != 0 || renderInfo.view.state.selectOffsetY != 0) {
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
        imageProps.onTouchStart = (e) => {
            e.stopPropagation()
            onClick(type, outerIndex, innerIndex, e.changedTouches[0].pageX, e.changedTouches[0].pageY, false, false)
        }
        imageProps.onTouchEnd = (e) => {
            e.stopPropagation()
            const target = document.elementFromPoint(e.changedTouches[0].clientX, e.changedTouches[0].clientY)

            const dataType = target.dataset.soltype
            const dataOuterIndex = target.dataset.solouter
            const dataInnerIndex = target.dataset.solinner
            if (dataType != null && dataOuterIndex != null && dataInnerIndex != null) {
                onClick(
                    dataType,
                    parseInt(dataOuterIndex),
                    parseInt(dataInnerIndex),
                    e.changedTouches[0].pageX,
                    e.changedTouches[0].pageY,
                    false,
                    true
                )
            } else {
                onOther(false)
            }
        }
    } else {
        imageProps.onClick = (e) => {
            if (stopPropagation) {
                e.stopPropagation()
            }
        }
        imageProps.onContextMenu = (e) => {
            e.preventDefault()
            e.stopPropagation()
        }
        imageProps.onMouseDown = (e) => {
            if (stopPropagation) {
                e.stopPropagation()
            }
            onClick(type, outerIndex, innerIndex, e.pageX, e.pageY, e.button == 2, false)
        }
        imageProps.onMouseUp = (e) => {
            if (stopPropagation) {
                e.stopPropagation()
            }
            onClick(type, outerIndex, innerIndex, e.pageX, e.pageY, e.button == 2, true)
        }
    }

    return el("img", imageProps)
}
