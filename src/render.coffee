import { el } from './reactutils'
import * as cardutils from './cardutils'

import cardsPNG from './cards.png'
import backPNG from './back.png'
import guidePNG from './guide.png'

export CARD_WIDTH = 120
export CARD_HEIGHT = 162
export CARD_ASPECT_RATIO = CARD_WIDTH / CARD_HEIGHT

export card = (key, raw, x, y, scale, isSelected, onClick) ->
  if raw == cardutils.GUIDE
    url = "url(#{guidePNG})"
    val = 0
    suit = 0
  else if (raw == cardutils.BACK) || ((raw & cardutils.FLIP_FLAG) == cardutils.FLIP_FLAG)
    url = "url(#{backPNG})"
    val = 0
    suit = 0
  else
    raw = raw & ~cardutils.FLIP_FLAG
    url = "url(#{cardsPNG})"
    val = raw % 13
    suit = Math.floor(raw / 13)

  cardStyle =
    position: 'fixed'
    left: "#{x}px"
    top: "#{y}px"
    backgroundImage: url
    backgroundPosition: "#{-4 + (-1 * (CARD_WIDTH * val))}px #{-4 + (-1 * (CARD_HEIGHT * suit))}px"
    backgroundRepeat: 'no-repeat'
    width: CARD_WIDTH
    height: CARD_HEIGHT
    transformOrigin: "top left"
    transform: "scale(#{scale})"

  if isSelected
    cardStyle.filter = "invert(0.8)"

  return el 'div', {
    key: key
    onClick: (e) ->
      e.stopPropagation()
      onClick(false)
    onContextMenu: (e) ->
      e.preventDefault()
      e.stopPropagation()
      onClick(true)
    style: cardStyle
  }
