import * as cardutils from './cardutils'

DEBUG_DONT_SAVE = true

# -------------------------------------------------------------------------------------------------

class SolitaireGame
  constructor: ->
    @saveTimeout = null
    @state = null
    @mode = 'klondike'
    @modes =
      klondike:
        newGame: @klondikeNewGame.bind(this)
        click: @klondikeClick.bind(this)
      spiderette:
        newGame: @spideretteNewGame.bind(this)
        click: @spideretteClick.bind(this)

    if not @load()
      @newGame()

  # -----------------------------------------------------------------------------------------------
  # Generic input handlers

  load: ->
    if DEBUG_DONT_SAVE
      return false
    rawPayload = localStorage.getItem('save')
    if not rawPayload?
      return false

    try
      payload = JSON.parse(rawPayload)
    catch
      return false

    @mode = payload.mode
    @state = payload.state
    console.log "Loaded."
    return true

  save: ->
    if DEBUG_DONT_SAVE
      return
    payload =
      mode: @mode
      state: @state
    localStorage.setItem('save', JSON.stringify(payload))
    console.log "Saved."

  queueSave: ->
    if @saveTimeout?
      clearTimeout(@saveTimeout)
    @saveTimeout = setTimeout =>
      @save()
      @saveTimeout = null
    , 3000

  # -----------------------------------------------------------------------------------------------
  # Generic input handlers

  newGame: (newMode = null) ->
    if newMode? and @modes[newMode]?
      @mode = newMode
    if @modes[@mode]?
      @modes[@mode].newGame()
      @queueSave()

  click: (type, outerIndex = 0, innerIndex = 0, isRightClick = false) ->
    console.log "game.click(#{type}, #{outerIndex}, #{innerIndex}, #{isRightClick})"
    if @modes[@mode]?
      @modes[@mode].click(type, outerIndex, innerIndex, isRightClick)
      @queueSave()

  # -----------------------------------------------------------------------------------------------
  # Generic helpers

  findFoundationSuitIndex: (raw) ->
    if @state.foundations.length == 0
      return -1

    # find a matching suit
    srcInfo = cardutils.info(raw)
    for f, fIndex in @state.foundations
      if f >= 0
        dstInfo = cardutils.info(f)
        if srcInfo.suit == dstInfo.suit
          return fIndex

    # find a free slot
    for f, fIndex in @state.foundations
      if f < 0
        return fIndex

    return -1

  dumpCards: (prefix, cards) ->
    infos = []
    for card in cards
      infos.push cardutils.info(card)
    console.log prefix, infos

  # -----------------------------------------------------------------------------------------------
  # Selection

  select: (type, outerIndex = 0, innerIndex = 0) ->
    if (@state.selection.type == type) and (@state.selection.outerIndex == outerIndex) and (@state.selection.innerIndex == innerIndex)
      # Toggle
      type = 'none'
      outerIndex = 0
      innerIndex = 0

    @state.selection =
      type: type
      outerIndex: outerIndex
      innerIndex: innerIndex

  eatSelection: ->
    switch @state.selection.type
      when 'pile'
        @state.pile.cards.pop()
      when 'work'
        srcCol = @state.work[@state.selection.outerIndex]
        while @state.selection.innerIndex < srcCol.length
          srcCol.pop()
        if srcCol.length > 0
          # reveal any face down cards
          srcCol[srcCol.length - 1] = srcCol[srcCol.length - 1] & ~cardutils.FLIP_FLAG

  getSelection: ->
    selectedCards = []
    switch @state.selection.type
      when 'pile'
        if @state.pile.cards.length > 0
          selectedCards.push @state.pile.cards[@state.pile.cards.length - 1]
      when 'work'
        srcCol = @state.work[@state.selection.outerIndex]
        index = @state.selection.innerIndex
        while index < srcCol.length
          selectedCards.push srcCol[index]
          index += 1

    return selectedCards

  # -----------------------------------------------------------------------------------------------
  # Mode: Klondike

  klondikeNewGame: ->
    @state =
      draw:
        pos: 'top'
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

    deck = cardutils.shuffle([0...52])
    for columnIndex in [0...7]
      col = []
      for i in [0...columnIndex]
        col.push(deck.shift() | cardutils.FLIP_FLAG)
      col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck

  klondikeSendHome: (type, outerIndex, innerIndex) ->
    src = @getSelection()
    if src.length != 1
      return false

    srcInfo = cardutils.info(src[0])
    dstIndex = @findFoundationSuitIndex(src[0])
    if dstIndex >= 0
      sendHome = false
      if @state.foundations[dstIndex] >= 0
        dstInfo = cardutils.info(@state.foundations[dstIndex])
        if srcInfo.value == dstInfo.value + 1
          sendHome = true
      else
        if srcInfo.value == 0 # Ace
          sendHome = true

      if sendHome
        @state.foundations[dstIndex] = src[0]
        @eatSelection()
        @select('none')
        return true
    return false

  klondikeClick: (type, outerIndex, innerIndex, isRightClick) ->
    switch type
      # -------------------------------------------------------------------------------------------
      when 'draw'
        # Draw some cards
        if @state.draw.cards.length == 0
          @state.draw.cards = cardutils.shuffle(@state.pile.cards)
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

            if cardutils.validMove(src, dst, cardutils.VALIDMOVE_DESCENDING | cardutils.VALIDMOVE_ALTERNATING_COLOR | cardutils.VALIDMOVE_EMPTY_KINGS_ONLY)
              for c in src
                dst.push c
              @eatSelection()

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

    if isRightClick
      @klondikeSendHome(type, outerIndex, innerIndex)
      @select('none')

  # -----------------------------------------------------------------------------------------------
  # Mode: Spiderette

  spideretteNewGame: ->
    @state =
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
    for columnIndex in [0...7]
      col = []
      for i in [0...3]
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
            @dumpCards "BEFORE REMOVE: ", @state.work[workIndex]
            @state.work[workIndex].splice(kingPos, 13)
            @dumpCards "AFTER REMOVE: ", @state.work[workIndex]

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

  spideretteClick: (type, outerIndex, innerIndex, isRightClick) ->
    # if isRightClick
    #   @spideretteDeal()
    #   return

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

  # -----------------------------------------------------------------------------------------------

export default SolitaireGame
