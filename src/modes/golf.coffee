import * as cardutils from '../cardutils'

mode =
  name: "Golf"
  help: """
    | GOAL:

    Move all cards from the tableau into the foundation pile as fast as possible.

    | PLAY:

    Choose any card from a column to start the single foundation. Build the foundation pile up OR
    down regardless of suit, including wrapping (Aces can stack on Kings and vice versa). Any card
    completely exposed may be built on the foundation.

    When play comes to a standstill, flip 1 card from the stock to the foundation, then continue if
    possible. Repeat until no cards remain in the stock.

    There is no redeal.

    | HARD MODE:

    Easy - 7 columns of 5 cards each.

    Hard - 6 columns of 6 cards each.
  """

  newGame: ->
    @state =
      hard: @hard
      draw:
        pos: 'middle'
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
      timerStart: null
      timerEnd: null
      timerColor: '#fff'

    deck = cardutils.shuffle([0...52])

    if @hard
      columnCount = 6
      cardCount  = 6
    else
      columnCount = 7
      cardCount  = 5
    faceDownCount = if @hard then 3 else 2
    for columnIndex in [0...columnCount]
      col = []
      for i in [0...cardCount]
        col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck

  golfCanPlay: (raw) ->
    if @state.pile.cards.length == 0
      return true
    else
      srcInfo = cardutils.info(raw)
      dstInfo = cardutils.info(@state.pile.cards[@state.pile.cards.length - 1])
      if Math.abs(srcInfo.value - dstInfo.value) == 1
        return true
      else if Math.abs(srcInfo.value - dstInfo.value) == 12
        # Wrapping
        return true
    return false

  golfHasPlays: ->
    for col, colIndex in @state.work
      if (col.length > 0) and @golfCanPlay(col[col.length - 1])
        return true
    return false

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    @select('none')

    pileWasEmpty = (@state.pile.cards.length == 0)

    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        if @state.draw.cards.length > 0
          @state.pile.cards.push @state.draw.cards.shift()

      # -------------------------------------------------------------------------------------------
      when 'work'
        col = @state.work[outerIndex]
        if col.length > 0
          src = col[col.length - 1]
          if @golfCanPlay(src)
            @state.pile.cards.push col.pop()

      # -------------------------------------------------------------------------------------------

    if pileWasEmpty and (@state.pile.cards.length > 0)
      @state.timerStart = cardutils.now()
    else if not @state.timerEnd?
      if @workPileEmpty()
        @state.timerEnd = cardutils.now()
        @state.timerColor = '#3f3'
      else if (@state.draw.cards.length == 0) and not @golfHasPlays()
        @state.timerEnd = cardutils.now()
        @state.timerColor = '#ff0'

  won: ->
    return @workPileEmpty()

  lost: ->
    return @state.timerEnd? and not @workPileEmpty()

export default mode
