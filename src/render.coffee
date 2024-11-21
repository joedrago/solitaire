import { el } from './reactutils'
import * as cardutils from './cardutils'

import * as deck_basic from './deck_basic'
import * as deck_balatro from './deck_balatro'
DECKS = {
  basic: deck_basic,
  balatro: deck_balatro
}

deckName = cardutils.qs("deck")
if not deckName
  deckName = "basic"
deck = DECKS[deckName]
CARD_URLS = deck.urls
OTHER_CARDS = deck.other
cardBack = deck.back
cardGuide = deck.guide
cardReserve = deck.reserve
cardDead = deck.dead
cardReady = deck.ready

window.solitairePreloadedImages = []
for preloadUrl in CARD_URLS.concat(OTHER_CARDS)
  # console.log "Preloading: #{preloadUrl}"
  img = new Image()
  img.src = preloadUrl
  window.solitairePreloadedImages.push img

export CARD_WIDTH = 119
export CARD_HEIGHT = 162
export CARD_ASPECT_RATIO = CARD_WIDTH / CARD_HEIGHT

easeInOutQuad = (x) ->
  if x < 0.5 
    return 2 * x * x 
  else 
    return 1 - Math.pow(-2 * x + 2, 2) / 2

export card = (cardInfo, renderInfo, listenerInfo) ->
  type = cardInfo.type
  outerIndex = cardInfo.outerIndex
  innerIndex = cardInfo.innerIndex
  onClick = listenerInfo.onClick
  onOther = listenerInfo.onOther

  isSelected = cardInfo.selected
  foundationOnly = isSelected == "foundationOnly"
  if foundationOnly
    isSelected = true

  x = cardInfo.x
  y = cardInfo.y
  if isSelected
    x -= 1
    y -= 1
    if (Math.abs(renderInfo.view.state.selectOffsetX) > renderInfo.dragSnapPixels) or (Math.abs(renderInfo.view.state.selectOffsetY) > renderInfo.dragSnapPixels)
      x += renderInfo.view.state.selectOffsetX + renderInfo.view.state.selectAdditionalOffsetX
      y += renderInfo.view.state.selectOffsetY + renderInfo.view.state.selectAdditionalOffsetY

  zIndex = null
  if renderInfo.sent? and (renderInfo.sent.raw == cardInfo.raw) and (renderInfo.sent.x >= 0) and (renderInfo.sent.y >= 0)
    p = easeInOutQuad(renderInfo.sentPerc)
    x += (renderInfo.sent.x - x) * (1 - p)
    y += (renderInfo.sent.y - y) * (1 - renderInfo.sentPerc)
    zIndex = 5

  cardStyle =
    position: 'fixed'
    left: "#{x}px"
    top: "#{y}px"
    width: CARD_WIDTH
    height: CARD_HEIGHT
    transformOrigin: "top left"
    transform: "scale(#{renderInfo.scale})"

  if zIndex?
    cardStyle.zIndex = zIndex

  if cardInfo.raw == cardutils.GUIDE
    url = cardGuide
    val = 0
    suit = 0
  else if cardInfo.raw == cardutils.RESERVE
    url = cardReserve
    val = 0
    suit = 0
  else if cardInfo.raw == cardutils.DEAD
    url = cardDead
    val = 0
    suit = 0
  else if cardInfo.raw == cardutils.READY
    url = cardReady
    val = 0
    suit = 0
  else if (cardInfo.raw == cardutils.BACK) || ((cardInfo.raw & cardutils.FLIP_FLAG) == cardutils.FLIP_FLAG)
    url = cardBack
    val = 0
    suit = 0
  else
    raw = cardInfo.raw & ~cardutils.FLIP_FLAG
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
      cardStyle.border = "2px solid rgba(255, 255, 0, 1)"

    if (renderInfo.view.state.selectOffsetX != 0) or (renderInfo.view.state.selectOffsetY != 0)
      stopPropagation = false
      cardStyle.pointerEvents = 'none'

  imageProps =
    key: cardInfo.key
    src: url
    "data-soltype": type
    "data-solouter": outerIndex
    "data-solinner": innerIndex
    draggable: false
    style: cardStyle

  if renderInfo.view.props.useTouch
    imageProps.onTouchStart = (e) ->
      e.stopPropagation()
      onClick(type, outerIndex, innerIndex, e.changedTouches[0].pageX, e.changedTouches[0].pageY, false, false)
    imageProps.onTouchEnd = (e) ->
      e.stopPropagation()
      target = document.elementFromPoint(e.changedTouches[0].clientX, e.changedTouches[0].clientY)

      dataType = target.dataset.soltype
      dataOuterIndex = target.dataset.solouter
      dataInnerIndex = target.dataset.solinner
      if dataType? and dataOuterIndex? and dataInnerIndex?
        onClick(dataType, parseInt(dataOuterIndex), parseInt(dataInnerIndex), e.changedTouches[0].pageX, e.changedTouches[0].pageY, false, true)
      else
        onOther(false)
  else
    imageProps.onClick = (e) ->
      if stopPropagation
        e.stopPropagation()
    imageProps.onContextMenu = (e) ->
      e.preventDefault()
      e.stopPropagation()
    imageProps.onMouseDown = (e) ->
      if stopPropagation
        e.stopPropagation()
      onClick(type, outerIndex, innerIndex, e.pageX, e.pageY, e.button == 2, false)
    imageProps.onMouseUp = (e) ->
      if stopPropagation
        e.stopPropagation()
      onClick(type, outerIndex, innerIndex, e.pageX, e.pageY, e.button == 2, true)

  return el 'img', imageProps
