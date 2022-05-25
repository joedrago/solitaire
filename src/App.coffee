import React, { Component } from 'react'
import Button from '@mui/material/Button'
import { el } from './utils'

class App extends Component
  render: ->
    return el Button, {
      variant: 'outlined'
      style:
        position: 'fixed'
        top: 200,
        left: 200,

      onClick: ->
        console.log "clack"

    }, "Hello"

export default App
