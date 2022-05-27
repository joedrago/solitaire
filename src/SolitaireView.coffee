import React, { Component } from 'react'
import { el } from './reactutils'
import * as render from './render'
import * as cardutils from './cardutils'

UNIT = render.CARD_HEIGHT
PILE_CARD_OVERLAP = 0.105
WORK_CARD_OVERLAP = 0.25
CENTER_CARD_MARGIN = 0.5 * (render.CARD_HEIGHT - render.CARD_WIDTH) / render.CARD_HEIGHT

# Coefficient for the height of the card
TOO_CLOSE_TO_DRAG_NORMALIZED = 0.2

class SolitaireView extends Component
  constructor: ->
    super()
    @state =
      selectStartX: -1
      selectStartY: -1
      selectOffsetX: 0
      selectOffsetY: 0
      selectMaxOffsetX: 0
      selectMaxOffsetY: 0

  tooCloseToDrag: ->
    dragDistanceSquared = ((@state.selectMaxOffsetX * @state.selectMaxOffsetX) + (@state.selectMaxOffsetY * @state.selectMaxOffsetY))
    tooClose = TOO_CLOSE_TO_DRAG_NORMALIZED * @renderScalePixels
    tooCloseSquared = tooClose * tooClose
    console.log "dragDistance: #{Math.sqrt(dragDistanceSquared).toFixed(2)}, tooClose: #{tooClose}"
    return dragDistanceSquared < tooCloseSquared

  cardClick: (type, outerIndex, innerIndex, x, y, isRightClick, isMouseUp) ->
    if isMouseUp
      @setState {
        selectStartX: -1
        selectStartY: -1
        selectOffsetX: 0
        selectOffsetY: 0
        selectMaxOffsetX: 0
        selectMaxOffsetY: 0
      }
    else
      @setState {
        selectStartX: x
        selectStartY: y
        selectOffsetX: 0
        selectOffsetY: 0
        selectMaxOffsetX: 0
        selectMaxOffsetY: 0
      }

    if isMouseUp and (@tooCloseToDrag() or (@props.gameState.selection.type == 'none'))
      return
    @props.app.gameClick(type, outerIndex, innerIndex, isRightClick, isMouseUp)

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
    @setState {
      selectStartX: -1
      selectStartY: -1
      selectOffsetX: 0
      selectOffsetY: 0
      selectMaxOffsetX: 0
      selectMaxOffsetY: 0
    }
    @props.app.gameClick('background', 0, 0, isRightClick, false)

  render: ->
    gameState = @props.gameState

    # Calculate necessary table extents, pretending a card is 1.0 units tall
    # "top area"  = top draw pile, foundation piles (both can be absent)
    # "work area" = work piles

    largestWork = 12 # this represents the *minimum* height the game will scale to
    for w in gameState.work
      if largestWork < w.length
        largestWork = w.length

    topWidth = gameState.foundations.length
    foundationOffsetL = 0
    if gameState.draw.pos == 'top'
      foundationOffsetL = 3
      topWidth += foundationOffsetL

    workWidth = gameState.work.length

    workTop = 0
    if (gameState.draw.pos == 'top') or (gameState.foundations.length > 0)
      workTop = 1.25
    workBottom = workTop + 1 + ((largestWork - 1) * WORK_CARD_OVERLAP)

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

    renderedCards = []
    # renderedCards.push el 'div', {
    #   key: "debug"
    #   style:
    #     position: 'fixed'
    #     backgroundColor: '#f00'
    #     left: renderOffsetL
    #     top: 0
    #     width: maxWidthPixels * renderScale
    #     height: maxHeightPixels * renderScale
    # }

    if gameState.draw.pos == 'top'
      # Top Left Draw Pile
      drawCard = cardutils.BACK
      if gameState.draw.cards.length == 0
        drawCard = cardutils.GUIDE
      renderedCards.push(render.card 'draw', drawCard, renderOffsetL + (@renderScalePixels * CENTER_CARD_MARGIN), renderOffsetT, renderScale, false, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
          @cardClick('draw', 0, 0, x, y, isRightClick, isMouseUp)
      )

      pileRenderCount = gameState.pile.cards.length
      if pileRenderCount > gameState.pile.show
        pileRenderCount = gameState.pile.show
      startPileIndex = gameState.pile.cards.length - pileRenderCount

      if startPileIndex > 0
        renderedCards.push(render.card "pileundercard", gameState.pile.cards[startPileIndex-1], renderOffsetL + ((1 + CENTER_CARD_MARGIN) * @renderScalePixels), renderOffsetT, renderScale, isSelected, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
          # clicking on the pile undercard does nothing
        )
      else
        renderedCards.push(render.card "pileguide", cardutils.GUIDE, renderOffsetL + ((1 + CENTER_CARD_MARGIN) * @renderScalePixels), renderOffsetT, renderScale, isSelected, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
          # clicking on the pile guide does nothing
        )

      for pileIndex in [startPileIndex...gameState.pile.cards.length]
        pile = gameState.pile.cards[pileIndex]
        isSelected = false
        if (gameState.selection.type == 'pile') and (pileIndex == (gameState.pile.cards.length - 1))
          isSelected = true
        do (pile, pileIndex, isSelected) =>
          renderedCards.push(render.card "pile#{pileIndex}", pile, renderOffsetL + ((1 + CENTER_CARD_MARGIN + ((pileIndex - startPileIndex) * PILE_CARD_OVERLAP)) * @renderScalePixels), renderOffsetT, renderScale, isSelected, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
              @cardClick('pile', pileIndex, 0, x, y, isRightClick, isMouseUp)
          )

    currentL = renderOffsetL + ((foundationOffsetL + CENTER_CARD_MARGIN) * @renderScalePixels)
    for foundation, foundationIndex in gameState.foundations
      do (foundation, foundationIndex) =>
        renderedCards.push(render.card "foundguide#{foundationIndex}", cardutils.GUIDE, currentL, renderOffsetT, renderScale, false, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
          @cardClick('foundation', foundationIndex, 0, x, y, isRightClick, isMouseUp)
        )
      if foundation != cardutils.GUIDE
        do (foundation, foundationIndex) =>
          renderedCards.push(render.card "found#{foundationIndex}", foundation, currentL, renderOffsetT, renderScale, false, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
            @cardClick('foundation', foundationIndex, 0, x, y, isRightClick, isMouseUp)
          )
      currentL += @renderScalePixels

    currentL = renderOffsetL + (CENTER_CARD_MARGIN * @renderScalePixels)
    for workColumn, workColumnIndex in gameState.work
      do (workColumnIndex, workIndex) =>
        renderedCards.push(render.card "workguide#{workColumnIndex}_#{workIndex}", cardutils.GUIDE, currentL, workTop * @renderScalePixels, renderScale, false, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
          @cardClick('work', workColumnIndex, -1, x, y, isRightClick, isMouseUp)
        )
      for work, workIndex in workColumn
        isSelected = false
        if (gameState.selection.type == 'work') and (workColumnIndex == gameState.selection.outerIndex) and (workIndex >= gameState.selection.innerIndex)
          isSelected = true
        do (work, workColumnIndex, workIndex, isSelected) =>
          renderedCards.push(render.card "work#{workColumnIndex}_#{workIndex}", work, currentL, ((workTop + (workIndex * WORK_CARD_OVERLAP)) * @renderScalePixels), renderScale, isSelected, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
            @cardClick('work', workColumnIndex, workIndex, x, y, isRightClick, isMouseUp)
          )
      currentL += @renderScalePixels

    if gameState.draw.pos == 'bottom'
      # Bottom Left Draw Pile
      drawCard = cardutils.BACK
      if gameState.draw.empty
        drawCard = cardutils.GUIDE
      renderedCards.push(render.card 'draw', drawCard, renderOffsetL, (maxHeight - 0.35) * @renderScalePixels, renderScale, false, @state.selectOffsetX, @state.selectOffsetY, (x, y, isRightClick, isMouseUp) =>
          @cardClick('draw', 0, 0, x, y, isRightClick, isMouseUp)
      )

    return el 'div', {
      key: 'bg'
      style:
        zIndex: -1
        backgroundColor: '#363'
        width: @props.width
        height: @props.height

      onContextMenu: (e) =>
        e.preventDefault()
        @onBackground(true)
      onMouseDown: =>
        @onBackground(false)
      onMouseUp: =>
        @onBackground(false)
      onMouseMove: (e) =>
        @onMouseMove(e.clientX, e.clientY)
    }, renderedCards

export default SolitaireView
