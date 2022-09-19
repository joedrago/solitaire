import * as cardutils from './cardutils'

# -------------------------------------------------------------------------------------------------

class SolitaireGame
  constructor: ->
    @saveTimeout = null
    @state = null
    @mode = 'klondike'
    @hard = false # this is the toggle for the *next* game. Check @state.hard to see if *this* game is hard
    @undoStack = []

    @modes = {}
    @loadMode('baker')
    @loadMode('eagle')
    @loadMode('freecell')
    @loadMode('golf')
    @loadMode('klondike')
    @loadMode('scorpion')
    @loadMode('spider')
    @loadMode('spiderette')
    @loadMode('yukon')

    if not @load()
      @newGame()

  # -----------------------------------------------------------------------------------------------
  # Mode Manipulation

  loadMode: (modeName) ->
    modeFuncs =
      newGame: true
      click: true
      won: true
      lost: true

    modeProps =
      name: true
      help: true

    m = require("./modes/#{modeName}").default
    @modes[modeName] = {}

    for key, val of m
      if modeFuncs[key]
        @modes[modeName][key] = val.bind(this)
      else if modeProps[key]
        @modes[modeName][key] = val
      else
        this[key] = val.bind(this)

  # -----------------------------------------------------------------------------------------------
  # Generic input handlers

  load: ->
    # return false

    rawPayload = localStorage.getItem('save')
    if not rawPayload?
      return false

    try
      payload = JSON.parse(rawPayload)
    catch
      return false

    @mode = payload.mode
    @hard = payload.hard == true
    @state = payload.state
    @undoStack = []
    console.log "Loaded."
    return true

  save: ->
    # return

    payload =
      mode: @mode
      hard: @hard
      state: @state
    localStorage.setItem('save', JSON.stringify(payload))
    # console.log "Saved."

  queueSave: ->
    # Don't bother queueing, just save immediately
    @save()

    # if @saveTimeout?
    #   clearTimeout(@saveTimeout)
    # @saveTimeout = setTimeout =>
    #   @save()
    #   @saveTimeout = null
    # , 3000

  # -----------------------------------------------------------------------------------------------
  # Undo

  canUndo: ->
    return @undoStack.length > 0

  pushUndo: ->
    @undoStack.push JSON.stringify(@state)

  undo: ->
    if @undoStack.length > 0
      @state = JSON.parse(@undoStack.pop())
      @queueSave()

  # -----------------------------------------------------------------------------------------------
  # Generic input handlers

  newGame: (newMode = null) ->
    if newMode? and @modes[newMode]?
      @mode = newMode
    if @modes[@mode]?
      @modes[@mode].newGame()
      @undoStack = []
      @save()

  click: (type, outerIndex = 0, innerIndex = 0, isRightClick = false, isMouseUp = false) ->
    console.log "game.click(#{type}, #{outerIndex}, #{innerIndex}, #{isRightClick}, #{isMouseUp})"
    if @modes[@mode]?
      if not isMouseUp
        @pushUndo()
      @modes[@mode].click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
      @queueSave()

  won: ->
    if @modes[@mode]?
      return @modes[@mode].won()
    return false

  lost: ->
    if @modes[@mode]? and @modes[@mode].lost?
      return @modes[@mode].lost()
    return false

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

  workPileEmpty: ->
    for work in @state.work
      if work.length > 0
        return false
    return true

  reserveEmpty: ->
    if not @state.reserve?
      return true
    for cols in @state.reserve.cols
      if cols.length > 0
        return false
    return true

  canAutoWin: ->
    if @won()
      # console.log "canAutoWin: false (won)"
      return false
    if @state.foundations.length == 0
      # console.log "canAutoWin: false (no foundations)"
      return false
    if @state.draw.cards.length > 0
      # console.log "canAutoWin: false (has draw)"
      return false
    if @state.pile.cards.length > 0
      # console.log "canAutoWin: false (has pile)"
      return false
    if @state.reserve?
      for col in @state.reserve.cols
        if col.length > 0
          # console.log "canAutoWin: false (has reserves)"
          return false
    for col, colIndex in @state.work
      last = 100
      for raw in col
        if raw & cardutils.FLIP_FLAG
          # console.log "canAutoWin: false (has flip)"
          return false
        info = cardutils.info(raw)
        if info.value > last
          # console.log "canAutoWin: false (not descending #{colIndex})"
          return false
        last = info.value
    # console.log "canAutoWin: true"
    return true

  sendHome: (type, outerIndex, innerIndex) ->
    src = null
    switch type
      when 'pile'
        if @state.pile.cards.length > 0
          src = @state.pile.cards[@state.pile.cards.length - 1]
      when 'reserve'
        if @state.reserve? and (@state.reserve.cols.length > outerIndex) and (@state.reserve.cols[outerIndex].length > 0)
          src = @state.reserve.cols[outerIndex][@state.reserve.cols[outerIndex].length - 1]
      when 'work'
        srcCol = @state.work[outerIndex]
        if innerIndex != srcCol.length - 1
          return false
        src = srcCol[innerIndex]

    if not src?
      return null

    srcInfo = cardutils.info(src)
    dstIndex = @findFoundationSuitIndex(src)
    if dstIndex >= 0
      sendHome = false
      if @state.foundations[dstIndex] >= 0
        dstInfo = cardutils.info(@state.foundations[dstIndex])
        if (srcInfo.value == dstInfo.value + 1) or (srcInfo.value == dstInfo.value - 12)
          sendHome = true
      else
        foundationBase = 0 # Ace
        if @state.foundationBase?
          foundationBase = @state.foundationBase
        if srcInfo.value == foundationBase
          sendHome = true

      if sendHome
        prevFoundationRaw = @state.foundations[dstIndex]
        @state.foundations[dstIndex] = src
        switch type
          when 'pile'
            @state.pile.cards.pop()
          when 'reserve'
            @state.reserve.cols[outerIndex].pop()
          when 'work'
            srcCol.pop()
            if srcCol.length > 0
              # reveal any face down cards
              srcCol[srcCol.length - 1] = srcCol[srcCol.length - 1] & ~cardutils.FLIP_FLAG
        @select('none')
        return {
          raw: src
          prevOuterIndex: outerIndex
          prevInnerIndex: innerIndex
          foundationIndex: dstIndex
          prevFoundationRaw: prevFoundationRaw
        }
    return null

  sendAny: ->
    if not @canAutoWin()
      return null
    for work, workIndex in @state.work
      if work.length > 0
        sent = @sendHome('work', workIndex, work.length - 1)
        if sent?
          @queueSave()
          return sent
    return null

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
      when 'reserve'
        if @state.reserve?
          @state.reserve.cols[@state.selection.outerIndex].pop()
      when 'work'
        srcCol = @state.work[@state.selection.outerIndex]
        if @state.selection.innerIndex >= 0
          while @state.selection.innerIndex < srcCol.length
            srcCol.pop()
        if srcCol.length > 0
          # reveal any face down cards
          srcCol[srcCol.length - 1] = srcCol[srcCol.length - 1] & ~cardutils.FLIP_FLAG
    @select('none')

  getSelection: ->
    selectedCards = []
    switch @state.selection.type
      when 'pile'
        if @state.pile.cards.length > 0
          selectedCards.push @state.pile.cards[@state.pile.cards.length - 1]
      when 'reserve'
        if @state.reserve?
          col = @state.reserve.cols[@state.selection.outerIndex]
          if col.length > 0
            selectedCards.push col[col.length - 1]
      when 'work'
        srcCol = @state.work[@state.selection.outerIndex]
        index = @state.selection.innerIndex
        while index < srcCol.length
          selectedCards.push srcCol[index]
          index += 1

    return selectedCards

  # -----------------------------------------------------------------------------------------------

export default SolitaireGame
