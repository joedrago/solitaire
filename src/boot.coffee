import webManifest from './manifest.webmanifest'
import logoPNG from './logo.png'

import React, { Component } from 'react'
import ReactDOM from 'react-dom/client'

import App from './App'

window.onload = ->
  app = new App
  root = ReactDOM.createRoot(document.getElementById('root'))
  root.render(React.createElement(App))
