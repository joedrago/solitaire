import webManifest from "./manifest.webmanifest"
import logoPNG from "./logo.png"

import React, { Component } from "react"
import ReactDOM from "react-dom/client"

import App from "./App"

window.onload = function () {
    const ua = navigator.userAgent
    console.log(`UA: ${ua}`)
    if (ua.indexOf("Chrome") === -1) {
        console.log("Safari'ifying body")
        const bodyElement = document.getElementsByTagName("body")[0]
        bodyElement.style.position = "fixed"
        bodyElement.style.left = 0
        bodyElement.style.top = 0
        bodyElement.style.right = 0
        bodyElement.style.bottom = 0
    }

    const app = new App()
    const root = ReactDOM.createRoot(document.getElementById("root"))
    root.render(React.createElement(App))
}
