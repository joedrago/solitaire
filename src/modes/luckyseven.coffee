import * as cardutils from '../cardutils'

MANEUVER = "Maneuver"

mode =
  name: "Lucky Seven"
  help: """
    | GOAL:

    To be written

    | PLAY:

    To be written

    | HARD MODE:

    To be implemented

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
        show: 0
        cards: []
      foundations: []
      work: []
      grid: []
      phase: MANEUVER

    for colIndex in [0...6]
      row = []
      for rowIndex in [0...4]
        row.push null
        # row.push {
        #   type: null
        #   down: false
        #   flare: false
        #   mortar: false
        # }
      @state.grid.push row

    @state.grid[5][0] = {
      raw: cardutils.INFANTRY1
    }

    # if @hard

  phase: ->
    console.log "lucky seven phase!"

  luckyAct: (sx, sy, dx, dy) ->
    console.log "luckyAct (#{sx}, #{sy}) -> (#{dx}, #{dy})"

    @addTweens [
      {
        d: 1000
        raw: cardutils.GRID
        sx: dx
        sy: dy
        dx: dx
        dy: dy
      }
      {
        d: 1000
        raw: cardutils.INFANTRY1
        sx: -2
        sy: -2
        dx: dx
        dy: dy
      }
    ]

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if (@state.selection.type == 'none') and (type == 'grid')
      if @state.grid[outerIndex][innerIndex]? # don't let people select the ground
        @select(type, outerIndex, innerIndex)
    else
      if type == 'grid'
        @luckyAct(@state.selection.outerIndex, @state.selection.innerIndex, outerIndex, innerIndex)
      @select('none')

    # pileWasEmpty = (@state.pile.cards.length == 0)

    # switch type
    #   # -------------------------------------------------------------------------------------------
    #   when 'draw'
    #     if @state.draw.cards.length > 0
    #       @state.pile.cards.push @state.draw.cards.shift()

    #   # -------------------------------------------------------------------------------------------
    #   when 'work'
    #     col = @state.work[outerIndex]
    #     if col.length > 0
    #       src = col[col.length - 1]
    #       if @golfCanPlay(src)
    #         @state.pile.cards.push col.pop()

    #   # -------------------------------------------------------------------------------------------

    # if pileWasEmpty and (@state.pile.cards.length > 0)
    #   @state.timerStart = cardutils.now()
    # else if not @state.timerEnd?
    #   if @workPileEmpty()
    #     @state.timerEnd = cardutils.now()
    #     @state.timerColor = '#3f3'
    #   else if (@state.draw.cards.length == 0) and not @golfHasPlays()
    #     @state.timerEnd = cardutils.now()
    #     @state.timerColor = '#ff0'

  won: ->
    return false # @workPileEmpty()

  lost: ->
    return false

export default mode
