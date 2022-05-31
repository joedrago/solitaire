export BACK = -1
export GUIDE = -2
export FLIP_FLAG = 1024

export shuffle = (array) ->
  for i in [array.length - 1 ... 0] by -1
    j = Math.floor(Math.random() * (i + 1))
    temp = array[i]
    array[i] = array[j]
    array[j] = temp
  return array

calcInfo = (raw) ->
  if raw == BACK
    info =
      value: BACK
      suit: BACK
      flip: true
      red: false
  else if raw == GUIDE
    info =
      value: GUIDE
      suit: GUIDE
      flip: false
      red: false
  else
    flip = (raw & FLIP_FLAG) == FLIP_FLAG
    raw = raw & ~FLIP_FLAG
    suit = Math.floor(raw / 13)
    info =
      value: raw % 13
      suit: suit
      flip: flip
      red: (suit > 1)
  return info


export VALIDMOVE_DESCENDING = (1 << 0)
export VALIDMOVE_ALTERNATING_COLOR = (1 << 1)
export VALIDMOVE_ANY_OTHER_SUIT = (1 << 2)
export VALIDMOVE_MATCHING_SUIT = (1 << 3)
export VALIDMOVE_EMPTY_KINGS_ONLY = (1 << 4)

export validMove = (src, dst, validMoveFlags) ->
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
