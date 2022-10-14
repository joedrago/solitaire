import * as cardutils from '../cardutils'

mode =
  name: "Emperor"
  help: """
    | GOAL:

    Build the foundations up in suit from ace to king (2 decks).

    | PLAY:

    Cards are flipped 1 at a time to a waste pile. Columns are built down, in
    alternating colors.

    The topmost card of any column or the waste pile may be moved to a
    foundation. The top card of the waste pile may also be moved to a column
    if desired, thus making the card below it playable also. Spaces in
    columns may be filled with any card.

    No redeals.

    | HARD MODE:

    Easy - Any number of packed cards may be moved together. (modern rules)

    Hard - Only one card may be moved at a time. (original rules)
  """

  newGame: ->
    @state =
      hard: @hard
      draw:
        pos: 'top'
        redeals: 0
        cards: []
      selection:
        type: 'none'
        outerIndex: 0
        innerIndex: 0
      pile:
        show: 1
        cards: []
      foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE]
      work: []

    deck = cardutils.shuffle([0...52].concat([0...52]))
    for columnIndex in [0...10]
      col = []
      for i in [0...3]
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      col.push(deck.shift())
      @state.work.push col

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
        if @state.draw.cards.length > 0
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
            if cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR)
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
            else if @state.hard
              innerIndex = col.length - 1
            else
              while (innerIndex < col.length) and (col[innerIndex] & cardutils.FLIP_FLAG)
                # Don't select face down cards
                innerIndex += 1

            @select(type, outerIndex, innerIndex)


      # -------------------------------------------------------------------------------------------
      else
        # Probably a background click, just forget the selection
        @select('none')

  won: ->
    return (@state.draw.cards.length == 0) and (@state.pile.cards.length == 0) and @workPileEmpty()

export default mode
