import * as cardutils from '../cardutils'

MANEUVER = "Maneuver"
ATTACK = "Attack"

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

  placeSquad: (squad, xPos, yPos) ->
    for squadIndex in [0...squad.length]
      s = squad[squadIndex]
      squadPos = squadIndex + 1
      for cards, posIndex in xPos
        for v in cards
          if v == squadPos
            s.x = posIndex
      for cards, posIndex in yPos
        for v in cards
          if v == squadPos
            s.y = posIndex

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

    xPos = [
      [1,6]
      [2]
      [3,7]
      [4]
      [5,8]
      []
    ]
    yPos = [
      [1,2]
      [3,4]
      [5,6]
      [7,8]
    ]

    squad = [
      { raw: cardutils.ANVIL }
      { raw: cardutils.ATHLETE }
      { raw: cardutils.HAMMER }
      { raw: cardutils.JOKER }
      { raw: cardutils.LEADER }
      { raw: cardutils.NATURAL }
      { raw: cardutils.PACIFIST }
      { raw: cardutils.MOUSE }
    ]
    cardutils.shuffle(xPos)
    cardutils.shuffle(yPos)
    cardutils.shuffle(squad)
    @placeSquad(squad, xPos, yPos)
    console.log squad

    for colIndex in [0...6]
      row = []
      for rowIndex in [0...4]
        row.push {
         squad: null
         flare: false
         mortar: false
        }
      @state.grid.push row

    for s, sIndex in squad
      if sIndex == squad.length - 1
        break
      @state.grid[s.x][s.y].squad = {
        raw: s.raw
        tapped: false
        down: false
        tx: -1
        ty: -1
      }
    @state.tank = [false, false, false, false]

    deadSquad = squad[squad.length - 1]
    deadAdj = @luckyAdjacents(deadSquad.x, deadSquad.y)
    for adj in deadAdj
      if @state.grid[adj.x][adj.y].squad?
        @state.grid[adj.x][adj.y].squad.down = true

    @state.bads = [
      { raw: cardutils.MACHINEGUN, col:  1 }
      { raw: cardutils.MACHINEGUN, col:  2 }
      { raw: cardutils.MACHINEGUN, col:  3 }
      { raw: cardutils.MACHINEGUN, col:  4 }

      { raw: cardutils.FLARE,      col:  1 }
      { raw: cardutils.FLARE,      col:  2 }
      { raw: cardutils.FLARE,      col:  3 }
      { raw: cardutils.FLARE,      col:  4 }

      { raw: cardutils.MORTAR,     col:  0 }
      { raw: cardutils.MORTAR,     col:  1 }
      { raw: cardutils.MORTAR,     col:  2 }
      { raw: cardutils.MORTAR,     col:  3 }
      { raw: cardutils.MORTAR,     col:  4 }
      { raw: cardutils.MORTAR,     col:  5 }

      { raw: cardutils.TANK,       col: -1 }
      { raw: cardutils.TANK,       col: -1 }

      { raw: cardutils.INFANTRY1,  col:  0 }
      { raw: cardutils.INFANTRY1,  col:  0 }
      { raw: cardutils.INFANTRY1,  col:  1 }
      { raw: cardutils.INFANTRY1,  col:  2 }
      { raw: cardutils.INFANTRY1,  col:  3 }
      { raw: cardutils.INFANTRY1,  col:  4 }
      { raw: cardutils.INFANTRY1,  col:  5 }
      { raw: cardutils.INFANTRY1,  col:  5 }

      { raw: cardutils.INFANTRY2,  col:  0 }
      { raw: cardutils.INFANTRY2,  col:  2 }
      { raw: cardutils.INFANTRY2,  col:  3 }
      { raw: cardutils.INFANTRY2,  col:  5 }
    ]
    cardutils.shuffle(@state.bads)
    @luckyDealBads()

  luckyAdjacents: (x, y) ->
    adj = []
    if x > 0
      adj.push { x: x - 1, y: y }
    if x < 5
      adj.push { x: x + 1, y: y }
    if y > 0
      adj.push { x: x, y: y - 1 }
    if y < 3
      adj.push { x: x, y: y + 1 }
    return adj

  luckyUntapSquad: ->
    for colIndex in [0...6]
      for rowIndex in [0...4]
        @state.grid[colIndex][rowIndex].flare = false
        if @state.grid[colIndex][rowIndex].squad?
          @state.grid[colIndex][rowIndex].squad.tapped = false
          @state.grid[colIndex][rowIndex].squad.tx = -1
          @state.grid[colIndex][rowIndex].squad.ty = -1

  luckyAdjustBadCol: (col, row) ->
    console.log "luckyAdjustBadCol(#{col}, #{row})"
    if not @state.grid[col][row].squad? and not @state.grid[col][row].bad?
      console.log " * check #{col}, #{row} -> nothing was there"
      return col

    innerSign = 1
    if col > 2
      innerSign = -1
    for dist in [0...6]
      for inner in [true, false]
        d = dist * innerSign
        if not inner
          d *= -1
        checkCol = col + d
        if (checkCol < 0) or (checkCol > 5)
          continue
        console.log " * check #{checkCol}, #{row}"
        if not @state.grid[checkCol][row].squad? and not @state.grid[checkCol][row].bad?
          console.log " * check #{checkCol}, #{row} -> closest"
          return checkCol

    console.log " * check #{checkCol}, #{row} -> full row, throw it out"
    return -1

  luckyDealBads: ->
    if @state.bads.length >= 4
      for row in [0...4]
        bad = @state.bads.shift()

        # FINISH OTHER CARD TYPES HERE

        if bad.raw == cardutils.MORTAR
          if @state.grid[bad.col][row].squad?
            @state.grid[bad.col][row].squad.down = true
            @state.grid[bad.col][row].squad.tapped = true
          adjs = @luckyAdjacents(bad.col, row)
          for adj in adjs
            if @state.grid[adj.x][adj.y].squad?
              @state.grid[adj.x][adj.y].squad.down = true
          @addTweens [
            {
              grid: @luckyCloneGrid()
              d: 500
              raw: cardutils.MORTAR
              sx: bad.col
              sy: row
              dx: bad.col
              dy: row
              sr: 0
              dr: 359
            }
          ]
        else if bad.raw == cardutils.FLARE
          @state.grid[bad.col][row].flare = true
          @addTweens [
            {
              grid: @luckyCloneGrid()
              d: 500
              raw: cardutils.FLARE
              sx: bad.col
              sy: row
              dx: bad.col
              dy: row
              sr: 0
              dr: 359
            }
          ]
        else if bad.raw == cardutils.TANK
          @state.tank[row] = true
        else # anything else
          col = @luckyAdjustBadCol(bad.col, row)
          if col != -1
            @addTweens [
              {
                grid: @luckyCloneGrid()
                d: 500
                raw: bad.raw
                sx: -2
                sy: -2
                dx: col
                dy: row
                sr: 270
                dr: 359
              }
            ]
            @state.grid[col][row].bad = bad.raw


  luckyHP: (bad) ->
    switch bad
      when cardutils.MACHINEGUN
        return 3
      when cardutils.INFANTRY2
        return 2
    return 1

  luckyCloneGrid: ->
    return JSON.parse(JSON.stringify(@state.grid))

  luckyHurtBads: ->
    targets = {}
    for colIndex in [0...6]
      for rowIndex in [0...4]
        sq = @state.grid[colIndex][rowIndex].squad
        sqDamage = 1
        if sq? and (sq.tx != -1) and (sq.ty != -1)
          bad = @state.grid[sq.tx][sq.ty].bad
          if bad?
            targetTag = "t-#{sq.tx}-#{sq.ty}"
            if not targets[targetTag]?
              targets[targetTag] =
                x: sq.tx
                y: sq.ty
                hp: @luckyHP(bad)

            console.log "[#{colIndex}, #{rowIndex}] attacking #{targetTag}: ", targets[targetTag]
            if (targets[targetTag].hp > 0) and (targets[targetTag].hp <= sqDamage)
              @state.grid[sq.tx][sq.ty].bad = null
              console.log "[#{colIndex}, #{rowIndex}] attacking #{targetTag}: (DIED)"
              @addTweens [
                {
                  grid: @luckyCloneGrid()
                  d: 500
                  raw: bad
                  sx: sq.tx
                  sy: sq.ty
                  dx: sq.tx
                  dy: sq.ty
                  sr: 0
                  dr: 359
                }
              ]
            targets[targetTag].hp -= sqDamage

  luckyHurtSquad: ->
    for colIndex in [0...6]
      for rowIndex in [0...4]
        sq = @state.grid[colIndex][rowIndex].squad
        if sq?
          adjs = @luckyAdjacents(colIndex, rowIndex)
          for adj in adjs
            if @state.grid[adj.x][adj.y].bad?
              @state.grid[colIndex][rowIndex].squad = null
              @addTweens [
                {
                  grid: @luckyCloneGrid()
                  d: 500
                  raw: sq.raw
                  sx: colIndex
                  sy: rowIndex
                  dx: colIndex
                  dy: rowIndex
                  sr: 0
                  dr: 359
                }
              ]
              break

  phase: ->
    console.log "lucky seven phase!"
    if @state.phase == MANEUVER
      @luckyUntapSquad()
      @state.phase = ATTACK
    else if @state.phase == ATTACK
      # deal damage to mobs, add tweens showing it
      @luckyHurtBads()
      @luckyHurtSquad()
      @luckyUntapSquad()
      @luckyDealBads()
      @state.tank = [false, false, false, false]
      @state.phase = MANEUVER

  luckyCanMoveTo: (sx, sy, dx, dy) ->
    # can't be tapped
    # can't be too far
    # dest can't be enemy
    # dest can't be flare
    # dest can't be tapped squad
    # can't go diagonally between enemies
    return true

  luckyManeuver: (sx, sy, dx, dy) ->
    s = @state.grid[sx][sy].squad
    if s?
      if (sx == dx) and (sy == dy)
        if not s.tapped
          # attempting to stand up / lay down
          s.down = !s.down
          s.tapped = true
      else if not s.tapped
        # attempting to move
        if @luckyCanMoveTo(sx, sy, dx, dy)
          temp = @state.grid[dx][dy].squad
          @state.grid[dx][dy].squad = @state.grid[sx][sy].squad
          @state.grid[sx][sy].squad = temp
          s.tapped = true
          if temp?
            temp.tapped = true

  luckyCanAttack: (sx, sy, dx, dy) ->
    # must target something hittable
    return true

  luckyAttack: (sx, sy, dx, dy) ->
    s = @state.grid[sx][sy].squad
    console.log "luckyAttack", s
    if s? and not s.tapped and (not s.down or (s.raw == cardutils.MOUSE)) and @luckyCanAttack(sx, sy, dx, dy)
      s.tx = dx
      s.ty = dy
      s.tapped = true
      console.log s

  luckyAct: (sx, sy, dx, dy) ->
    console.log "luckyAct (#{sx}, #{sy}) -> (#{dx}, #{dy})"

    if @state.phase == MANEUVER
      @luckyManeuver(sx, sy, dx, dy)
    else if @state.phase == ATTACK
      @luckyAttack(sx, sy, dx, dy)

#    @addTweens [
#      {
#        d: 1000
#        raw: cardutils.GRID
#        sx: dx
#        sy: dy
#        dx: dx
#        dy: dy
#      }
#      {
#        d: 1000
#        raw: cardutils.INFANTRY1
#        sx: -2
#        sy: -2
#        dx: dx
#        dy: dy
#        sr: 0
#        dr: 359
#        so: 0
#        do: 1
#      }
#    ]

  click: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    if (@state.selection.type == 'none') and (type == 'grid')
      if @state.grid[outerIndex][innerIndex].squad? and not @state.grid[outerIndex][innerIndex].squad.tapped
        @select(type, outerIndex, innerIndex)
    else
      if type == 'grid'
        @luckyAct(@state.selection.outerIndex, @state.selection.innerIndex, outerIndex, innerIndex)
      @select('none')

      console.log @state.grid

  won: ->
    return false

  lost: ->
    return false

export default mode
