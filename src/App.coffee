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
import { qs } from './cardutils'

easter =
  imageW: 0
  imageH: 0
  imageO: 0
  gameO: 0
  gameR: 0
  gameT: 0
  gameB: 0

easterOpacity = 1
easterName = qs('e')
if window.easterDB? and easterName?
  if not window.easterDB[easterName]?
    # pick one at random
    names = Object.keys(window.easterDB)
    easterName = names[Math.floor(Math.random() * names.length)]
  easter = window.easterDB[easterName]
  easter.name = easterName
  easterOpacity = 0.2

  for soundIndex in [0...easter.random.length]
    easter.random[soundIndex] = new Audio("easter/#{easter.random[soundIndex]}")
    easter.random[soundIndex].volume = 0.4
  for soundIndex in [0...easter.win.length]
    easter.win[soundIndex] = new Audio("easter/#{easter.win[soundIndex]}")
    easter.win[soundIndex].volume = 0.4

  console.log "easter: ", easter

lastPlayed = null
easterPlay = (which) ->
  if not easter.name?
    return
  if lastPlayed?
    lastPlayed.pause()
    lastPlayed = null
  soundIndex = Math.floor(Math.random() * easter[which].length)
  lastPlayed = easter[which][soundIndex]
  lastPlayed.play()

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
      useTouch: false # navigator.maxTouchPoints? and (navigator.maxTouchPoints > 0)

  componentDidMount: ->
    window.addEventListener("resize", @onResize.bind(this))
    window.addEventListener("orientationchange", @onResize.bind(this))

    if not @state.useTouch
      touchDetector = =>
        console.log "Solitaire: touch detected! Switching to touch mode."
        window.removeEventListener('touchstart', touchDetector, false)
        @setState {
          useTouch: true
        }
      window.addEventListener 'touchstart', touchDetector

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
    easterScale = 1
    if easter.name?
      easterScale = @state.height * easter.charHeight / easter.imageH
      charIndex = 0
      if @state.winToastOpen
        charIndex = 1
      char = el 'div', {
        key: 'easterChar'
        style:
          backgroundImage: "url(easter/#{easter.images[charIndex]})"
          backgroundSize: 'contain'
          backgroundPosition: "#{Math.floor(easter.imageO * easterScale)}px 0px"
          backgroundRepeat: 'no-repeat'
          position: 'absolute'
          left: "0px"
          bottom: "0px"
          width: "#{easter.imageW * easterScale}px"
          height: "#{easter.imageH * easterScale}px"
      }

      bg = el 'img', {
        key: 'easterBG'
        src: "easter/#{easter.bg}"
        style:
          position: 'fixed'
          left: '0px'
          top: '0px'
          width: '100%'
          height: '100%'
      }

      br = el 'img', {
        key: 'easterBR'
        src: "easter/br.png"
        style:
          position: 'fixed'
          bottom: '0px'
          right: '0px'
          height: "#{Math.floor(@state.height * 0.2)}px"
      }

      title = el 'img', {
        key: 'easterTitle'
        src: "easter/#{easter.title}"
        style:
          height: "#{easter.gameT * @state.height}px"
      }
      titleDiv = el 'div', {
        key: 'easterTitleDiv'
        style:
          position: 'fixed'
          left: '0px'
          top: '0px'
          textAlign: 'center'
          display: 'block'
          width: '100%'
      }, [ title ]

      easterView = el 'div', {
        key: 'easterView'
        style:
          position: 'fixed'
          width: '100%'
          height: '100%'
          zIndex: -50
      }, [ bg, titleDiv, br, char ]
    else
      easterView = el 'div', {
        key: 'easterView'
        style:
          display: 'none'
      }

    gameView = el SolitaireView, {
      key: 'gameview'
      gameState: @state.gameState
      canAutoWin: @game.canAutoWin()
      app: this
      x: easter.gameO * easterScale
      y: easter.gameT * @state.height
      width: @state.width - ((easter.gameO + easter.gameR) * easterScale)
      height: @state.height - ((easter.gameT + easter.gameB) * @state.height)
      opacity: easterOpacity
      useTouch: @state.useTouch
    }

    drawerItems = []

    drawerItems.push @createDrawerButton "undoButton", UndoIcon, "Undo", =>
      easterPlay('random')
      @game.undo()
      @setState {
        gameState: @game.state
      }
    , null, !@game.canUndo()
    drawerItems.push el Divider, { key: "undoDivider" }

    drawerItems.push @createDrawerButton "helpMenu", BookIcon, "Rule Help: #{@game.modes[@game.mode].name}", =>
      @setState {
        helpOpen: true
        drawerOpen: false
      }
    drawerItems.push el Divider, { key: "helpDivider" }

    drawerItems.push @createDrawerButton "hardMenu", SickIcon, "Hard Mode", =>
      @game.hard = !@game.hard
      @game.save()
      @setState {
        hard: @game.hard
      }
    , @game.hard
    drawerItems.push @createDrawerButton "playAgainMenu", ReplayIcon, "Play Again: #{@game.modes[@game.mode].name}", =>
      easterPlay('win')
      @game.newGame()
      @setState {
        drawerOpen: false
        gameState: @game.state
      }
    drawerItems.push el Divider, { key: "playAgainDivider" }

    for modeName, mode of @game.modes
      do (drawerItems, modeName, mode) =>
        drawerItems.push @createDrawerButton "newGame#{modeName}", GamesIcon, "New Game: #{mode.name}", =>
            easterPlay('win')
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
        color: '#000'
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
      key: 'bottomRightText'
      style:
        position: 'fixed'
        right: 10
        bottom: 10
        textAlign: 'right'
        fontFamily: 'monospace'
        fontSize: '1.2em'
        color: '#fff'
        textShadow: '2px 2px #000'
    }, [
      el 'div', {
        key: "buildVersion"
        style:
          color: '#6a6'
      }, "#{WEBPACK_BUILD_VERSION}"
      el 'div', { key: "gameAndDiff" }, "#{@game.modes[@game.mode].name}#{if @game.state.hard then ' (Hard)' else ''}"
    ]

    return el 'div', {
        key: 'appcontainer'
      }, [
      drawer
      easterView
      gameView
      menuButton
      winToast
      loseToast
      helpDialog
      gameText
    ]

  gameClick: (type, outerIndex, innerIndex, isRightClick, isMouseUp) ->
    @game.click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
    if not @state.winToastOpen && @game.won()
      easterPlay('win')
    @setState {
      gameState: @game.state
      winToastOpen: @game.won()
      loseToastOpen: @game.lost()
    }

  sendAny: ->
    sent = @game.sendAny()
    if not @state.winToastOpen && @game.won()
      easterPlay('win')
    @setState {
      gameState: @game.state
      winToastOpen: @game.won()
      loseToastOpen: @game.lost()
    }
    return sent

export default App
