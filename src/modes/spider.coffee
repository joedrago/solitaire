import * as cardutils from '../cardutils'

mode =
  name: "Spider"
  help: """
    | GOAL:

    Remove all 104 cards from the tableau by building eight sets of cards in
    suit from king to ace. The completed sets are removed from the tableau
    immediately.

    | PLAY:

    Build columns down regardless of suit. Either the topmost card or all
    packed cards of the same suit may be moved to another column which meets
    the build requirements.

    When play comes to a standstill (or sooner if desired), deal the next
    group of 10 cards, 1 to each column, then play again if possible. Spaces
    in columns may be filled with any available card or build.

    There is no redeal.

    | HARD MODE:

    Easy - Only two suits are represented (52 hearts, 52 spades).

    Hard - Two full decks are used (all four suits). Very hard!
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

    if @hard
      deck = cardutils.shuffle([0...52].concat([0...52]))
    else
      blacks = [0...13].concat([0...13]).concat([0...13]).concat([0...13])
      reds = [39...52].concat([39...52]).concat([39...52]).concat([39...52])
      deck = cardutils.shuffle(reds.concat(blacks))
    for columnIndex in [0...10]
      col = []
      for i in [0...4]
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck

  spiderRemoveSets: ->
    loop
      foundOne = false
      for work, workIndex in @state.work
        if work.length < 13
          # optimization: this can't have a full set in it
          continue

        kingPos = -1
        kingInfo = null
        for raw, rawIndex in work
          info = cardutils.info(raw)
          if kingPos >= 0
            if (info.value != 12 - rawIndex + kingPos) or (info.suit != kingInfo.suit)
              kingPos = -1
              kingInfo = null

          if kingPos < 0
            if (info.value == 12) and not info.flip
              kingPos = rawIndex
              kingInfo = info

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

  spiderDeal: ->
    for work, workIndex in @state.work
      if @state.draw.cards.length == 0
        break
      work.push @state.draw.cards.pop()

    @select('none')

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
    #   @spiderDeal()
      return

    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        @spiderDeal()

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
            if (lowerInfo.value != upperInfo.value - 1) or (lowerInfo.suit != upperInfo.suit)
              break
            innerIndex -= 1

          @select(type, outerIndex, innerIndex)


      # -------------------------------------------------------------------------------------------
      else
        # Probably a background click, just forget the selection
        @select('none')

    @spiderRemoveSets()

  won: ->
    return (@state.draw.cards.length == 0) and (@state.pile.cards.length == 0) and @workPileEmpty()

export default mode
