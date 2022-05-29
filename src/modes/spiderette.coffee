import * as cardutils from '../cardutils'

mode =
  name: "Spiderette"
  help: """
    | GOAL:

    Remove all cards from the tableau by building four sets of cards from king
    to ace regardless of suit. The completed sets are removed from the
    tableau immediately.

    | PLAY:

    Build columns down regardless of suit. Either the topmost card or all
    packed cards of a column may be moved to another column which meets the
    build requirements.

    When play comes to a standstill (or sooner if desired), deal the next
    group of 7 cards, 1 to each column, then play again if possible. Spaces
    in columns may be filled with any available card or build.

    There is no redeal.

    | HARD MODE:

    Easy - 2 cards are dealt face down to columns.

    Hard - 3 cards are dealt face down to columns.
  """

  newGame: ->
    @state =
      hard: @hard
      draw:
        pos: 'bottom'
        cards: []
      selection:
        type: 'none'
        outerIndex: 0
        innerIndex: 0
      pile:
        show: 1
        cards: []
      foundations: []
      work: []

    deck = cardutils.shuffle([0...52])
    faceDownCount = if @hard then 3 else 2
    for columnIndex in [0...7]
      col = []
      for i in [0...faceDownCount]
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      col.push(deck.shift())
      @state.work.push col

    # @state.work[0] = [18,23,12,11,10,9,8,7,6,5,4,3,2,1]
    # @state.work[1] = [0]

    @state.draw.cards = deck

  spideretteRemoveSets: ->
    loop
      foundOne = false
      for work, workIndex in @state.work
        if work.length < 13
          # optimization: this can't have a full set in it
          continue

        kingPos = -1
        for raw, rawIndex in work
          info = cardutils.info(raw)
          if kingPos < 0
            if (info.value == 12) and not info.flip
              kingPos = rawIndex
          else
            if info.value != 12 - rawIndex + kingPos
              kingPos = -1

          if (kingPos >= 0) and ((rawIndex - kingPos) == 12)
            foundOne = true
            # @dumpCards "BEFORE REMOVE: ", @state.work[workIndex]
            @state.work[workIndex].splice(kingPos, 13)
            # @dumpCards "AFTER REMOVE: ", @state.work[workIndex]

            if @state.work[workIndex].length > 0
              @state.work[workIndex][@state.work[workIndex].length - 1] &= ~cardutils.FLIP_FLAG
            break

      if not foundOne
        break

  spideretteDeal: ->
    for work, workIndex in @state.work
      if @state.draw.cards.length == 0
        break
      work.push @state.draw.cards.pop()

    @select('none')

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
    #   @spideretteDeal()
      return

    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        @spideretteDeal()

      # -------------------------------------------------------------------------------------------
      when 'work'
        # Potential selections or destinations
        src = @getSelection()

        sameWorkPile = (@state.selection.type == 'work') and (@state.selection.outerIndex == outerIndex)
        if (src.length > 0) and not sameWorkPile
          # Moving into work
          dst = @state.work[outerIndex]

          if cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING)
            for c in src
              dst.push c
            @eatSelection()

          @select('none')
        else if sameWorkPile and isMouseUp
          @select('none')
        else
          # Selecting a fresh column
          col = @state.work[outerIndex]
          if innerIndex != col.length - 1
            innerIndex = 0
          while (innerIndex < col.length) and (col[innerIndex] & cardutils.FLIP_FLAG)
            # Don't select face down cards
            innerIndex += 1

          stopIndex = innerIndex
          innerIndex = col.length - 1
          while innerIndex > stopIndex
            lowerInfo = cardutils.info(col[innerIndex])
            upperInfo = cardutils.info(col[innerIndex - 1])
            if lowerInfo.value != upperInfo.value - 1
              break
            innerIndex -= 1

          @select(type, outerIndex, innerIndex)


      # -------------------------------------------------------------------------------------------
      else
        # Probably a background click, just forget the selection
        @select('none')

    @spideretteRemoveSets()

  won: ->
    return (@state.draw.cards.length == 0) and (@state.pile.cards.length == 0) and @workPileEmpty()

export default mode
