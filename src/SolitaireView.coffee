import React, { Component } from 'react'
import { el } from './utils'
import * as render from './render'

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

    largestWork = 1
    for w in gameState.work
      if largestWork < w.length
        largestWork = w.length

    topWidth = gameState.foundations.length
    foundationOffsetL = 0
    if gameState.draw == 'top'
      foundationOffsetL = 3
      topWidth += foundationOffsetL

    workWidth = gameState.work.length

    workTop = 0
    if (gameState.draw == 'top') or (gameState.foundations.length > 0)
      workTop = 1.25
    workBottom = workTop + 1 + ((largestWork - 1) * WORK_CARD_OVERLAP)

    maxWidth = topWidth
    if maxWidth < workWidth
      maxWidth = workWidth
    maxHeight = workBottom
    maxAspectRatio = maxWidth / maxHeight
    boardAspectRatio = @props.width / @props.height

    console.log "maxWidth: #{maxWidth}, maxHeight: #{maxHeight}, maxAspectRatio: #{maxAspectRatio}, boardAspectRatio: #{boardAspectRatio}"

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

    console.log "renderScale: #{renderScale} CENTER_CARD_MARGIN #{CENTER_CARD_MARGIN} renderOffsetT #{renderOffsetT}"

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

    if gameState.draw == 'top'
      # Top Left Draw Pile
      renderedCards.push(render.card 'draw', render.CARD_BACK, renderOffsetL + (renderScalePixels * CENTER_CARD_MARGIN), renderOffsetT, renderScale, false, (e) =>
          e.stopPropagation()
          @props.app.gameClick('draw')
      )

      for pile, pileIndex in gameState.pile
        isSelected = false
        if (gameState.selection.type == 'pile') and (pileIndex == (gameState.pile.length - 1))
          isSelected = true
        do (pile, pileIndex, isSelected) =>
          renderedCards.push(render.card "pile#{pileIndex}", pile, renderOffsetL + ((1 + (pileIndex * PILE_CARD_OVERLAP)) * renderScalePixels), renderOffsetT, renderScale, isSelected, (e) =>
              e.stopPropagation()
              @props.app.gameClick('pile', pileIndex)
          )

    currentL = renderOffsetL + ((foundationOffsetL + CENTER_CARD_MARGIN) * renderScalePixels)
    for foundation, foundationIndex in gameState.foundations
      do (foundation, foundationIndex) =>
        renderedCards.push(render.card "found#{foundationIndex}", foundation, currentL, renderOffsetT, renderScale, false, (e) =>
          e.stopPropagation()
          @props.app.gameClick('foundation', foundationIndex)
        )
      currentL += renderScalePixels

    currentL = renderOffsetL + (CENTER_CARD_MARGIN * renderScalePixels)
    for workColumn, workColumnIndex in gameState.work
      if workColumn.length == 0
        renderedCards.push(render.card "work#{workColumnIndex}_#{workIndex}", render.CARD_GUIDE, currentL, workTop * renderScalePixels, renderScale, false, (e) =>
          e.stopPropagation()
          @props.app.gameClick('work', workColumnIndex, -1)
        )
      else
        for work, workIndex in workColumn
          isSelected = false
          if (gameState.selection.type == 'work') and (workColumnIndex == gameState.selection.outerIndex) and (workIndex >= gameState.selection.innerIndex)
            isSelected = true
          do (work, workColumnIndex, workIndex, isSelected) =>
            renderedCards.push(render.card "work#{workColumnIndex}_#{workIndex}", work, currentL, ((workTop + (workIndex * WORK_CARD_OVERLAP)) * renderScalePixels), renderScale, isSelected, (e) =>
              e.stopPropagation()
              @props.app.gameClick('work', workColumnIndex, workIndex)
            )
      currentL += renderScalePixels

    return el 'div', {
      key: 'bg'
      style:
        zIndex: -1
        backgroundColor: '#373'
        width: @props.width
        height: @props.height

      onClick: =>
        @props.app.gameClick('background')
    }, renderedCards

export default SolitaireView
