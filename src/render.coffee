import { el } from './utils'

import cardsPNG from './cards.png'
import backPNG from './back.png'
import guidePNG from './guide.png'

export CARD_BACK = -1
export CARD_GUIDE = -2

export CARD_FLIP_FLAG = 1024

export CARD_WIDTH = 120
export CARD_HEIGHT = 162
export CARD_ASPECT_RATIO = CARD_WIDTH / CARD_HEIGHT

export card = (key, raw, x, y, scale, isSelected, onClick) ->
  # if (w == 0) and (h == 0)
  #   w = CARD_WIDTH
  #   h = CARD_HEIGHT
  # else if (w > 0) and (h == 0)
  #   h = Math.floor(w * CARD_ASPECT_RATIO)
  # else if (w == 0) and (h > 0)
  #   w = Math.floor(h / CARD_ASPECT_RATIO)
  # scale = w / CARD_WIDTH

  if raw == CARD_GUIDE
    url = "url(#{guidePNG})"
    val = 0
    suit = 0
  else if (raw == CARD_BACK) || ((raw & CARD_FLIP_FLAG) == CARD_FLIP_FLAG)
    url = "url(#{backPNG})"
    val = 0
    suit = 0
  else
    raw = raw & ~CARD_FLIP_FLAG
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
    onClick: onClick
    style: cardStyle
  }
