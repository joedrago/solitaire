export const BACK = -1
export const GUIDE = -2
export const RESERVE = -3
export const DEAD = -4
export const READY = -5
export const ROAD = -6
export const GRID = -7

export const ANVIL = -8
export const ATHLETE = -9
export const HAMMER = -10
export const JOKER = -11
export const LEADER = -12
export const NATURAL = -13
export const PACIFIST = -14
export const MOUSE = -15

export const MACHINEGUN = -16
export const FLARE = -17
export const MORTAR = -18
export const TANK = -19
export const INFANTRY1 = -20
export const INFANTRY2 = -21

export const FLAREBG = -22

export const FLIP_FLAG = 1024

export const MAXLOG = 10

export const shuffle = function (array) {
    for (let i = array.length - 1; i > 0; i--) {
        let j = Math.floor(Math.random() * (i + 1))
        let temp = array[i]
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

export const VALIDMOVE_DESCENDING = 1 << 0
export const VALIDMOVE_DESCENDING_WRAP = 1 << 1
export const VALIDMOVE_ALTERNATING_COLOR = 1 << 2
export const VALIDMOVE_ANY_OTHER_SUIT = 1 << 3
export const VALIDMOVE_MATCHING_SUIT = 1 << 4
export const VALIDMOVE_EMPTY_KINGS_ONLY = 1 << 5
export const VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE = 1 << 6

export const validMove = function (src, dst, validMoveFlags, foundationBase = null) {
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

export const alternatesColorDescending = function (src, dst, emptyAcceptsOnlyKings) {
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

export const descending = function (src, dst, emptyAcceptsOnlyKings) {
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

export const now = () => Math.floor(Date.now())

export const qs = function (name) {
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
