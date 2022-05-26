import React, { Component } from 'react'
import Button from '@mui/material/Button'

import SolitaireGame from './SolitaireGame'
import SolitaireView from './SolitaireView'
import * as render from './render'
import { el } from './utils'

class App extends Component
  constructor: (props) ->
    super(props)

    @game = new SolitaireGame

    @state =
      width: window.innerWidth
      height: window.innerHeight
      gameState: @game.state

  componentDidMount: ->
    window.addEventListener("resize", @onResize.bind(this))

  onResize: ->
    @setState {
      width: window.innerWidth
      height: window.innerHeight
    }

  render: ->
    return el SolitaireView, {
      gameState: @state.gameState
      app: this
      width: @state.width
      height: @state.height
    }

  gameClick: (type, outerIndex, innerIndex) ->
    @game.click(type, outerIndex, innerIndex)
    @setState {
      gameState: @game.state
    }

export default App
