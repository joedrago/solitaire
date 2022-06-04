import * as cardutils from '../cardutils'

mode =
  name: "Freecell"
  help: """
    | GOAL:

    Build the foundations up in suit from ace to king.

    | PLAY:

    Columns are built down in alternating colors. Cards on the bottom of a
    column can be moved to a cell to gain access to cards below it, but at a
    cost.

    Cards that are descending and in suit may be moved all at once, but the
    max count of cards that can be moved at a single time is based on how
    many cells are free and how many columns are empty. You're always allowed
    to move a single card (1) plus an additional card for every free cell.
    This number is then doubled for every empty column.

    The max count able to be moved is displayed between the cells and
    foundations for your convenience.

    The topmost card of any column or cell may be moved to a foundation. Cards
    in a cell may also be moved to a foundation.

    | HARD MODE:

    Easy - There are four cells.

    Hard - There are only two cells.
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
      reserve:
        pos: 'top'
        cols: []

    cellCount = 4
    if @hard
      cellCount = 2
    for c in [0...cellCount]
      @state.reserve.cols.push []

    deck = cardutils.shuffle([0...52])
    for columnIndex in [0...8]
      col = []
      colCount = 6
      if columnIndex < 4
        colCount += 1
      for i in [0...colCount]
        col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck
    @freecellUpdateCount()

  freecellUpdateCount: ->
    count = 1
    for col in @state.reserve.cols
      if col.length == 0
        count += 1

    for col in @state.work
      if col.length == 0
        count *= 2

    if count > 52
      count = 52

    @state.centerDisplay = "#{count}"
    return count

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
      if not isMouseUp
        @sendHome(type, outerIndex, innerIndex)
        @freecellUpdateCount()
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
      when 'foundation'
        src = @getSelection()

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

      # -----------------------------------------------------------------------------------------
      when 'reserve'
        src = @getSelection()

        srcIsDest = (@state.selection.type == 'reserve') and (@state.selection.outerIndex == outerIndex)
        if (src.length > 0) and not srcIsDest
          # Moving into reserve
          if (src.length == 1) and (@state.reserve.cols[outerIndex].length == 0)
            @state.reserve.cols[outerIndex].push src[0]
            @eatSelection()
          @select('none')
        else
          # Selecting a reserve card
          col = @state.reserve.cols[outerIndex]
          if col.length > 0
            @select('reserve', outerIndex, col.length - 1)
          else
            @select('none')

      # ---------------------------------------------------------------------------------------
      when 'work'
        src = @getSelection()

        srcIsDest = (@state.selection.type == 'work') and (@state.selection.outerIndex == outerIndex)
        if (src.length > 0) and not srcIsDest
          # Moving into work

          if @state.selection.foundationOnly
            @select('none')
            return

          dst = @state.work[outerIndex]
          if cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR)
            for c in src
              dst.push c
            @eatSelection()

          @select('none')
        else if srcIsDest and isMouseUp
          @select('none')
        else
          # Selecting a fresh column
          col = @state.work[outerIndex]

          stopIndex = innerIndex
          innerIndex = col.length - 1
          while innerIndex > stopIndex
            lowerInfo = cardutils.info(col[innerIndex])
            upperInfo = cardutils.info(col[innerIndex - 1])
            if (lowerInfo.value != upperInfo.value - 1) or (lowerInfo.red == upperInfo.red)
              break
            innerIndex -= 1

          maxCount = @freecellUpdateCount()
          while (col.length - innerIndex) > maxCount
            innerIndex += 1

          @select(type, outerIndex, innerIndex)


      # -------------------------------------------------------------------------------------------
      else
        # Probably a background click, just forget the selection
        @select('none')

    @freecellUpdateCount()

  won: ->
    return @workPileEmpty() and @reserveEmpty()

export default mode
