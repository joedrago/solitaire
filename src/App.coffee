import React, { Component } from 'react'
import Button from '@mui/material/Button'

import SolitaireView from './SolitaireView'
import * as render from './render'
import { el } from './utils'

class App extends Component
  constructor: (props) ->
    super(props)

    @state =
      width: window.innerWidth
      height: window.innerHeight
      selection:
        type: 'none'
        outerIndex: 0
        innerIndex: 0

  componentDidMount: ->
    window.addEventListener("resize", @onResize.bind(this))

  onResize: ->
    @setState {
      width: window.innerWidth
      height: window.innerHeight
    }

  render: ->
    gameState =
      draw: 'top'
      selection: @state.selection
      pile: [1,2,3]
      foundations: [0, render.CARD_GUIDE, 2]
      work: [
        # [1,2,3,4,5,6,7,8,9]
        # [1,2,3,4,5,6,7,8,9]
        # [1,2,3,4,5,6,7,8,9]
        # [1,2,3,4,5,6,7,8,9]
        # [1,2,3,4,5,6,7,8,9]
        # [1,2,3,4,5,6,7,8,9]
        # [1,2,3,4,5,6,7,8,9]
        [23,24,25]
        [11,21,31]
        []
        []
        []
        []
        []
      ]

    return el SolitaireView, {
      gameState: gameState
      app: this
      width: @state.width
      height: @state.height
    }

  gameClick: (type, outerIndex, innerIndex) ->
    console.log "gameClick(#{type}, #{outerIndex}, #{innerIndex})"
    @setState {
      selection:
        type: type
        outerIndex: outerIndex
        innerIndex: innerIndex
    }

export default App
