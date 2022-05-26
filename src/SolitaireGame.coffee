import * as render from './render'

DEBUG_DONT_SAVE = true

# -------------------------------------------------------------------------------------------------
# Helpers

shuffleArray = (array) ->
  for i in [array.length - 1 ... 0] by -1
    j = Math.floor(Math.random() * (i + 1))
    temp = array[i]
    array[i] = array[j]
    array[j] = temp
  return array

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

    if not @load()
      @newGame()

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

  click: (type, outerIndex, innerIndex) ->
    console.log "game.click(#{type}, #{outerIndex}, #{innerIndex})"
    if @modes[@mode]?
      @modes[@mode].click(type, outerIndex, innerIndex)
      @queueSave()


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
        show: 3
        cards: []
      foundations: [render.CARD_GUIDE, render.CARD_GUIDE, render.CARD_GUIDE, render.CARD_GUIDE]
      work: []

    deck = shuffleArray([0...52])
    for columnIndex in [0...7]
      col = []
      for i in [0...columnIndex]
        col.push(deck.shift() | render.CARD_FLIP_FLAG)
      col.push(deck.shift())
      @state.work.push col

    @state.draw.cards = deck

  klondikeClick: (type, outerIndex, innerIndex) ->
    if type == 'draw'
      if @state.draw.cards.length == 0
        @state.draw.cards = shuffleArray(@state.pile.cards)
        @state.pile.cards = []
      else
        cardsToDraw = @state.pile.show
        if cardsToDraw > @state.draw.cards.length
          cardsToDraw = @state.draw.cards.length
        for i in [0...cardsToDraw]
          @state.pile.cards.push @state.draw.cards.shift()
      console.log @state.draw.cards
      console.log @state.pile.cards

      @state.selection.type = 'none'

    else if type == 'pile'
      # Selecting the top card on the draw pile
      @state.selection.type = 'pile'

    else if type == 'foundation'
      console.log "TODO: FOUNDATION"

    else if type == 'work'
      if (@state.selection.type == 'pile')
        # Trying to play a card from a pile onto a work
        dstCol = @state.work[outerIndex]
        dstCol.push @state.pile.cards.pop()
        @state.selection.type = 'none'

      else if (@state.selection.type == 'work') and (@state.selection.outerIndex != outerIndex)
        # Trying to move cards from one work to another work
        srcCol = @state.work[@state.selection.outerIndex]
        movedCards = []
        while @state.selection.innerIndex < srcCol.length
          movedCards.unshift srcCol.pop()

        if srcCol.length > 0
          # reveal any face down cards
          srcCol[srcCol.length - 1] = srcCol[srcCol.length - 1] & ~render.CARD_FLIP_FLAG

        dstCol = @state.work[outerIndex]
        for m in movedCards
          dstCol.push m

        @state.selection.type = 'none'

      else
        # Selecting a fresh column
        col = @state.work[outerIndex]
        while (innerIndex < col.length) and (col[innerIndex] & render.CARD_FLIP_FLAG)
          # Don't select face down cards
          innerIndex += 1
        @state.selection =
          type: type
          outerIndex: outerIndex
          innerIndex: innerIndex

    else
      # Probably a background click, just forget the selection
      @state.selection.type = 'none'

  # -----------------------------------------------------------------------------------------------

export default SolitaireGame
