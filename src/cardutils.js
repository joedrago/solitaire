/*
 * decaffeinate suggestions:
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
export var BACK = -1
export var GUIDE = -2
export var RESERVE = -3
export var DEAD = -4
export var READY = -5
export var ROAD = -6
export var GRID = -7

export var ANVIL = -8
export var ATHLETE = -9
export var HAMMER = -10
export var JOKER = -11
export var LEADER = -12
export var NATURAL = -13
export var PACIFIST = -14
export var MOUSE = -15

export var MACHINEGUN = -16
export var FLARE = -17
export var MORTAR = -18
export var TANK = -19
export var INFANTRY1 = -20
export var INFANTRY2 = -21

export var FLAREBG = -22

export var FLIP_FLAG = 1024

export var MAXLOG = 10

export var shuffle = function (array) {
    for (let i = array.length - 1; i > 0; i--) {
        var j = Math.floor(Math.random() * (i + 1))
        var temp = array[i]
        array[i] = array[j]
        array[j] = temp
    }
    return array
}

const calcInfo = function (raw) {
    let info
    if (raw < 0) {
        info = {
            value: raw,
            suit: raw,
            flip: raw === BACK,
            red: false
        }
    } else {
        const flip = (raw & FLIP_FLAG) === FLIP_FLAG
        raw = raw & ~FLIP_FLAG
        const suit = Math.floor(raw / 13)
        const value = raw % 13
        const valueName = (() => {
            switch (value) {
                case 0:
                    return "A"
                case 10:
                    return "J"
                case 11:
                    return "Q"
                case 12:
                    return "K"
                default:
                    return `${value + 1}`
            }
        })()
        info = {
            value,
            valueName,
            suit,
            flip,
            red: suit > 1
        }
    }
    return info
}

export var VALIDMOVE_DESCENDING = 1 << 0
export var VALIDMOVE_DESCENDING_WRAP = 1 << 1
export var VALIDMOVE_ALTERNATING_COLOR = 1 << 2
export var VALIDMOVE_ANY_OTHER_SUIT = 1 << 3
export var VALIDMOVE_MATCHING_SUIT = 1 << 4
export var VALIDMOVE_EMPTY_KINGS_ONLY = 1 << 5
export var VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE = 1 << 6

export var validMove = function (src, dst, validMoveFlags, foundationBase = null) {
    const srcInfo = calcInfo(src[0])

    if (dst.length === 0) {
        if (validMoveFlags & VALIDMOVE_EMPTY_KINGS_ONLY) {
            return srcInfo.value === 12
        } else {
            return true
        }
    }

    const dstInfo = calcInfo(dst[dst.length - 1])
    if (validMoveFlags & VALIDMOVE_ALTERNATING_COLOR && srcInfo.red === dstInfo.red) {
        return false
    }
    if (validMoveFlags & VALIDMOVE_MATCHING_SUIT && srcInfo.suit !== dstInfo.suit) {
        return false
    }
    if (validMoveFlags & VALIDMOVE_ANY_OTHER_SUIT && srcInfo.suit === dstInfo.suit) {
        return false
    }
    if (validMoveFlags & VALIDMOVE_DESCENDING && srcInfo.value !== dstInfo.value - 1) {
        return false
    }
    if (
        validMoveFlags & VALIDMOVE_DESCENDING_WRAP &&
        srcInfo.value !== dstInfo.value - 1 &&
        srcInfo.value !== dstInfo.value + 12
    ) {
        return false
    }
    if (validMoveFlags & VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE && dstInfo.value === foundationBase) {
        return false
    }

    return true
}

export var alternatesColorDescending = function (src, dst, emptyAcceptsOnlyKings) {
    if (emptyAcceptsOnlyKings == null) {
        emptyAcceptsOnlyKings = false
    }
    const srcInfo = calcInfo(src[0])

    if (dst.length === 0) {
        if (emptyAcceptsOnlyKings) {
            return srcInfo.value === 12
        } else {
            return true
        }
    }

    const dstInfo = calcInfo(dst[dst.length - 1])
    if (srcInfo.red === dstInfo.red) {
        return false
    }
    if (srcInfo.value !== dstInfo.value - 1) {
        return false
    }

    return true
}

export var descending = function (src, dst, emptyAcceptsOnlyKings) {
    if (emptyAcceptsOnlyKings == null) {
        emptyAcceptsOnlyKings = false
    }
    const srcInfo = calcInfo(src[0])

    if (dst.length === 0) {
        if (emptyAcceptsOnlyKings) {
            return srcInfo.value === 12
        } else {
            return true
        }
    }

    const dstInfo = calcInfo(dst[dst.length - 1])
    if (srcInfo.value !== dstInfo.value - 1) {
        return false
    }

    return true
}

export var now = () => Math.floor(Date.now())

export var qs = function (name) {
    const url = window.location.href
    name = name.replace(/[\[\]]/g, "\\$&")
    const regex = new RegExp("[?&]" + name + "(=([^&#]*)|&|#|$)")
    const results = regex.exec(url)
    if (!results || !results[2]) {
        return null
    }
    return decodeURIComponent(results[2].replace(/\+/g, " "))
}

export { calcInfo as info }
