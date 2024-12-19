import * as cardutils from '../cardutils'

mode =
  name: "Klondike"
  help: """
    | GOAL:

    Build the foundations up in suit from ace to king.

    | PLAY:

    Cards are flipped 3 at a time to a waste pile. Columns are built down, in
    alternating colors. All packed cards in a column must be moved as a unit
    to other columns.

    The topmost card of any column or the waste pile may be moved to a
    foundation. The top card of the waste pile may also be moved to a column
    if desired, thus making the card below it playable also.

    Unlimited redeals are allowed.

    | HARD MODE:

    Easy - Cards are flipped 3 cards at a time with unlimited redeals.

    Hard - Cards are flipped 1 card at a time with no redeals.
  """

  newGame: ->
    @state =
      hard: @hard
      draw:
        pos: 'top'
        cards: []
      selection:
        type: 'none'
        outerIndex: 0
        innerIndex: 0
      pile:
        show: if @hard then 1 else 3
        cards: []
      foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE]
      work: []

    deck = cardutils.shuffle(cardutils.range(0, 52))
    for columnIndex in [0...7]
      col = []
      for i in [0...columnIndex]
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck
    return

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
      if not isMouseUp
        @sendHome(type, outerIndex, innerIndex)
      @select('none')
      return

    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        # Draw some cards
        if !@state.hard and (@state.draw.cards.length == 0)
          @state.draw.cards = @state.pile.cards
          @state.pile.cards = []
        else
          cardsToDraw = @state.pile.show
          if cardsToDraw > @state.draw.cards.length
            cardsToDraw = @state.draw.cards.length
          for i in [0...cardsToDraw]
            @state.pile.cards.push @state.draw.cards.shift()
        @select('none')

      # -------------------------------------------------------------------------------------------
      when 'pile'
        # Selecting the top card on the draw pile
        @select('pile')

      # -------------------------------------------------------------------------------------------
      when 'foundation', 'work'
        # Potential selections or destinations
        src = @getSelection()

        # -----------------------------------------------------------------------------------------
        if type == 'foundation'
          loop # create a gauntlet of breaks. if we survive them all, move the card
            if src.length != 1
              break
            srcInfo = cardutils.info(src[0])
            if @state.foundations[outerIndex] < 0 # empty
              if srcInfo.value != 0 # Ace
                break
            else
              dstInfo = cardutils.info(@state.foundations[outerIndex])
              if srcInfo.suit != dstInfo.suit
                break
              if srcInfo.value != dstInfo.value + 1
                break

            @state.foundations[outerIndex] = src[0]
            @eatSelection()
            break
          @select('none')

        # ---------------------------------------------------------------------------------------
        else # type == work
          sameWorkPile = (@state.selection.type == 'work') and (@state.selection.outerIndex == outerIndex)
          if (src.length > 0) and not sameWorkPile
            # Moving into work

            if @state.selection.foundationOnly
              @select('none')
              return

            dst = @state.work[outerIndex]
            if cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR | cardutils.VALIDMOVE_EMPTY_KINGS_ONLY)
              for c in src
                dst.push c
              @eatSelection()

            @select('none')
          else if sameWorkPile and isMouseUp
            @select('none')
          else
            # Selecting a fresh column
            col = @state.work[outerIndex]
            wasClickingLastCard = innerIndex == col.length - 1

            innerIndex = 0 # "All packed cards in a column must be moved as a unit to other columns."
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

            isClickingLastCard = innerIndex == col.length - 1

            if wasClickingLastCard and not isClickingLastCard
              @select(type, outerIndex, col.length - 1)
              @state.selection.foundationOnly = true
            else
              @select(type, outerIndex, innerIndex)


      # -------------------------------------------------------------------------------------------
      else
        # Probably a background click, just forget the selection
        @select('none')

    return

  won: ->
    return (@state.draw.cards.length == 0) and (@state.pile.cards.length == 0) and @workPileEmpty()

export default mode
