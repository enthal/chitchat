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


# http service
do ->
  http = require 'http'
  url  = require 'url'

  CONTENT_TYPES_BY_EXTENSION =
    txt:    'text/plain'
    html:   'text/html'
    coffee: 'text/coffeescript'

  http.createServer( (req, res) ->
    path = url.parse(req.url).pathname
    path += 'index.html'  if /\/$/.test path

    respond = (status, contentType, data) ->
      console.log status, req.method, path, contentType
      res.writeHead status, 'Content-Type': contentType
      res.end data

    fs.readFile "public/#{path}", (err, data) ->
      if err
        respond 404, 'text/plain', "404: #{path} ; Error #{err}"
      else
        contentType = CONTENT_TYPES_BY_EXTENSION[(path.match(/\.(\w+)$/) or ['txt'])[1]]
        respond 200, contentType, data

  ).listen 1337, '127.0.0.1'

  console.log 'Server running at http://127.0.0.1:1337/'
