export BACK = -1
export GUIDE = -2
export RESERVE = -3
export DEAD = -4
export READY = -5
export ROAD = -6
export GRID = -7
export ANVIL = -8
export ATHLETE = -9
export FLARE = -10
export HAMMER = -11
export INFANTRY1 = -12
export INFANTRY2 = -13
export JOKER = -14
export LEADER = -15
export MACHINEGUN = -16
export MORTAR = -17
export NATURAL = -18
export PACIFIST = -19

export FLIP_FLAG = 1024

export shuffle = (array) ->
  for i in [array.length - 1 ... 0] by -1
    j = Math.floor(Math.random() * (i + 1))
    temp = array[i]
    array[i] = array[j]
    array[j] = temp
  return array

calcInfo = (raw) ->
  if raw < 0
    info =
      value: raw
      suit: raw
      flip: raw == BACK
      red: false
  else
    flip = (raw & FLIP_FLAG) == FLIP_FLAG
    raw = raw & ~FLIP_FLAG
    suit = Math.floor(raw / 13)
    value = raw % 13
    valueName = switch value
      when 0 then 'A'
      when 10 then 'J'
      when 11 then 'Q'
      when 12 then 'K'
      else "#{value+1}"
    info =
      value: value
      valueName: valueName
      suit: suit
      flip: flip
      red: (suit > 1)
  return info


export VALIDMOVE_DESCENDING = (1 << 0)
export VALIDMOVE_DESCENDING_WRAP = (1 << 1)
export VALIDMOVE_ALTERNATING_COLOR = (1 << 2)
export VALIDMOVE_ANY_OTHER_SUIT = (1 << 3)
export VALIDMOVE_MATCHING_SUIT = (1 << 4)
export VALIDMOVE_EMPTY_KINGS_ONLY = (1 << 5)
export VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE = (1 << 6)

export validMove = (src, dst, validMoveFlags, foundationBase = null) ->
  srcInfo = calcInfo(src[0])

  if dst.length == 0
    if validMoveFlags & VALIDMOVE_EMPTY_KINGS_ONLY
      return (srcInfo.value == 12)
    else
      return true

  dstInfo = calcInfo(dst[dst.length - 1])
  if (validMoveFlags & VALIDMOVE_ALTERNATING_COLOR) and (srcInfo.red == dstInfo.red)
    return false
  if (validMoveFlags & VALIDMOVE_MATCHING_SUIT) and (srcInfo.suit != dstInfo.suit)
    return false
  if (validMoveFlags & VALIDMOVE_ANY_OTHER_SUIT) and (srcInfo.suit == dstInfo.suit)
    return false
  if (validMoveFlags & VALIDMOVE_DESCENDING) and (srcInfo.value != dstInfo.value - 1)
    return false
  if (validMoveFlags & VALIDMOVE_DESCENDING_WRAP) and ((srcInfo.value != dstInfo.value - 1) and (srcInfo.value != dstInfo.value + 12))
    return false
  if (validMoveFlags & VALIDMOVE_DISALLOW_STACKING_FOUNDATION_BASE) and (dstInfo.value == foundationBase)
    return false

  return true

export alternatesColorDescending = (src, dst, emptyAcceptsOnlyKings = false) ->
  srcInfo = calcInfo(src[0])

  if dst.length == 0
    if emptyAcceptsOnlyKings
      return (srcInfo.value == 12)
    else
      return true

  dstInfo = calcInfo(dst[dst.length - 1])
  if srcInfo.red == dstInfo.red
    return false
  if srcInfo.value != dstInfo.value - 1
    return false

  return true

export descending = (src, dst, emptyAcceptsOnlyKings = false) ->
  srcInfo = calcInfo(src[0])

  if dst.length == 0
    if emptyAcceptsOnlyKings
      return (srcInfo.value == 12)
    else
      return true

  dstInfo = calcInfo(dst[dst.length - 1])
  if srcInfo.value != dstInfo.value - 1
    return false

  return true

export now = ->
  return Math.floor(Date.now())

export qs = (name) ->
  url = window.location.href
  name = name.replace(/[\[\]]/g, '\\$&')
  regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)')
  results = regex.exec(url);
  if not results or not results[2]
    return null
  return decodeURIComponent(results[2].replace(/\+/g, ' '))


export { calcInfo as info }
