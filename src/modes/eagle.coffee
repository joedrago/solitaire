import * as cardutils from '../cardutils'

mode =
  name: "Eagle Wing"
  help: """
    | GOAL:

    Build the foundations up, in suit, from the rank of the first card played in the foundation,
    untill all cards of the suit have been played, wrapping from king to ace as necessary.

    | PLAY:

    The reserve is dealt 14 cards to begin with. Empty spaces in columns are filled automatically
    from the reserve. If there are no cards left in the reserve, empty spaces of columns can be
    filled with any available card.

    Build columns down and in suit, wrapping as necessary. There is a 3 card maximum for colums.
    Cards from the reserve, waste pile, and packed cards from other columns may be moved to a column.

    There is one redeal.

    | HARD MODE:

    Easy - 14 cards in the reserve pile.

    Hard - 17 cards in the reserve pile.
  """

  newGame: ->
    @state =
      hard: @hard
      draw:
        pos: 'middle'
        redeals: 1
        cards: []
      selection:
        type: 'none'
        outerIndex: 0
        innerIndex: 0
      pile:
        show: 1
        cards: []
      foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE]
      work: []
      reserve:
        pos: 'middle'
        cols: [[]]

    deck = cardutils.shuffle([0...52])

    for columnIndex in [0...8]
      @state.work[columnIndex] = [deck.shift()]

    reserveCount = 14
    if @hard
      reserveCount = 17
    for columnIndex in [0...reserveCount]
      @state.reserve.cols[0].push deck.shift()

    @state.foundations[0] = deck.shift()
    foundationInfo = cardutils.info(@state.foundations[0])
    @state.foundationBase = foundationInfo.value
    @state.centerDisplay = foundationInfo.valueName
    @state.draw.cards = deck

  eagleDealReserve: ->
    for work, workIndex in @state.work
      if @state.reserve.cols[0].length < 1
        break
      if work.length == 0
        work.push @state.reserve.cols[0].pop()

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
      if not isMouseUp
        @sendHome(type, outerIndex, innerIndex)
        @eagleDealReserve()
      @select('none')
      return

    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        # Draw some cards
        if !@state.hard and (@state.draw.cards.length == 0)
          if @state.draw.redeals > 0
            @state.draw.redeals -= 1
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
      when 'reserve'
        # Selecting the top card on the draw pile
        @select('reserve', 0, @state.reserve.cols[0].length - 1)

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
              if srcInfo.value != @state.foundationBase
                break
            else
              dstInfo = cardutils.info(@state.foundations[outerIndex])
              if srcInfo.suit != dstInfo.suit
                break
              if (srcInfo.value != dstInfo.value + 1) and (srcInfo.value != dstInfo.value - 12)
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
            if (dst.length + src.length) <= 3 # Eagle Wing has a pile max of 3
              if (dst.length == 0) or cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING_WRAP | cardutils.VALIDMOVE_MATCHING_SUIT | cardutils.VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE, @state.foundationBase)
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

    @eagleDealReserve()

  won: ->
    return (@state.draw.cards.length == 0) and (@state.pile.cards.length == 0) and (@state.reserve.cols[0].length == 0) and @workPileEmpty()

export default mode
