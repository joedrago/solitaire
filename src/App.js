/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
import React, { Component } from "react"

import Box from "@mui/material/Box"
import Drawer from "@mui/material/Drawer"
import Divider from "@mui/material/Divider"

import Dialog from "@mui/material/Dialog"
import DialogActions from "@mui/material/DialogActions"
import DialogContent from "@mui/material/DialogContent"
import DialogContentText from "@mui/material/DialogContentText"
import DialogTitle from "@mui/material/DialogTitle"
import Typography from "@mui/material/Typography"

import Button from "@mui/material/Button"
import IconButton from "@mui/material/IconButton"

import List from "@mui/material/List"
import ListItem from "@mui/material/ListItem"
import ListItemButton from "@mui/material/ListItemButton"
import ListItemIcon from "@mui/material/ListItemIcon"
import ListItemText from "@mui/material/ListItemText"
import Switch from "@mui/material/Switch"

import GamesIcon from "@mui/icons-material/Games"
import FullscreenIcon from "@mui/icons-material/Fullscreen"
import MenuIcon from "@mui/icons-material/Menu"
import BookIcon from "@mui/icons-material/Book"
import ReplayIcon from "@mui/icons-material/Replay"
import SickIcon from "@mui/icons-material/Sick"
import UndoIcon from "@mui/icons-material/Undo"

import Snackbar from "@mui/material/Snackbar"

import SolitaireGame from "./SolitaireGame"
import SolitaireView from "./SolitaireView"
import * as render from "./render"
import * as cardutils from "./cardutils"
import fullscreen from "./fullscreen"
import { el } from "./reactutils"

class App extends Component {
    constructor(props) {
        super(props)

        this.tweens = []
        this.nextTweenID = 1

        this.game = new SolitaireGame()
        this.game.app = this

        this.state = {
            width: window.innerWidth,
            height: window.innerHeight,
            gameState: this.game.state,
            drawerOpen: false,
            winToastOpen: false,
            loseToastOpen: false,
            helpOpen: false,
            hard: this.game.hard,
            useTouch: false // navigator.maxTouchPoints? and (navigator.maxTouchPoints > 0)
        }
    }

    componentDidMount() {
        window.addEventListener("resize", this.onResize.bind(this))
        window.addEventListener("orientationchange", this.onResize.bind(this))

        if (!this.state.useTouch) {
            var touchDetector = () => {
                console.log("Solitaire: touch detected! Switching to touch mode.")
                window.removeEventListener("touchstart", touchDetector, false)
                return this.setState({
                    useTouch: true
                })
            }
            return window.addEventListener("touchstart", touchDetector)
        }
    }

    onResize() {
        return this.setState({
            width: window.innerWidth,
            height: window.innerHeight
        })
    }

    createDrawerButton(keyBase, iconClass, text, onClick, switchValue = null, disabled) {
        if (disabled == null) {
            disabled = false
        }
        const buttonPieces = [
            el(
                ListItemIcon,
                {
                    key: `${keyBase}ItemIcon`
                },
                [
                    el(iconClass, {
                        key: `${keyBase}Icon`
                    })
                ]
            ),
            el(
                ListItemText,
                {
                    key: `${keyBase}Text`,
                    primary: text
                },
                []
            )
        ]
        if (switchValue != null) {
            buttonPieces.push(
                el(Switch, {
                    key: `${keyBase}Switch`,
                    color: "secondary",
                    edge: "end",
                    checked: switchValue
                    // onChange={handleToggle('wifi')}
                    // checked={checked.indexOf('wifi') !== -1}
                })
            )
        }

        return el(
            ListItem,
            {
                key: `${keyBase}Item`,
                disablePadding: true
            },
            [
                el(
                    ListItemButton,
                    {
                        key: `${keyBase}Button`,
                        onClick,
                        disabled
                    },
                    buttonPieces
                )
            ]
        )
    }

    render() {
        let mode
        const gameView = el(SolitaireView, {
            key: "gameview",
            gameState: this.state.gameState,
            canAutoWin: this.game.canAutoWin(),
            app: this,
            width: this.state.width,
            height: this.state.height,
            useTouch: this.state.useTouch
        })

        const drawerItems = []

        drawerItems.push(
            this.createDrawerButton(
                "undoButton",
                UndoIcon,
                "Undo",
                () => {
                    this.game.undo()
                    return this.setState({
                        gameState: this.game.state
                    })
                },
                null,
                !this.game.canUndo()
            )
        )
        drawerItems.push(el(Divider, { key: "undoDivider" }))

        drawerItems.push(
            this.createDrawerButton("helpMenu", BookIcon, `Rule Help: ${this.game.modes[this.game.mode].name}`, () => {
                return this.setState({
                    helpOpen: true,
                    drawerOpen: false
                })
            })
        )
        drawerItems.push(el(Divider, { key: "helpDivider" }))

        drawerItems.push(
            this.createDrawerButton(
                "hardMenu",
                SickIcon,
                "Hard Mode",
                () => {
                    this.game.hard = !this.game.hard
                    this.game.save()
                    return this.setState({
                        hard: this.game.hard
                    })
                },
                this.game.hard
            )
        )
        drawerItems.push(
            this.createDrawerButton("playAgainMenu", ReplayIcon, `Play Again: ${this.game.modes[this.game.mode].name}`, () => {
                this.game.newGame()
                return this.setState({
                    drawerOpen: false,
                    gameState: this.game.state
                })
            })
        )
        drawerItems.push(el(Divider, { key: "playAgainDivider" }))

        for (var modeName in this.game.modes) {
            mode = this.game.modes[modeName]
            ;((drawerItems, modeName, mode) => {
                return drawerItems.push(
                    this.createDrawerButton(`newGame${modeName}`, GamesIcon, `New Game: ${mode.name}`, () => {
                        this.game.newGame(modeName)
                        return this.setState({
                            drawerOpen: false,
                            gameState: this.game.state
                        })
                    })
                )
            })(drawerItems, modeName, mode)
        }

        if (fullscreen.available()) {
            drawerItems.push(el(Divider, { key: "fullscreenDivider" }))
            drawerItems.push(
                this.createDrawerButton("fullscreen", FullscreenIcon, "Toggle Fullscreen", () => {
                    fullscreen.toggle()
                    return this.setState({
                        drawerOpen: false
                    })
                })
            )
        }

        const drawer = el(
            Drawer,
            {
                key: "drawer",
                anchor: "right",
                open: this.state.drawerOpen,
                onClose: () => {
                    return this.setState({
                        drawerOpen: false
                    })
                }
            },
            [
                el(
                    Box,
                    {
                        key: "drawerBox",
                        role: "presentation"
                    },
                    [
                        el(
                            List,
                            {
                                key: "drawerList"
                            },
                            drawerItems
                        )
                    ]
                )
            ]
        )

        const menuButton = el(
            IconButton,
            {
                key: "menuButton",
                size: "large",
                style: {
                    position: "fixed",
                    top: "10px",
                    right: "10px",
                    color: "#000"
                },
                onClick: () => {
                    return this.setState({
                        drawerOpen: true
                    })
                }
            },
            [el(MenuIcon, { key: "menuButtonIcon" })]
        )

        const winToastAction = el(
            React.Fragment,
            {
                key: "winToastFragment"
            },
            [
                el(
                    Button,
                    {
                        key: "winToastButton",
                        color: "primary",
                        size: "small",
                        onClick: () => {
                            this.game.newGame()
                            return this.setState({
                                drawerOpen: false,
                                winToastOpen: false,
                                gameState: this.game.state
                            })
                        }
                    },
                    ["Play Again?"]
                )
            ]
        )

        const winToast = el(Snackbar, {
            key: "winToast",
            open: this.state.winToastOpen,
            autoHideDuration: 10000,
            anchorOrigin: {
                vertical: "top",
                horizontal: "center"
            },
            message: "You Win!",
            action: winToastAction,
            onClose: () => {
                return this.setState({
                    winToastOpen: false
                })
            }
        })

        const loseToastAction = el(
            React.Fragment,
            {
                key: "loseToastFragment"
            },
            [
                el(
                    Button,
                    {
                        key: "loseToastButton",
                        color: "primary",
                        size: "small",
                        onClick: () => {
                            this.game.newGame()
                            return this.setState({
                                drawerOpen: false,
                                loseToastOpen: false,
                                gameState: this.game.state
                            })
                        }
                    },
                    ["Play Again?"]
                )
            ]
        )

        const loseToast = el(Snackbar, {
            key: "loseToast",
            open: this.state.loseToastOpen,
            autoHideDuration: 10000,
            anchorOrigin: {
                vertical: "top",
                horizontal: "center"
            },
            message: "You Lose.",
            action: loseToastAction,
            onClose: () => {
                return this.setState({
                    loseToastOpen: false
                })
            }
        })

        const helpDialogTextSplits = this.game.modes[this.game.mode].help.split(/\n\n/)
        const helpTypographies = []
        for (let textIndex = 0; textIndex < helpDialogTextSplits.length; textIndex++) {
            var matches
            var text = helpDialogTextSplits[textIndex]
            var variant = "body1"
            if ((matches = text.match(/^\| (.+)/))) {
                variant = "h6"
                text = matches[1]
            }
            helpTypographies.push(
                el(
                    Typography,
                    {
                        key: `helpTypo${textIndex}`,
                        gutterBottom: true,
                        variant
                    },
                    [text]
                )
            )
        }

        const helpDialog = el(
            Dialog,
            {
                key: "helpDialog",
                open: this.state.helpOpen,
                onClose: () => {
                    return this.setState({
                        helpOpen: false
                    })
                }
            },
            [
                el(
                    DialogTitle,
                    {
                        key: "helpDialogTitle"
                    },
                    [`Rule Help: ${this.game.modes[this.game.mode].name}`]
                ),
                el(
                    DialogContent,
                    {
                        key: "helpDialogContent",
                        dividers: true
                    },
                    helpTypographies
                ),
                el(
                    DialogActions,
                    {
                        key: "helpDialogActions"
                    },
                    [
                        el(
                            Button,
                            {
                                key: "helpDialogOK",
                                onClick: () => {
                                    return this.setState({
                                        helpOpen: false
                                    })
                                }
                            },
                            ["Got it!"]
                        )
                    ]
                )
            ]
        )

        const gameText = el(
            "div",
            {
                key: "bottomRightText",
                style: {
                    position: "fixed",
                    right: 10,
                    bottom: 10,
                    textAlign: "right",
                    fontFamily: "monospace",
                    fontSize: "1.2em",
                    color: "#fff",
                    textShadow: "2px 2px #000"
                }
            },
            [
                el(
                    "div",
                    {
                        key: "buildVersion",
                        style: {
                            color: "#6a6"
                        }
                    },
                    `${WEBPACK_BUILD_VERSION}`
                ),
                el(
                    "div",
                    { key: "gameAndDiff" },
                    `${this.game.modes[this.game.mode].name}${this.game.state.hard ? " (Hard)" : ""}`
                )
            ]
        )

        return el(
            "div",
            {
                key: "appcontainer"
            },
            [drawer, gameView, menuButton, winToast, loseToast, helpDialog, gameText]
        )
    }

    gameClick(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
        this.game.click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
        return this.setState({
            gameState: this.game.state,
            winToastOpen: this.game.won(),
            loseToastOpen: this.game.lost()
        })
    }

    sendAny() {
        const sent = this.game.sendAny()
        this.setState({
            gameState: this.game.state,
            winToastOpen: this.game.won(),
            loseToastOpen: this.game.lost()
        })
        return sent
    }

    phase() {
        this.game.phase()
        return this.setState({
            gameState: this.game.state,
            winToastOpen: this.game.won(),
            loseToastOpen: this.game.lost()
        })
    }

    addTweens(tweens) {
        console.log("addTweens: ", tweens)
        const id = this.nextTweenID
        this.nextTweenID += 1
        return (() => {
            const result = []
            for (var tween of Array.from(tweens)) {
                tween.id = id
                tween.done = false
                result.push(this.tweens.push(tween))
            }
            return result
        })()
    }
}

export default App
