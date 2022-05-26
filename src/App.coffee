import React, { Component } from 'react'
import Button from '@mui/material/Button'

import SolitaireView from './SolitaireView'
import { el } from './utils'

class App extends Component
  constructor: (props) ->
    super(props)

    @state =
      width: window.innerWidth
      height: window.innerHeight

  componentDidMount: ->
    window.addEventListener("resize", @onResize.bind(this))

  onResize: ->
    @setState {
      width: window.innerWidth
      height: window.innerHeight
    }

  render: ->
    return el SolitaireView, {
      app: this
      width: @state.width
      height: @state.height
    }

export default App
