import React, { Component } from 'react'
import { el } from './utils'

import cardsPNG from './cards.png'

class SolitaireView extends Component
  render: ->
    return el 'div', {
      key: 'bg'
      style:
        backgroundColor: '#373'
        width: @props.width
        height: @props.height

      onClick: ->
        console.log "green"
    }, [
      el 'img', {
        key: 'allcards'
        src: cardsPNG
      }
    ]

export default SolitaireView
