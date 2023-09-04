import * as cardutils from '../cardutils'

MANEUVER = "Maneuver"
ATTACK = "Attack"

WON = "You Win!"
LOST = "You Lost!"

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
      log: []
      lastRound: false
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

    @luckyLog("Dealing new game...")

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
    @luckyLog("Killing: #{@luckyName(deadSquad.raw)}", '#fcc')
    deadAdj = @luckyAdjacents(deadSquad.x, deadSquad.y)
    for adj in deadAdj
      if @state.grid[adj.x][adj.y].squad?
        @state.grid[adj.x][adj.y].squad.down = true
        @luckyLog("...knocking down #{@luckyName(@state.grid[adj.x][adj.y].squad.raw)}", '#fff')

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

  luckyName: (raw) ->
    switch raw
      when cardutils.ANVIL
        return "The Anvil"
      when cardutils.ATHLETE
        return "The Athlete"
      when cardutils.HAMMER
        return "The Hammer"
      when cardutils.JOKER
        return "The Joker"
      when cardutils.LEADER
        return "The Leader"
      when cardutils.NATURAL
        return "The Natural"
      when cardutils.PACIFIST
        return "The Pacifist"
      when cardutils.MOUSE
        return "The Mouse"
      when cardutils.MACHINEGUN
        return "Machine Gun"
      when cardutils.FLARE
        return "Flare"
      when cardutils.MORTAR
        return "Mortar"
      when cardutils.TANK
        return "Tank"
      when cardutils.INFANTRY1
        return "Infantry1"
      when cardutils.INFANTRY2
        return "Infantry2"
    return "Unknown"

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

  luckyLog: (text, color = '#fff')->
    @state.log.push {
      text: text
      color: color
    }
    while @state.log.length > cardutils.MAXLOG
      @state.log.shift()

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
    if @state.bads.length < 4
      @state.lastRound = true
    else
      for row in [0...4]
        bad = @state.bads.shift()

        if bad.raw == cardutils.MORTAR
          mortarList = []
          if @state.grid[bad.col][row].squad?
            @state.grid[bad.col][row].squad.down = true
            @state.grid[bad.col][row].squad.tapped = true
            mortarList.push @luckyName(@state.grid[bad.col][row].squad.raw)
          adjs = @luckyAdjacents(bad.col, row)
          for adj in adjs
            if @state.grid[adj.x][adj.y].squad?
              @state.grid[adj.x][adj.y].squad.down = true
              mortarList.push @luckyName(@state.grid[adj.x][adj.y].squad.raw)
          @addTweens [
            @luckyTween "Encounter", {
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
          if mortarList.length == 0
            @luckyLog("Encounter(#{row+1}) Mortar hits: nobody", '#ffc')
          else
            @luckyLog("Encounter(#{row+1}) Mortar hits: #{mortarList.join(', ')}", '#ffc')
        else if bad.raw == cardutils.FLARE
          @luckyLog("Encounter(#{row+1}) Flare!", '#ffc')
          @state.grid[bad.col][row].flare = true
          @addTweens [
            @luckyTween "Encounter", {
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
          @luckyLog("Encounter(#{row+1}) Tank!", '#ffc')
          @state.tank[row] = true
        else # anything else
          col = @luckyAdjustBadCol(bad.col, row)
          if col != -1
            @luckyLog("Encounter(#{row+1}) #{@luckyName(bad.raw)} (column #{col+1})", '#ffc')
            @addTweens [
              @luckyTween "Encounter", {
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

  luckyTween: (fakePhase, data) ->
    t =
      phase: fakePhase
      grid: JSON.parse(JSON.stringify(@state.grid))
    for k,v of data
      t[k] = v
    return t

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
              @luckyLog("Killed: #{@luckyName(@state.grid[sq.tx][sq.ty].bad)}", '#cfc')
              @state.grid[sq.tx][sq.ty].bad = null
              @addTweens [
                @luckyTween "Attacking!", {
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

  luckyCounts: ->
    counts =
      squad: 0
      bads: 0
    for colIndex in [0...6]
      for rowIndex in [0...4]
        sq = @state.grid[colIndex][rowIndex].squad
        if sq?
          counts.squad += 1
        bad = @state.grid[colIndex][rowIndex].bad
        if bad?
          counts.bads += 1
    return counts

  luckyHurtSquad: ->
    for colIndex in [0...6]
      for rowIndex in [0...4]
        sq = @state.grid[colIndex][rowIndex].squad
        if sq?
          adjs = @luckyAdjacents(colIndex, rowIndex)
          for adj in adjs
            if @state.grid[adj.x][adj.y].bad?
              @luckyLog("Killed: #{@luckyName(@state.grid[colIndex][rowIndex].squad.raw)}", '#fcc')
              @state.grid[colIndex][rowIndex].squad = null
              @addTweens [
                @luckyTween "lolesquads", {
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
    console.log "lucky seven phase!", @state
    if (@state.phase == WON) or (@state.phase == LOST)
      return

    alreadyLost = false
    if @state.phase == MANEUVER
      @luckyUntapSquad()
      @state.phase = ATTACK
    else if @state.phase == ATTACK
      @luckyLog("---", '#666')

      # deal damage to mobs, add tweens showing it
      @luckyHurtBads()
      @luckyHurtSquad()

      if @state.lastRound
        # Everything must be dead right here
        counts = @luckyCounts()
        if counts.bads > 0
          alreadyLost = true

      if not alreadyLost
        @luckyUntapSquad()
        @luckyDealBads()
        @state.tank = [false, false, false, false]
        @state.phase = MANEUVER

    if alreadyLost
      @luckyLog("You lose! (Ran out of rounds)", '#fcc')
      @state.phase = LOST
    else
      counts = @luckyCounts()
      if counts.squad == 0
        @luckyLog("You lose! (Everyone is dead)", '#fcc')
        @state.phase = LOST
      else if (counts.bads == 0) and (@state.bads.length == 0)
        @luckyLog("You win!", '#cfc')
        @state.phase = WON

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
    return (@state.phase == WON)

  lost: ->
    return (@state.phase == LOST)

export default mode
