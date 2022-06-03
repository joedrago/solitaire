import * as cardutils from '../cardutils'

mode =
  name: "Baker's Dozen"
  help: """
    | GOAL:

    Build the foundations up in suit from ace to king.

    | PLAY:

    Build columns down regardless of suit. Only the topmost card may be moved
    to another column which meets the build requirements. Empty columns must
    stay empty.

    The topmost card of any column may be moved to a foundation.

    Kings are always dealt to the bottom of columns.

    | HARD MODE:

    Easy - All cards are dealt face up.

    Hard - The last non-King card is face down in each column.
  """

  newGame: ->
    @state =
      hard: @hard
      draw:
        pos: 'none'
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

    # shuffle the deck, but shuffle kings separately
    deck = cardutils.shuffle([0...12].concat([13...25]).concat([26...38]).concat([39...51]))
    kings = cardutils.shuffle([12, 25, 38, 51])

    for columnIndex in [0...13]
      @state.work.push []

    kingPositions = cardutils.shuffle([0...13]).slice(0, 4)
    for p, pIndex in kingPositions
      @state.work[p].push kings[pIndex]
    for columnIndex in [0...13]
      col = @state.work[columnIndex]
      if @hard
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      while col.length < 4
        col.push(deck.shift())

    @state.draw.cards = deck

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

            dst = @state.work[outerIndex]
            if dst.length > 0 # Empty piles must stay empty
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
            if col.length < 1
              @select('none')
            else
              innerIndex = col.length - 1
              @select(type, outerIndex, innerIndex)


      # -------------------------------------------------------------------------------------------
      else
        # Probably a background click, just forget the selection
        @select('none')

  won: ->
    return (@state.draw.cards.length == 0) and (@state.pile.cards.length == 0) and @workPileEmpty()

export default mode
