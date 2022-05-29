import { el } from './reactutils'
import * as cardutils from './cardutils'

# Vector Playing Cards 3.2
# https://totalnonsense.com/open-source-vector-playing-cards/
# Copyright 2011,2021 – Chris Aguilar – conjurenation@gmail.com
# Licensed under: LGPL 3.0 - https://www.gnu.org/licenses/lgpl-3.0.html
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

CARD_URLS = [ card0, card1, card2, card3, card4, card5, card6, card7, card8, card9,
card10, card11, card12, card13, card14, card15, card16, card17, card18,
card19, card20, card21, card22, card23, card24, card25, card26, card27,
card28, card29, card30, card31, card32, card33, card34, card35, card36,
card37, card38, card39, card40, card41, card42, card43, card44, card45,
card46, card47, card48, card49, card50, card51 ]

window.solitairePreloadedImages = []
for preloadUrl in CARD_URLS
  # console.log "Preloading: #{preloadUrl}"
  img = new Image()
  img.src = preloadUrl
  window.solitairePreloadedImages.push img

export CARD_WIDTH = 119
export CARD_HEIGHT = 162
export CARD_ASPECT_RATIO = CARD_WIDTH / CARD_HEIGHT

# How much must you drag in a direction before it starts to visually show the drag
DRAG_SNAP_PIXELS = 10

export card = (key, raw, x, y, scale, isSelected, selectOffsetX, selectOffsetY, onClick) ->
  foundationOnly = isSelected == "foundationOnly"
  if foundationOnly
    isSelected = true

  if isSelected and ((Math.abs(selectOffsetX) > DRAG_SNAP_PIXELS) or (Math.abs(selectOffsetY) > DRAG_SNAP_PIXELS))
    x += selectOffsetX
    y += selectOffsetY

  cardStyle =
    position: 'fixed'
    left: "#{x}px"
    top: "#{y}px"
    width: CARD_WIDTH
    height: CARD_HEIGHT
    transformOrigin: "top left"
    transform: "scale(#{scale})"

  if raw == cardutils.GUIDE
    url = cardGuide
    val = 0
    suit = 0
  else if (raw == cardutils.BACK) || ((raw & cardutils.FLIP_FLAG) == cardutils.FLIP_FLAG)
    url = cardBack
    val = 0
    suit = 0
  else
    raw = raw & ~cardutils.FLIP_FLAG
    url = CARD_URLS[raw]
    val = raw % 13
    suit = Math.floor(raw / 13)
    cardStyle.border = "1px solid rgba(0, 0, 0, 0.5)"
    cardStyle.borderRadius = "10px"

  stopPropagation = true
  if isSelected
    cardStyle.zIndex = 5
    # cardStyle.filter = "invert(0.8)"
    cardStyle.border = "2px solid rgba(128, 128, 255, 1)"
    if foundationOnly
      cardStyle.border = "4px solid rgba(255, 255, 0, 1)"

    if (selectOffsetX != 0) or (selectOffsetY != 0)
      stopPropagation = false
      cardStyle.pointerEvents = 'none'

  return el 'img', {
    key: key
    src: url
    draggable: false
    onClick: (e) ->
      if stopPropagation
        e.stopPropagation()
    onContextMenu: (e) ->
      e.preventDefault()
      e.stopPropagation()
      # onClick(e.pageX, e.pageY, true, false)
    onMouseDown: (e) ->
      # console.log e
      if stopPropagation
        e.stopPropagation()
      onClick(e.pageX, e.pageY, e.button == 2, false)
    onMouseUp: (e) ->
      if stopPropagation
        e.stopPropagation()
      onClick(e.pageX, e.pageY, e.button == 2, true)
    style: cardStyle
  }
