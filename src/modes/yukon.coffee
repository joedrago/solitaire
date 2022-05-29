import * as cardutils from '../cardutils'

mode =
  name: "Yukon"
  help: """
    | GOAL:

    Build the foundations up in suit from ace to king.

    | PLAY:

    Build columns down and in any other suit.

    Any face up card in the tableau along with all other cards on top of it,
    may be moved to another column provided that the connecting cards folow
    the build rules.Spaces in columns are filled only with kings.

    There is no redeal.

    | HARD MODE:

    Easy - Columns are built on any other suit.

    Hard - Columns are built on alternating colors.
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
        show: 3
        cards: []
      foundations: [cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE, cardutils.GUIDE]
      work: []

    deck = cardutils.shuffle([0...52])
    @state.work.push [deck.shift()]
    for columnIndex in [1...7]
      col = []
      for i in [0...columnIndex]
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      for i in [0...5]
        col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = []

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
      if not isMouseUp
        @sendHome(type, outerIndex, innerIndex)
      @select('none')
      return

    switch type
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

            if @state.hard
              validFlags = cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR | cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
            else
              validFlags = cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ANY_OTHER_SUIT | cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
            if cardutils.validMove(src, dst, validFlags)
              for c in src
                dst.push c
              @eatSelection()

            @select('none')
          else if sameWorkPile and isMouseUp
            @select('none')
          else
            # Selecting a fresh column
            col = @state.work[outerIndex]
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
