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
import TextField from "@mui/material/TextField"

import { QRCodeSVG } from "qrcode.react"

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
import RestartAltIcon from "@mui/icons-material/RestartAlt"
import DialpadIcon from "@mui/icons-material/Dialpad"
import SickIcon from "@mui/icons-material/Sick"
import UndoIcon from "@mui/icons-material/Undo"

import Snackbar from "@mui/material/Snackbar"

import SolitaireGame from "./SolitaireGame"
import SolitaireView from "./SolitaireView"
import * as render from "./render"
import fullscreen from "./fullscreen"
import { el } from "./reactutils"

class App extends Component {
    constructor(props) {
        super(props)

        this.game = new SolitaireGame()

        this.state = {
            width: window.innerWidth,
            height: window.innerHeight,
            gameState: this.game.state,
            drawerOpen: false,
            winToastOpen: false,
            loseToastOpen: false,
            helpOpen: false,
            seedDialogOpen: false,
            seedInputValue: "",
            hard: this.game.hard,
            useTouch: false // navigator.maxTouchPoints? and (navigator.maxTouchPoints > 0)
        }
    }

    componentDidMount() {
        window.addEventListener("resize", this.onResize.bind(this))
        window.addEventListener("orientationchange", this.onResize.bind(this))

        if (!this.state.useTouch) {
            let touchDetector = () => {
                console.log("Solitaire: touch detected! Switching to touch mode.")
                window.removeEventListener("touchstart", touchDetector, false)
                this.setState({
                    useTouch: true
                })
            }
            window.addEventListener("touchstart", touchDetector)
            return
        }
    }

    onResize() {
        this.setState({
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
        if (switchValue) {
            buttonPieces.push(
                el(Switch, {
                    key: `${keyBase}Switch`,
                    color: "secondary",
                    edge: "end",
                    checked: switchValue
                    // onChange={handleToggle('wifi')}
                    // checked={checked.indexOf('wifi') != -1}
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
                    this.setState({
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
                this.setState({
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
                    this.setState({
                        hard: this.game.hard
                    })
                },
                this.game.hard
            )
        )
        drawerItems.push(
            this.createDrawerButton("playAgainMenu", ReplayIcon, `Play Again: ${this.game.modes[this.game.mode].name}`, () => {
                this.game.newGame()
                this.setState({
                    drawerOpen: false,
                    gameState: this.game.state
                })
            })
        )
        drawerItems.push(
            this.createDrawerButton("startOverMenu", RestartAltIcon, "Start Over (same deal)", () => {
                this.game.newGame(null, this.game.seed)
                this.setState({
                    drawerOpen: false,
                    gameState: this.game.state
                })
            })
        )
        drawerItems.push(
            this.createDrawerButton("chooseGameMenu", DialpadIcon, "Choose Game (by seed)…", () => {
                this.setState({
                    drawerOpen: false,
                    seedDialogOpen: true,
                    seedInputValue: String(this.game.seed != null ? this.game.seed : "")
                })
            })
        )
        drawerItems.push(el(Divider, { key: "playAgainDivider" }))

        for (let modeName in this.game.modes) {
            mode = this.game.modes[modeName]
            ;((drawerItems, modeName, mode) => {
                drawerItems.push(
                    this.createDrawerButton(`newGame${modeName}`, GamesIcon, `New Game: ${mode.name}`, () => {
                        this.game.newGame(modeName)
                        this.setState({
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
                    this.setState({
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
                    this.setState({
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
                    this.setState({
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
                            this.setState({
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
                this.setState({
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
                            this.setState({
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
                this.setState({
                    loseToastOpen: false
                })
            }
        })

        const helpDialogTextSplits = this.game.modes[this.game.mode].help.split(/\n\n/)
        const helpTypographies = []
        for (let textIndex = 0; textIndex < helpDialogTextSplits.length; ++textIndex) {
            let matches
            let text = helpDialogTextSplits[textIndex]
            let variant = "body1"
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
                    this.setState({
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
                                    this.setState({
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

        const commitSeed = () => {
            const parsed = parseInt(this.state.seedInputValue, 10)
            if (!isNaN(parsed)) {
                this.game.newGame(null, parsed)
                this.setState({
                    seedDialogOpen: false,
                    gameState: this.game.state
                })
            }
        }
        const seedDialog = el(
            Dialog,
            {
                key: "seedDialog",
                open: this.state.seedDialogOpen,
                onClose: () => {
                    this.setState({ seedDialogOpen: false })
                }
            },
            [
                el(DialogTitle, { key: "seedDialogTitle" }, ["Choose Game"]),
                el(
                    DialogContent,
                    { key: "seedDialogContent" },
                    [
                        el(
                            DialogContentText,
                            { key: "seedDialogText" },
                            ["Enter a seed to deal that exact game. Share a seed (or scan its QR) to play the same deal as a friend."]
                        ),
                        el(TextField, {
                            key: "seedDialogField",
                            autoFocus: true,
                            margin: "dense",
                            label: "Seed",
                            type: "number",
                            fullWidth: true,
                            variant: "standard",
                            value: this.state.seedInputValue,
                            onChange: (e) => {
                                this.setState({ seedInputValue: e.target.value })
                            },
                            onKeyDown: (e) => {
                                if (e.key === "Enter") {
                                    commitSeed()
                                }
                            }
                        })
                    ]
                ),
                el(
                    DialogActions,
                    { key: "seedDialogActions" },
                    [
                        el(Button, { key: "seedDialogCancel", onClick: () => this.setState({ seedDialogOpen: false }) }, ["Cancel"]),
                        el(Button, { key: "seedDialogPlay", onClick: commitSeed }, ["Play"])
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
                ),
                this.game.seed != null &&
                    el("div", { key: "seedLine", style: { fontSize: "0.8em", opacity: 0.85 } }, `Seed ${this.game.seed}`),
                this.game.seed != null &&
                    el(
                        "div",
                        { key: "seedQR", style: { marginTop: 4, display: "inline-block", background: "#fff", padding: 3, borderRadius: 2 } },
                        [
                            el(QRCodeSVG, {
                                key: "seedQRCode",
                                value: String(this.game.seed),
                                size: 56,
                                level: "M"
                            })
                        ]
                    )
            ]
        )

        return el(
            "div",
            {
                key: "appcontainer"
            },
            [drawer, gameView, menuButton, winToast, loseToast, helpDialog, seedDialog, gameText]
        )
    }

    gameClick(type, outerIndex, innerIndex, isRightClick, isMouseUp) {
        this.game.click(type, outerIndex, innerIndex, isRightClick, isMouseUp)
        this.setState({
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
}

export default App
