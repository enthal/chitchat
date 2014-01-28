#!/usr/bin/env coffee

HOST =  process.env.HOST || process.env.HOSTNAME || '127.0.0.1'
PORT = +process.env.PORT || 1337
BASE_URL = "http://#{HOST}:#{PORT}"

model = do ->
  # redis schema:
  #   chitchat:rooms = (SADD) set of room names
  #   chitchat:room:messages:<roomName> = (RPUSH) list of messages

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

  withRoomCount: (fn) ->
    client.scard 'chitchat:rooms', (e,x)->fn x

  withAllRoomsWithMessages: (fn) ->
    roomsByName = {}
    client.smembers 'chitchat:rooms', (e, roomNames) ->
      roomNames ?= []
      left = roomNames.length
      for roomName in roomNames
        do (roomName) ->
          client.lrange 'chitchat:room:messages:'+roomName, 0, -1, (e, messageJsons) ->
            roomsByName[roomName] = messages: (JSON.parse m for m in messageJsons)
            fn roomsByName  unless --left

  acceptMessage: (message) ->
    messageJson = JSON.stringify message
    client.sadd    'chitchat:rooms',         message.room
    client.rpush   'chitchat:room:messages:'+message.room, messageJson
    client.publish 'chitchat:messages',                    messageJson

  onRedisMessage: (fn) ->
    onRedisMessage = fn

  withUserForId: (userId, fn) ->
    client.hget 'chitchat:users', userId, (e, userJson) ->
      return fn(e) if e
      console.log 'withUserForId', userJson
      fn e, (if userJson then JSON.parse userJson else false)

  withUserForIdUpdatingProfile: (userId, profile, fn) ->
    client.hget 'chitchat:users', userId, (e, userJson) ->
      return fn(e) if e
      console.log 'withUserForIdUpdatingProfile', userJson
      if userJson
        fn e, JSON.parse userJson
      else
        profile.id ?= userId
        client.hset 'chitchat:users', userId, JSON.stringify(profile), (e) ->
          fn e, profile



# express app http service
[express, httpServer, sessionConfig] = do ->
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
  sessionConfig =
    store: new RedisStore
    key: 'express.sid'
    secret: 'who knows me?'    # Not very secret in a public github repo!
  app.use express.session sessionConfig

  passport = require 'passport'
  app.use passport.initialize()
  app.use passport.session()
  passport.serializeUser (user, done) -> done null, user.id
  passport.deserializeUser (id, done) -> model.withUserForId id, (e, user) -> done e, user

  app.get '/auth/logout', (req, res) ->
    req.logout()
    res.redirect '/'
  app.get '/auth/google',        passport.authenticate 'google'
  app.get '/auth/google/return', passport.authenticate 'google',
    successRedirect: '/'
    failureRedirect: '/'
  GoogleStrategy = require('passport-google').Strategy
  passport.use new GoogleStrategy
    returnURL: "#{BASE_URL}/auth/google/return"    # TODO: what host?
    realm:     "#{BASE_URL}/"                      # TODO: what host?
  , (identifier, profile, done) ->
    console.log 'GoogleStrategy', identifier, profile
    model.withUserForIdUpdatingProfile identifier, profile, (e, user) -> done e, user

  app.get '/', (req, res) -> res.render 'index'

  httpServer.listen PORT

  console.log "Server running at #{BASE_URL}/"

  [express, httpServer, sessionConfig]



# socket.io service
do ->
  io = require('socket.io').listen(httpServer).set('log level', 1)

  sessionConfig.cookieParser = express.cookieParser
  sessionConfig.success = (data, accept) ->
    console.log 'successful connection to socket.io on behalf of:', data.user?.displayName#, data
    accept null, true
  sessionConfig.fail = (data, message, error, accept) ->
    console.log (if error then 'ERROR' else 'failed'), 'connection to socket.io:', message
    accept null, false

  io.set 'authorization', require('passport.socketio').authorize sessionConfig

  io.sockets.on 'connection', (socket) ->
    user = socket.handshake?.user
    console.log 'connection!', socket.id, user
    unless user?.logged_in
      console.log 'bail out of connection: user not logged_in!'
      return

    socket.emit 'authenticatedAs', user

    model.withAllRoomsWithMessages (all) ->
      socket.emit 'messages', all

    socket.on 'message', (message) ->
      console.log message
      model.acceptMessage message
      # don't emit here; wait until message moves through redis pubsub channel

  model.onRedisMessage (message) ->
    io.sockets.emit 'message', message



model.withRoomCount (n) -> console.log "starting with #{n} rooms"
