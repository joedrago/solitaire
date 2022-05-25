import React, { Component } from 'react'
import { el } from './utils'

class SolitaireView extends Component
  render: ->
    return el 'div', {
      style:
        backgroundColor: '#373'
        width: @props.width
        height: @props.height

      onClick: ->
        console.log "green"
    }

export default SolitaireView
