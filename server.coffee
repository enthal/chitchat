#!/usr/bin/env coffee

CHATS_FILENAME = '/tmp/chats.json'

fs   = require 'fs'
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
      console.log req.method, status, path, contentType
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

