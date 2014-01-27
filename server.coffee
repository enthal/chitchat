#!/usr/bin/env coffee

PORT = +process.env.PORT || 1337


model = do ->
  # redis schema:
  #   chitchat:rooms = (SADD) set of room names
  #   chitchat:room:<roomName> = (RPUSH) list of message body texts

  redis = require 'redis'
  onRedisMessage = null

  do ->
    clientSubcr = redis.createClient()
    clientSubcr.on 'message', (channel, message) ->
      console.log "message from redis subscription on channel [#{channel}] : #{message}"
      return unless channel is 'chitchat:messages'
      onRedisMessage JSON.parse message
    clientSubcr.subscribe 'chitchat:messages'

  client = redis.createClient()
  usersById = {}

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

  withUserForId: (userId, fn) ->
    console.log 'withUserForId', (x for x of usersById).length, usersById[userId]
    fn(null, usersById[userId] or false)

  withUserForIdUpdatingProfile: (userId, profile, fn) ->
    console.log 'withUserForIdUpdatingProfile', (x for x of usersById).length, usersById[userId]
    profile.id ?= userId
    fn(null, usersById[userId] ?= profile)



# express app http service
httpServer = do ->
  express = require 'express'

  app = express()
  httpServer = require('http').createServer app

  app.use express.logger()
  app.set 'views', __dirname + '/views'
  app.set 'view engine', 'jade'
  app.locals.pretty = true
  app.use express.static __dirname + '/public'
  app.use express.cookieParser()

  RedisStore = require('connect-redis')(express)
  app.use express.session store: new RedisStore, secret: 'who knows me?'

  passport = require 'passport'
  app.use passport.initialize()
  app.use passport.session()
  passport.serializeUser (user, done) -> done null, user.id
  passport.deserializeUser (id, done) -> model.withUserForId id, (e, user) -> done e, user

  app.get '/auth/google',        passport.authenticate 'google'
  app.get '/auth/google/return', passport.authenticate 'google',
    successRedirect: '/'
    failureRedirect: '/login'
  GoogleStrategy = require('passport-google').Strategy
  passport.use new GoogleStrategy
    returnURL: "http://127.0.0.1:#{PORT}/auth/google/return"    # TODO: what host?
    realm:     "http://127.0.0.1:#{PORT}/"                      # TODO: what host?
  , (identifier, profile, done) ->
    console.log 'GoogleStrategy', identifier, profile
    model.withUserForIdUpdatingProfile identifier, profile, (e, user) -> done e, user

  app.get '/', (req, res) -> res.render 'index'

  httpServer.listen PORT

  console.log "Server running at http://127.0.0.1:#{PORT}/"

  httpServer



# socket.io service
do ->
  io = require('socket.io').listen(httpServer).set('log level', 1)

  model.withRoomCount (n) -> console.log "starting with #{n} rooms"

  io.sockets.on 'connection', (socket) ->
    console.log 'connection!', socket.id

    model.withAllRoomsWithMessages (all) ->
      socket.emit 'messages', all

    socket.on 'message', (message) ->
      console.log message
      model.acceptMessage message
      # don't emit here; wait until message moves through redis pubsub channel

  model.onRedisMessage (message) ->
    io.sockets.emit 'message', message
