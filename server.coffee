#!/usr/bin/env coffee

model = do ->
  CHATS_FILENAME = '/tmp/room-chats.json'
  fs   = require 'fs'

  roomsByName = try
    JSON.parse fs.readFileSync CHATS_FILENAME
  catch e
    {}

  getRoomCount: -> (1 for _ of roomsByName).length
  getAllRoomsWithMessages: -> roomsByName
  acceptMessage: (message) ->
    room = roomsByName[message.room] ?= name: message.room
    messages = room.messages ?= []
    messages.push message
    fs.writeFile CHATS_FILENAME, JSON.stringify(roomsByName, null, 2)


# socket.io service
do ->
  io   = require('socket.io').listen(1338).set('log level', 1)

  console.log "starting with #{model.getRoomCount()} rooms"

  io.sockets.on 'connection', (socket) ->
    console.log 'connection!', socket.id

    socket.emit 'messages', model.getAllRoomsWithMessages()

    socket.on 'message', (message) ->
      console.log message
      model.acceptMessage message
      io.sockets.emit 'message', message


# express app http service
do ->
  express = require 'express'

  app = express()
  app.use express.logger()
  app.use express.static(__dirname + "/public")
  app.listen 1337

  console.log 'Server running at http://127.0.0.1:1337/'
