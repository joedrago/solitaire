/*
 * decaffeinate suggestions:
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
var fullscreen = {
    available() {
        const available = false
        if (document.documentElement.requestFullScreen) {
            return true
        }
        if (document.documentElement.mozRequestFullScreen) {
            return true
        }
        if (document.documentElement.webkitRequestFullScreen) {
            return true
        }
        return false
    },

    active() {
        const active =
            document.fullscreenElement ||
            document.webkitFullscreenElement ||
            document.mozFullScreenElement ||
            document.msFullscreenElement
        return active !== undefined
    },

    enable(enabled) {
        if (enabled == null) {
            enabled = true
        }
        if (!fullscreen.available()) {
            return
        }
        if (enabled === fullscreen.active()) {
            return
        }
        if (enabled) {
            if (document.documentElement.requestFullScreen) {
                return document.documentElement.requestFullScreen()
            }
            if (document.documentElement.mozRequestFullScreen) {
                return document.documentElement.mozRequestFullScreen()
            }
            if (document.documentElement.webkitRequestFullScreen) {
                return document.documentElement.webkitRequestFullScreen(Element.ALLOW_KEYBOARD_INPUT)
            }
        } else {
            if (document.cancelFullScreen) {
                return document.cancelFullScreen()
            }
            if (document.mozCancelFullScreen) {
                return document.mozCancelFullScreen()
            }
            if (document.webkitCancelFullScreen) {
                return document.webkitCancelFullScreen()
            }
        }
    },

    // alias
    disable() {
        return fullscreen.enable(false)
    },

    // helper
    toggle() {
        const active = fullscreen.active()
        return fullscreen.enable(!active)
    }
}

export default fullscreen
