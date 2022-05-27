import React, { Component } from 'react'
import { el } from './reactutils'
import * as render from './render'
import * as cardutils from './cardutils'

UNIT = render.CARD_HEIGHT
PILE_CARD_OVERLAP = 0.105
WORK_CARD_OVERLAP = 0.25
CENTER_CARD_MARGIN = 0.5 * (render.CARD_HEIGHT - render.CARD_WIDTH) / render.CARD_HEIGHT

class SolitaireView extends Component
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
    renderScalePixels = renderScale * UNIT
    renderOffsetT = renderScalePixels * 0.1

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
      renderedCards.push(render.card 'draw', drawCard, renderOffsetL + (renderScalePixels * CENTER_CARD_MARGIN), renderOffsetT, renderScale, false, (isRightClick) =>
          @props.app.gameClick('draw', 0, 0, isRightClick)
      )

      pileRenderCount = gameState.pile.cards.length
      if pileRenderCount > gameState.pile.show
        pileRenderCount = gameState.pile.show
      startPileIndex = gameState.pile.cards.length - pileRenderCount
      for pileIndex in [startPileIndex...gameState.pile.cards.length]
        pile = gameState.pile.cards[pileIndex]
        isSelected = false
        if (gameState.selection.type == 'pile') and (pileIndex == (gameState.pile.cards.length - 1))
          isSelected = true
        do (pile, pileIndex, isSelected) =>
          renderedCards.push(render.card "pile#{pileIndex}", pile, renderOffsetL + ((1 + CENTER_CARD_MARGIN + ((pileIndex - startPileIndex) * PILE_CARD_OVERLAP)) * renderScalePixels), renderOffsetT, renderScale, isSelected, (isRightClick) =>
              @props.app.gameClick('pile', pileIndex, 0, isRightClick)
          )

    currentL = renderOffsetL + ((foundationOffsetL + CENTER_CARD_MARGIN) * renderScalePixels)
    for foundation, foundationIndex in gameState.foundations
      do (foundation, foundationIndex) =>
        renderedCards.push(render.card "found#{foundationIndex}", foundation, currentL, renderOffsetT, renderScale, false, (isRightClick) =>
          @props.app.gameClick('foundation', foundationIndex, 0, isRightClick)
        )
      currentL += renderScalePixels

    currentL = renderOffsetL + (CENTER_CARD_MARGIN * renderScalePixels)
    for workColumn, workColumnIndex in gameState.work
      if workColumn.length == 0
        do (workColumnIndex, workIndex) =>
          renderedCards.push(render.card "work#{workColumnIndex}_#{workIndex}", cardutils.GUIDE, currentL, workTop * renderScalePixels, renderScale, false, (isRightClick) =>
            @props.app.gameClick('work', workColumnIndex, -1, isRightClick)
          )
      else
        for work, workIndex in workColumn
          isSelected = false
          if (gameState.selection.type == 'work') and (workColumnIndex == gameState.selection.outerIndex) and (workIndex >= gameState.selection.innerIndex)
            isSelected = true
          do (work, workColumnIndex, workIndex, isSelected) =>
            renderedCards.push(render.card "work#{workColumnIndex}_#{workIndex}", work, currentL, ((workTop + (workIndex * WORK_CARD_OVERLAP)) * renderScalePixels), renderScale, isSelected, (isRightClick) =>
              @props.app.gameClick('work', workColumnIndex, workIndex, isRightClick)
            )
      currentL += renderScalePixels

    if gameState.draw.pos == 'bottom'
      # Bottom Left Draw Pile
      drawCard = cardutils.BACK
      if gameState.draw.empty
        drawCard = cardutils.GUIDE
      renderedCards.push(render.card 'draw', drawCard, renderOffsetL, (maxHeight - 0.35) * renderScalePixels, renderScale, false, (isRightClick) =>
          @props.app.gameClick('draw', 0, 0, isRightClick)
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
        @props.app.gameClick('background', 0, 0, true)
      onClick: =>
        @props.app.gameClick('background', 0, 0, false)
    }, renderedCards

export default SolitaireView
