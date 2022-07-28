import React, { Component } from 'react'
import { el } from './reactutils'
import * as render from './render'
import * as cardutils from './cardutils'

import IconButton from '@mui/material/IconButton'
import PlayIcon from '@mui/icons-material/PlayCircle'

UNIT = render.CARD_HEIGHT
PILE_CARD_OVERLAP = 0.105
WORK_CARD_OVERLAP = 0.25
CENTER_CARD_MARGIN = 0.5 * (render.CARD_HEIGHT - render.CARD_WIDTH) / render.CARD_HEIGHT
CARD_HALF_WIDTH = render.CARD_WIDTH / render.CARD_HEIGHT / 2

AUTOWIN_RATE_MS = 200

# Coefficient for the height of the card
TOO_CLOSE_TO_DRAG_NORMALIZED = 0.2

# this represents the *minimum* height the game will scale to
MINIMUM_SCALE_IN_CARD_HEIGHTS = 12
tmpMinScale = cardutils.qs('min')
if tmpMinScale?
  tmpMinScale = parseInt(tmpMinScale)
  if tmpMinScale >= 1
    MINIMUM_SCALE_IN_CARD_HEIGHTS = tmpMinScale

noop = ->

class SolitaireView extends Component
  constructor: ->
    super()
    @state =
      selectStartX: -1
      selectStartY: -1
      selectOffsetX: 0
      selectOffsetY: 0
      selectAdditionalOffsetX: 0
      selectAdditionalOffsetY: 0
      selectMaxOffsetX: 0
      selectMaxOffsetY: 0
      now: 0
      lastSendAny: 0
      sent: null

    @timer = null
    @autowinInterval = false

  tooCloseToDrag: ->
    dragDistanceSquared = ((@state.selectMaxOffsetX * @state.selectMaxOffsetX) + (@state.selectMaxOffsetY * @state.selectMaxOffsetY))
    tooClose = TOO_CLOSE_TO_DRAG_NORMALIZED * @renderScalePixels
    tooCloseSquared = tooClose * tooClose
    # console.log "dragDistance: #{Math.sqrt(dragDistanceSquared).toFixed(2)}, tooClose: #{tooClose}"
    return dragDistanceSquared < tooCloseSquared

  forgetCards: ->
    @renderedCards = []
    @cardInfos = {}

  cardKey: (type, outerIndex, innerIndex) ->
    return "#{type}/#{innerIndex}/#{outerIndex}"

  renderCard: (cardInfo, renderInfo, listenerInfo) ->
    @renderedCards.push(render.card(cardInfo, renderInfo, listenerInfo))
    @cardInfos[@cardKey(cardInfo.type, cardInfo.outerIndex, cardInfo.innerIndex)] = cardInfo

  resetSelectState: ->
    @setState {
      selectStartX: -1
      selectStartY: -1
      selectOffsetX: 0
      selectOffsetY: 0
      selectAdditionalOffsetX: 0
      selectAdditionalOffsetY: 0
      selectMaxOffsetX: 0
      selectMaxOffsetY: 0
    }

  cardClick: (type, outerIndex, innerIndex, x, y, isRightClick, isMouseUp) ->
    if isMouseUp
      @resetSelectState()
      if @tooCloseToDrag() or (@props.gameState.selection.type == 'none')
        return

    @props.app.gameClick(type, outerIndex, innerIndex, isRightClick, isMouseUp)

    if not isMouseUp
      type = @props.app.state.gameState.selection.type
      if type != 'none'
        # console.log "gamestate ", @props.app.state.gameState
        innerIndex = @props.app.state.gameState.selection.innerIndex
        outerIndex = @props.app.state.gameState.selection.outerIndex

        selectAdditionalOffsetX = 0
        selectAdditionalOffsetY = 0
        cardInfo = @cardInfos[@cardKey(type, outerIndex, innerIndex)]
        if cardInfo?
          selectAdditionalOffsetX = x - cardInfo.x - (@renderScalePixels * CARD_HALF_WIDTH)
          selectAdditionalOffsetY = y - cardInfo.y - (@renderScalePixels * WORK_CARD_OVERLAP * 0.5)

        @setState {
          selectStartX: x
          selectStartY: y
          selectOffsetX: 0
          selectOffsetY: 0
          selectAdditionalOffsetX: selectAdditionalOffsetX
          selectAdditionalOffsetY: selectAdditionalOffsetY
          selectMaxOffsetX: 0
          selectMaxOffsetY: 0
        }

  onMouseMove: (x, y) ->
    if (@state.selectStartX < 0) or (@state.selectStartY < 0)
      return
    newOffSetX = x - @state.selectStartX
    newOffSetY = y - @state.selectStartY
    newMaxX = Math.max(Math.abs(newOffSetX), @state.selectMaxOffsetX)
    newMaxY = Math.max(Math.abs(newOffSetY), @state.selectMaxOffsetY)
    @setState {
      selectOffsetX: newOffSetX
      selectOffsetY: newOffSetY
      selectMaxOffsetX: newMaxX
      selectMaxOffsetY: newMaxY
    }

  onBackground: (isRightClick) ->
    @resetSelectState()
    @props.app.gameClick('background', 0, 0, isRightClick, false)

  adjustTimer: (gameState) ->
    if gameState.timerStart? and not gameState.timerEnd?
      if not @timer?
        @timer = setInterval =>
          @setState {
            now: cardutils.now()
          }
        , 500
    else
      if @timer?
        clearInterval(@timer)
        @timer = null

  prettyTime: (t, showMS = false) ->
    zp = (t) ->
      if t < 10
        return "0" + t
      return String(t)
    zpp = (t) ->
      if t < 10
        return "00" + t
      if t < 100
        return "0" + t
      return String(t)

    minutes = Math.floor(t / 60000)
    t -= minutes * 60000
    seconds = Math.floor(t / 1000)
    t -= seconds * 1000
    if showMS
      return "#{zp(minutes)}:#{zp(seconds)}.#{zpp(t)}"
    return "#{zp(minutes)}:#{zp(seconds)}"

  onAutowin: ->
    now = cardutils.now()
    if now > (@state.lastSendAny + AUTOWIN_RATE_MS)
      sent = @props.app.sendAny()
      if sent?
        cardInfo = @cardInfos[@cardKey('work', sent.prevOuterIndex, sent.prevInnerIndex)]
        if cardInfo?
          sent.x = cardInfo.x
          sent.y = cardInfo.y
        else
          sent.x = -1
          sent.y = -1
        console.log "Sent: ", sent
      else if @autowinInterval
        @toggleAutowin()
      @setState {
        lastSendAny: now
        now: now
        sent: sent
      }
    else
      @setState {
        now: now
      }

    if @autowinInterval
      window.requestAnimationFrame(@onAutowin.bind(this))

  toggleAutowin: ->
    @autowinInterval = !@autowinInterval

    if @autowinInterval
      window.requestAnimationFrame(@onAutowin.bind(this))

    @setState {
      now: cardutils.now()
      sent: null
    }

  render: ->
    gameState = @props.gameState
    @adjustTimer(gameState)

    # Calculate necessary table extents, pretending a card is 1.0 units tall
    # "top area"  = top draw pile, foundation piles (both can be absent)
    # "work area" = work piles

    largestWork = 3
    if not @props.useTouch
      largestWork = MINIMUM_SCALE_IN_CARD_HEIGHTS
    for w in gameState.work
      if largestWork < w.length
        largestWork = w.length

    topWidth = gameState.foundations.length
    foundationOffsetL = gameState.work.length - gameState.foundations.length
    topWidth += foundationOffsetL

    workWidth = gameState.work.length

    workTop = 0
    if (gameState.draw.pos == 'top') or (gameState.foundations.length > 0)
      workTop = 1.25
    workBottom = workTop + 1 + ((largestWork - 1) * WORK_CARD_OVERLAP)
    if (workBottom < 4.1) and ((gameState.draw.pos == 'middle') or (gameState.reserve? and (gameState.reserve.pos == 'middle')))
      # Leave room for draw/reserve at the bottom of the screen
      workBottom = 4.1

    maxWidth = topWidth
    if maxWidth < workWidth
      maxWidth = workWidth
    maxHeight = workBottom
    maxAspectRatio = maxWidth / maxHeight
    boardAspectRatio = @props.width / @props.height

    maxWidthPixels = maxWidth * UNIT
    maxHeightPixels = maxHeight * UNIT

    if maxAspectRatio < boardAspectRatio
      # use height for scaling
      renderScale = @props.height / maxHeightPixels
      renderOffsetL = (@props.width - (maxWidthPixels * renderScale)) / 2
    else
      # use width for scaling
      renderScale = @props.width / maxWidthPixels
      renderOffsetL = 0
    @renderScalePixels = renderScale * UNIT
    renderOffsetT = @renderScalePixels * 0.1

    sentPerc = (@state.now - @state.lastSendAny) / AUTOWIN_RATE_MS
    if sentPerc < 0
      sentPerc = 0
    else if sentPerc > 1
      sentPerc = 1
    renderInfo =
      view: this
      scale: renderScale
      dragSnapPixels: Math.floor(@renderScalePixels * 0.1)
      sent: @state.sent
      sentPerc: sentPerc
    listenerInfo =
      onClick: @cardClick.bind(this)
      onOther: @onBackground.bind(this)
    listenerInfoNoop =
      onClick: noop
      onOther: @onBackground.bind(this)

    @forgetCards()
    if (gameState.draw.pos == 'top') or (gameState.draw.pos == 'middle')
      if gameState.draw.pos == 'top'
        drawOffsetL = 0
        drawOffsetT = 0
      else if gameState.reserve? and (gameState.reserve.pos == 'middle')
        drawOffsetL = 1 * @renderScalePixels
        drawOffsetT = 3 * @renderScalePixels
      else
        drawOffsetL = ((maxWidth / 2) - 1) * @renderScalePixels
        drawOffsetT = 2.3 * @renderScalePixels
      # Top Left Draw Pile
      drawCard = cardutils.BACK
      if gameState.draw.cards.length == 0
        drawCard = cardutils.READY
        if gameState.draw.redeals == 0
          drawCard = cardutils.DEAD
      cardInfo =
        key: 'draw'
        raw: drawCard
        x: drawOffsetL + renderOffsetL + (@renderScalePixels * CENTER_CARD_MARGIN)
        y: drawOffsetT + renderOffsetT
        selected: false
        type: 'draw'
        outerIndex: 0
        innerIndex: 0
      @renderCard(cardInfo, renderInfo, listenerInfo)

      pileRenderCount = gameState.pile.cards.length
      if pileRenderCount > gameState.pile.show
        pileRenderCount = gameState.pile.show
      startPileIndex = gameState.pile.cards.length - pileRenderCount

      if startPileIndex > 0
        cardInfo =
          key: 'pileundercard'
          raw: gameState.pile.cards[startPileIndex-1]
          x: drawOffsetL + renderOffsetL + ((1 + CENTER_CARD_MARGIN) * @renderScalePixels)
          y: drawOffsetT + renderOffsetT
          selected: isSelected
          type: 'pile'
          outerIndex: 0
          innerIndex: 0
      else
        cardInfo =
          key: 'pileguide'
          raw: cardutils.GUIDE
          x: drawOffsetL + renderOffsetL + ((1 + CENTER_CARD_MARGIN) * @renderScalePixels)
          y: drawOffsetT + renderOffsetT
          selected: false
          type: 'pile'
          outerIndex: 0
          innerIndex: 0
      @renderCard(cardInfo, renderInfo, listenerInfoNoop)

      for pileIndex in [startPileIndex...gameState.pile.cards.length]
        pile = gameState.pile.cards[pileIndex]
        isSelected = false
        if (gameState.selection.type == 'pile') and (pileIndex == (gameState.pile.cards.length - 1))
          isSelected = true
        do (pile, pileIndex, isSelected) =>
          cardInfo =
            key: "pile#{pileIndex}"
            raw: pile
            x: drawOffsetL + renderOffsetL + ((1 + CENTER_CARD_MARGIN + ((pileIndex - startPileIndex) * PILE_CARD_OVERLAP)) * @renderScalePixels)
            y: drawOffsetT + renderOffsetT
            selected: isSelected
            type: 'pile'
            outerIndex: pileIndex
            innerIndex: 0
          @renderCard(cardInfo, renderInfo, listenerInfo)

    currentL = renderOffsetL + (CENTER_CARD_MARGIN * @renderScalePixels)
    for workColumn, workColumnIndex in gameState.work
      do (workColumnIndex, workIndex) =>
        cardInfo =
          key: "workguide#{workColumnIndex}_#{workIndex}"
          raw: cardutils.GUIDE
          x: currentL
          y: workTop * @renderScalePixels
          selected: false
          type: 'work'
          outerIndex: workColumnIndex
          innerIndex: -1
        @renderCard(cardInfo, renderInfo, listenerInfo)
      for work, workIndex in workColumn
        isSelected = false
        if (gameState.selection.type == 'work') and (workColumnIndex == gameState.selection.outerIndex) and (workIndex >= gameState.selection.innerIndex)
          isSelected = true
          if gameState.selection.foundationOnly
            isSelected = "foundationOnly"
        do (work, workColumnIndex, workIndex, isSelected) =>
          cardInfo =
            key: "work#{workColumnIndex}_#{workIndex}"
            raw: work
            x: currentL
            y: ((workTop + (workIndex * WORK_CARD_OVERLAP)) * @renderScalePixels)
            selected: isSelected
            type: 'work'
            outerIndex: workColumnIndex
            innerIndex: workIndex
          @renderCard(cardInfo, renderInfo, listenerInfo)
      currentL += @renderScalePixels

    currentL = renderOffsetL + ((foundationOffsetL + CENTER_CARD_MARGIN) * @renderScalePixels)
    for foundation, foundationIndex in gameState.foundations
      do (foundation, foundationIndex) =>
        cardInfo =
          key: "foundguide#{foundationIndex}"
          raw: cardutils.GUIDE
          x: currentL
          y: renderOffsetT
          selected: false
          type: 'foundation'
          outerIndex: foundationIndex
          innerIndex: 0
        @renderCard(cardInfo, renderInfo, listenerInfo)
      if @state.sent? and (@state.sent.foundationIndex == foundationIndex) and (@state.sent.prevFoundationRaw >= 0)
        do (foundation, foundationIndex) =>
          cardInfo =
            key: "foundunder#{foundationIndex}"
            raw: @state.sent.prevFoundationRaw
            x: currentL
            y: renderOffsetT
            selected: false
            type: 'foundation'
            outerIndex: foundationIndex
            innerIndex: 0
          @renderCard(cardInfo, renderInfo, listenerInfo)
      if foundation != cardutils.GUIDE
        do (foundation, foundationIndex) =>
          cardInfo =
            key: "found#{foundationIndex}"
            raw: foundation
            x: currentL
            y: renderOffsetT
            selected: false
            type: 'foundation'
            outerIndex: foundationIndex
            innerIndex: 0
          @renderCard(cardInfo, renderInfo, listenerInfo)
      currentL += @renderScalePixels

    if gameState.draw.pos == 'bottom'
      # Bottom Left Draw Pile
      drawCard = cardutils.BACK
      if gameState.draw.cards.length == 0
        drawCard = cardutils.GUIDE

      cardInfo =
        key: 'draw'
        raw: drawCard
        x: renderOffsetL
        y: @props.height - (0.35 * @renderScalePixels)
        selected: false
        type: 'draw'
        outerIndex: 0
        innerIndex: 0
      @renderCard(cardInfo, renderInfo, listenerInfo)

    if gameState.reserve?
      if gameState.reserve.pos == 'middle'
        drawOffsetL = ((maxWidth / 2) - 0.5) * @renderScalePixels
        drawOffsetT = 3 * @renderScalePixels
      else
        drawOffsetL = 0
        drawOffsetT = 0

      for col, colIndex in gameState.reserve.cols
        drawCard = cardutils.RESERVE
        if col.length > 1
          drawCard = col[col.length - 2]
        cardInfo =
          key: "reserveguide#{colIndex}"
          raw: drawCard
          x: drawOffsetL + renderOffsetL + (@renderScalePixels * (colIndex + CENTER_CARD_MARGIN))
          y: drawOffsetT + renderOffsetT
          selected: false
          type: 'reserve'
          outerIndex: colIndex
          innerIndex: -1
        @renderCard(cardInfo, renderInfo, listenerInfo)

        if col.length > 0
          reserveIndex = col.length - 1
          isSelected = false
          if (gameState.selection.type == 'reserve') and (colIndex == gameState.selection.outerIndex) and (reserveIndex >= gameState.selection.innerIndex)
            isSelected = true
          cardInfo =
            key: "reserve#{colIndex}"
            raw: col[reserveIndex]
            x: drawOffsetL + renderOffsetL + (@renderScalePixels * (colIndex + CENTER_CARD_MARGIN))
            y: drawOffsetT + renderOffsetT
            selected: isSelected
            type: 'reserve'
            outerIndex: colIndex
            innerIndex: reserveIndex
          @renderCard(cardInfo, renderInfo, listenerInfo)

    if gameState.timerStart? and gameState.timerColor?
      endTime = gameState.timerEnd
      if not endTime?
        endTime = cardutils.now()
      timeToShow = endTime - gameState.timerStart
      @renderedCards.push el 'div', {
        key: 'timer'
        style:
          position: 'fixed'
          textAlign: 'center'
          left: "0px"
          width: '100%'
          top: "#{3.5 * @renderScalePixels}px"
          fontFamily: 'monospace'
          fontSize: "#{@renderScalePixels * 0.1}px"
          color: gameState.timerColor
          textShadow: '2px 2px #000'
          pointerEvents: 'none'
      }, [ @prettyTime(timeToShow, gameState.timerEnd?) ]

    if gameState.centerDisplay?
      @renderedCards.push el 'div', {
        key: 'centerdisplay'
        style:
          position: 'fixed'
          textAlign: 'center'
          left: "0px"
          width: '100%'
          top: "#{0.5 * @renderScalePixels}px"
          fontFamily: 'monospace'
          fontSize: "#{@renderScalePixels * 0.2}px"
          color: '#6a6'
          textShadow: '2px 2px #000'
          pointerEvents: 'none'
      }, [ gameState.centerDisplay ]

    if @autowinInterval or @props.canAutoWin
      @renderedCards.push el IconButton, {
        key: 'autowinButton'
        size: 'large'
        style:
          position: 'fixed'
          top: '10px'
          left: '10px'
          color: if @autowinInterval then '#afa' else '#aaa'
        onClick: =>
          @toggleAutowin()
      }, [
        el PlayIcon, { key: 'autowinIcon' }
      ]

    bgProps =
      key: 'bg'
      style:
        zIndex: -1
        backgroundColor: '#363'
        width: @props.width
        height: @props.height

    if @props.useTouch
      bgProps.onTouchStart = (e) =>
        if e.touches.length == 1
          @onBackground(false)
      bgProps.onTouchEnd = (e) =>
        if e.touches.length == 0
          @onBackground(false)
      bgProps.onTouchMove = (e) =>
        if e.touches.length == 1
          @onMouseMove(e.touches[0].clientX, e.touches[0].clientY)
    else
      bgProps.onContextMenu = (e) =>
        e.preventDefault()
        # @onBackground(true)
      bgProps.onMouseDown = =>
        @onBackground(false)
      bgProps.onMouseUp = =>
        @onBackground(false)
      bgProps.onMouseMove = (e) =>
        @onMouseMove(e.clientX, e.clientY)

    return el 'div', bgProps, @renderedCards

export default SolitaireView
