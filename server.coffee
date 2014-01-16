#!/usr/bin/env coffee

fs   = require 'fs'
http = require 'http'
io   = require('socket.io').listen(1338)

io.sockets.on 'connection', (socket) ->

  socket.emit 'news', hello: 'world'

  socket.on 'my other event', (data) -> console.log data


http.createServer( (req, res) ->

  res.writeHead 200, 'Content-Type': 'text/html'
  fs.readFile 'public/index.html', (err, data) ->
    throw err  if err
    res.end data

).listen 1337, '127.0.0.1'

console.log 'Server running at http://127.0.0.1:1337/'

