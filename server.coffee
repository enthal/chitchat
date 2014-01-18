#!/usr/bin/env coffee

PORT = +process.env.PORT || 1337


model = do ->
  # redis schema:
  #   chitchat:rooms = (SADD) set of room names
  #   chitchat:room:<roomName> = (RPUSH) list of message body texts

  redis = require("redis")
  onRedisMessage = null

  do ->
    clientPubSub = redis.createClient()
    clientPubSub.on 'message', (channel, message) ->
      console.log "message from redis subscription on channel [#{channel}] : #{message}"
      return unless channel is 'chitchat:messages'
      onRedisMessage JSON.parse message
    clientPubSub.subscribe 'chitchat:messages'

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
    client.publish 'chitchat:messages', JSON.stringify message

  onRedisMessage: (fn) ->
    onRedisMessage = fn



# socket.io service
do ->
  io   = require('socket.io').listen(PORT+1).set('log level', 1)

  model.withRoomCount (n) -> console.log "starting with #{n} rooms"

  io.sockets.on 'connection', (socket) ->
    console.log 'connection!', socket.id

    model.withAllRoomsWithMessages (all) ->
      socket.emit 'messages', all

    socket.on 'message', (message) ->
      console.log message
      model.acceptMessage message
      # don't emit here; wait untl message moves through redis pubsub channel

  model.onRedisMessage (message) ->
    io.sockets.emit 'message', message



# express app http service
do ->
  express = require 'express'

  app = express()
  app.use express.logger()
  app.use express.static(__dirname + "/public")
  app.listen PORT

  console.log "Server running at http://127.0.0.1:#{PORT}/"
