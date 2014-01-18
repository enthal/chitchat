#!/usr/bin/env coffee

CHATS_FILENAME = '/tmp/room-chats.json'

fs   = require 'fs'


# socket.io service
do ->
  io   = require('socket.io').listen(1338).set('log level', 1)

  roomsByName = try
    JSON.parse fs.readFileSync CHATS_FILENAME
  catch e
    {}
  console.log "starting with #{(1 for _ of roomsByName).length} rooms"

  io.sockets.on 'connection', (socket) ->
    console.log 'connection!', socket.id

    socket.emit 'messages', roomsByName

    socket.on 'message', (message) ->
      console.log message

      room = roomsByName[message.room] ?= name: message.room
      messages = room.messages ?= []
      messages.push message

      io.sockets.emit 'message', message
      fs.writeFile CHATS_FILENAME, JSON.stringify(roomsByName, null, 2)


# express app http service
do ->
  express = require 'express'

  app = express()
  app.use express.logger()
  app.use express.static(__dirname + "/public")
  app.listen 1337

  console.log 'Server running at http://127.0.0.1:1337/'
