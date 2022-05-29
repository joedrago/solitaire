import * as cardutils from '../cardutils'

mode =
  name: "Scorpion"
  help: """
    | GOAL:

    Arrange four sets of cards in suit, from, king down to ace.

    | PLAY:

    Build columns down and in suit. Any face up card may be moved, along
    with all other cards on top of it, to a completely exposed card which
    meets the build requirements. Flip face down cards which become exposed
    face up.

    When play comes to a standstill (or sooner if desired), deal the three
    remaining cards of the stock to the first three columns, then continue if
    possible. Empty spaces in columns may be filled with any cards.

    There is no redeal.

    | HARD MODE:

    Easy - 2 cards face down in the first 4 columns. Fill empties with any cards.

    Hard - 3 cards face down in the first 4 columns. Fill empties with Kings only.
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
    if @hard
      faceDownCount = 3
      faceUpCount = 4
    else
      faceDownCount = 2
      faceUpCount = 5
    for columnIndex in [0...7]
      col = []
      if columnIndex < 4
        for i in [0...faceDownCount]
          col.push(deck.shift() | cardutils.FLIP_FLAG)
        for i in [0...faceUpCount]
          col.push(deck.shift())
      else
        for i in [0...7]
          col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck

  scorpionDeal: ->
    for work, workIndex in @state.work
      if @state.draw.cards.length == 0
        break
      work.push @state.draw.cards.pop()

    @select('none')

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if isRightClick
    #   @scorpionDeal()
      return

    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        @scorpionDeal()

      # -------------------------------------------------------------------------------------------
      when 'work'
        # Potential selections or destinations
        src = @getSelection()

        sameWorkPile = (@state.selection.type == 'work') and (@state.selection.outerIndex == outerIndex)
        if (src.length > 0) and not sameWorkPile
          # Moving into work
          dst = @state.work[outerIndex]

          validFlags = cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_MATCHING_SUIT
          if @state.hard
            validFlags |= cardutils.VALIDMOVE_EMPTY_KINGS_ONLY
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
    if @state.draw.cards.length > 0
      return false

    # each work must either be empty or have a perfect 13 card run of same-suit in it
    for work, workIndex in @state.work
      if work.length == 0
        continue
      if work.length != 13
        # console.log "column #{workIndex} isnt 13 cards"
        return false
      for c, cIndex in work
        info = cardutils.info(c)
        if info.flip
          return false
        if info.value != (12 - cIndex)
          # console.log "column #{workIndex} card #{cIndex} breaks the pattern"
          return false
    return true

export default mode
