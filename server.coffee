#!/usr/bin/env coffee

CHATS_FILENAME = '/tmp/chats.json'

fs   = require 'fs'
http = require 'http'
io   = require('socket.io').listen(1338).set('log level', 1)

messages = try
  JSON.parse fs.readFileSync CHATS_FILENAME
catch e
  []
console.log "starting with #{messages.length} messages"

io.sockets.on 'connection', (socket) ->
  console.log 'connection!', socket.id

  socket.emit 'messages', messages

  socket.on 'message', (message) ->
    console.log message
    messages.push message
    io.sockets.emit 'message', message
    fs.writeFile CHATS_FILENAME, JSON.stringify(messages, null, 2)


http.createServer( (req, res) ->

  res.writeHead 200, 'Content-Type': 'text/html'
  fs.readFile 'public/index.html', (err, data) ->
    throw err  if err
    res.end data

).listen 1337, '127.0.0.1'

console.log 'Server running at http://127.0.0.1:1337/'

