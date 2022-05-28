import React, { Component } from 'react'

import Box from '@mui/material/Box'
import Drawer from '@mui/material/Drawer'
import Divider from '@mui/material/Divider'

import Dialog from '@mui/material/Dialog'
import DialogActions from '@mui/material/DialogActions'
import DialogContent from '@mui/material/DialogContent'
import DialogContentText from '@mui/material/DialogContentText'
import DialogTitle from '@mui/material/DialogTitle'
import Typography from '@mui/material/Typography'

import Button from '@mui/material/Button'
import IconButton from '@mui/material/IconButton'

import List from '@mui/material/List'
import ListItem from '@mui/material/ListItem'
import ListItemButton from '@mui/material/ListItemButton'
import ListItemIcon from '@mui/material/ListItemIcon'
import ListItemText from '@mui/material/ListItemText'

import GamesIcon from '@mui/icons-material/Games'
import FullscreenIcon from '@mui/icons-material/Fullscreen'
import MenuIcon from '@mui/icons-material/Menu'
import BookIcon from '@mui/icons-material/Book'

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
      helpOpen: false

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

    drawerItems = []
    for modeName, mode of @game.modes
      do (drawerItems, modeName, mode) =>
        drawerItems.push @createDrawerButton "newGame#{modeName}", GamesIcon, "New Game: #{mode.name}", =>
            @game.newGame(modeName)
            @setState {
              drawerOpen: false
              gameState: @game.state
            }

    if fullscreen.available()
      drawerItems.push el Divider, { key: "fullscreenDivider" }
      drawerItems.push @createDrawerButton "fullscreen", FullscreenIcon, "Toggle Fullscreen", =>
        fullscreen.toggle()
        @setState {
          drawerOpen: false
        }

    drawerItems.push el Divider, { key: "helpDivider" }
    drawerItems.push @createDrawerButton "helpMenu", BookIcon, "Rule Help: #{@game.modes[@game.mode].name}", =>
      @setState {
        helpOpen: true
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

    helpDialogTextSplits = @game.modes[@game.mode].help.split(/\n\n/)
    helpTypographies = []
    for text, textIndex in helpDialogTextSplits
      variant = 'body1'
      if matches = text.match(/^\| (.+)/)
        variant = 'h6'
        text = matches[1]
      helpTypographies.push el Typography, {
        key: "helpTypo#{textIndex}"
        gutterBottom: true
        variant: variant
      }, [ text ]

    helpDialog = el Dialog, {
      key: "helpDialog"
      open: @state.helpOpen
      onClose: =>
        @setState {
          helpOpen: false
        }
    }, [
      el DialogTitle, {
        key: "helpDialogTitle"
      }, [ "Rule Help: #{@game.modes[@game.mode].name}" ]
      el DialogContent, {
        key: "helpDialogContent"
        dividers: true
      }, helpTypographies
      el DialogActions, {
        key: "helpDialogActions"
      }, [
        el Button, {
          key: "helpDialogOK"
          onClick: =>
            @setState {
              helpOpen: false
            }
        }, [ "Got it!" ]
      ]
    ]

    return el 'div', {
        key: 'appcontainer'
      }, [
      drawer
      gameView
      menuButton
      winToast
      helpDialog
    ]

  gameClick: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    @game.click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
    @setState {
      gameState: @game.state
      winToastOpen: @game.won()
    }

export default App
