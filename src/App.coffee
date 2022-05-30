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
import Switch from '@mui/material/Switch'

import GamesIcon from '@mui/icons-material/Games'
import FullscreenIcon from '@mui/icons-material/Fullscreen'
import MenuIcon from '@mui/icons-material/Menu'
import BookIcon from '@mui/icons-material/Book'
import ReplayIcon from '@mui/icons-material/Replay'
import SickIcon from '@mui/icons-material/Sick'
import UndoIcon from '@mui/icons-material/Undo'

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
      loseToastOpen: false
      helpOpen: false
      hard: @game.hard

  componentDidMount: ->
    window.addEventListener("resize", @onResize.bind(this))

  onResize: ->
    @setState {
      width: window.innerWidth
      height: window.innerHeight
    }

  createDrawerButton: (keyBase, iconClass, text, onClick, switchValue = null, disabled = false) ->
    buttonPieces = [
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
    if switchValue?
      buttonPieces.push el Switch, {
        key: "#{keyBase}Switch"
        color: 'secondary'
        edge: "end"
        checked: switchValue
        # onChange={handleToggle('wifi')}
        # checked={checked.indexOf('wifi') !== -1}
      }

    return el ListItem, {
      key: "#{keyBase}Item"
      disablePadding: true
    }, [
      el ListItemButton, {
        key: "#{keyBase}Button"
        onClick: onClick
        disabled: disabled
      }, buttonPieces
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

    drawerItems.push @createDrawerButton "playAgainMenu", ReplayIcon, "Play Again: #{@game.modes[@game.mode].name}", =>
      @game.newGame()
      @setState {
        drawerOpen: false
        gameState: @game.state
      }
    drawerItems.push el Divider, { key: "playAgainDivider" }

    drawerItems.push @createDrawerButton "helpMenu", BookIcon, "Rule Help: #{@game.modes[@game.mode].name}", =>
      @setState {
        helpOpen: true
        drawerOpen: false
      }
    drawerItems.push @createDrawerButton "hardMenu", SickIcon, "Hard Mode", =>
      @game.hard = !@game.hard
      @game.save()
      @setState {
        hard: @game.hard
      }
    , @game.hard
    drawerItems.push el Divider, { key: "helpDivider" }

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

    drawerItems.push el Divider, { key: "undoDivider" }
    drawerItems.push @createDrawerButton "undoButton", UndoIcon, "Undo", =>
      @game.undo()
      @setState {
        gameState: @game.state
      }
    , null, !@game.canUndo()

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
      }, ['Play Again?']
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

    loseToastAction = el React.Fragment, {
      key: 'loseToastFragment'
    }, [
      el Button, {
        key: 'loseToastButton'
        color: 'primary'
        size: 'small'
        onClick: =>
          @game.newGame()
          @setState {
            drawerOpen: false
            loseToastOpen: false
            gameState: @game.state
          }
      }, ['Play Again?']
    ]

    loseToast = el Snackbar, {
      key: 'loseToast'
      open: @state.loseToastOpen
      autoHideDuration: 10000
      anchorOrigin:
        vertical: 'top'
        horizontal: 'center'
      message: "You Lose."
      action: loseToastAction
      onClose: =>
        @setState {
          loseToastOpen: false
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

    gameText = el 'div', {
      key: 'bottomRightName'
      style:
        position: 'fixed'
        right: 10
        bottom: 10
        fontFamily: 'monospace'
        fontSize: '1.2em'
        color: '#fff'
        textShadow: '2px 2px #000'
    }, [ "#{@game.modes[@game.mode].name}: #{if @game.state.hard then 'Hard' else 'Easy'}" ]

    return el 'div', {
        key: 'appcontainer'
      }, [
      drawer
      gameView
      menuButton
      winToast
      loseToast
      helpDialog
      gameText
    ]

  gameClick: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    @game.click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
    @setState {
      gameState: @game.state
      winToastOpen: @game.won()
      loseToastOpen: @game.lost()
    }

export default App
