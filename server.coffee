#!/usr/bin/env coffee

model = do ->
  # redis schema:
  #   chitchat:rooms = (SADD) set of room names
  #   chitchat:room:<roomName> = (RPUSH) list of message body texts

  redis = require("redis")
  client = redis.createClient()

  withRoomCount: (fn) ->
    client.scard 'chitchat:rooms', (e,x)->fn x

  withAllRoomsWithMessages: (fn) ->
    roomsByName = {}
    client.smembers 'chitchat:rooms', (e, roomNames) ->
      roomNames ?= []
      left = roomNames.length
      for roomName in roomNames
        do (roomName) ->
          client.lrange 'chitchat:room:'+roomName, 0, -1, (e, messages) ->
            roomsByName[roomName] = messages: ((body:m) for m in messages)
            fn roomsByName  unless --left

  acceptMessage: (message) ->
    client.sadd  'chitchat:rooms', message.room
    client.rpush 'chitchat:room:'+ message.room, message.body


# socket.io service
do ->
  io   = require('socket.io').listen(1338).set('log level', 1)

  model.withRoomCount (n) -> console.log "starting with #{n} rooms"

  io.sockets.on 'connection', (socket) ->
    console.log 'connection!', socket.id

    model.withAllRoomsWithMessages (all) ->
      socket.emit 'messages', all

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
