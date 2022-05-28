import React, { Component } from 'react'

import Box from '@mui/material/Box'
import Drawer from '@mui/material/Drawer'
import Divider from '@mui/material/Divider'

import Button from '@mui/material/Button'
import IconButton from '@mui/material/IconButton'

import List from '@mui/material/List'
import ListItem from '@mui/material/ListItem'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'

import AcUnitIcon from '@mui/icons-material/AcUnit'
import BugReportIcon from '@mui/icons-material/BugReport'
import MenuIcon from '@mui/icons-material/Menu'

import Snackbar from '@mui/material/Snackbar'

import SolitaireGame from './SolitaireGame'
import SolitaireView from './SolitaireView'
import * as render from './render'
import fullscreen from './fullscreen'
import { el } from './reactutils'

class App extends Component
  constructor: (props) ->
    super(props)

    @game = new SolitaireGame

    @state =
      width: window.innerWidth
      height: window.innerHeight
      gameState: @game.state
      drawerOpen: false
      winToastOpen: false

  componentDidMount: ->
    window.addEventListener("resize", @onResize.bind(this))

  onResize: ->
    @setState {
      width: window.innerWidth
      height: window.innerHeight
    }

  createDrawerButton: (keyBase, iconClass, text, onClick) ->
    return el ListItem, {
      key: "#{keyBase}Item"
      disablePadding: true
    }, [
      el ListItemButton, {
        key: "#{keyBase}Button"
        onClick: onClick
      }, [
        el ListItemIcon, {
          key: "#{keyBase}ItemIcon"
        }, [
          el iconClass, {
            key: "#{keyBase}Icon"
          }
        ]
        el ListItemText, {
          key: "#{keyBase}Text"
          primary: text
        }, []
      ]
    ]

  render: ->
    gameView = el SolitaireView, {
      key: 'gameview'
      gameState: @state.gameState
      app: this
      width: @state.width
      height: @state.height
    }

    drawerItems = [
      @createDrawerButton "newGameK", AcUnitIcon, "New Game: Klondike", =>
        # if confirm('Start a new Klondike game?')
        @game.newGame('klondike')
        @setState {
          drawerOpen: false
          gameState: @game.state
        }

      @createDrawerButton "newGameS", BugReportIcon, "New Game: Spiderette", =>
        # if confirm('Start a new Spiderette game?')
        @game.newGame('spiderette')
        @setState {
          drawerOpen: false
          gameState: @game.state
        }
    ]

    if fullscreen.available()
      drawerItems.push el Divider, { key: "fullscreenDivider" }
      drawerItems.push @createDrawerButton "fullscreen", BugReportIcon, "Toggle Fullscreen", =>
        fullscreen.toggle()
        @setState {
          drawerOpen: false
        }

    drawer = el Drawer, {
      key: 'drawer'
      anchor: 'right'
      open: @state.drawerOpen
      onClose: =>
        @setState {
          drawerOpen: false
        }
    }, [
      el Box, {
        key: 'drawerBox'
        role: 'presentation'
      }, [
        el List, {
          key: 'drawerList'
        }, drawerItems
      ]
    ]

    menuButton = el IconButton, {
      key: 'menuButton'
      size: 'large'
      style:
        position: 'fixed'
        top: '10px'
        right: '10px'
        color: '#aaa'
      onClick: =>
        @setState {
          drawerOpen: true
        }
    }, [
      el MenuIcon, { key: 'menuButtonIcon' }
    ]

    winToastAction = el React.Fragment, {
      key: 'winToastFragment'
    }, [
      el Button, {
        key: 'winToastButton'
        color: 'primary'
        size: 'small'
        onClick: =>
          @game.newGame()
          @setState {
            drawerOpen: false
            winToastOpen: false
            gameState: @game.state
          }
      }, ['Play Again']
    ]

    winToast = el Snackbar, {
      key: 'winToast'
      open: @state.winToastOpen
      autoHideDuration: 10000
      anchorOrigin:
        vertical: 'top'
        horizontal: 'center'
      message: "You Win!"
      action: winToastAction
      onClose: =>
        @setState {
          winToastOpen: false
        }
    }

    return el 'div', {
        key: 'appcontainer'
      }, [
      drawer
      gameView
      menuButton
      winToast
    ]

  gameClick: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    @game.click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
    @setState {
      gameState: @game.state
      winToastOpen: @game.won()
    }

export default App
