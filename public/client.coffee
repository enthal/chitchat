model =
  roomsByName: {}

angular.module('chitchat', [])

.run( ($rootScope, socketIo) ->
  socketIo(':1338')
  .on('connect',    -> $rootScope.isConnected = true)
  .on('disconnect', -> $rootScope.isConnected = false)
  .on('messages', (roomsByName) ->
    console.log('roomsByName', roomsByName)
    model.roomsByName = roomsByName
    $rootScope.messages = model.roomsByName.home?.messages  # TODO
  )
  .on('message', (message) ->
    room = model.roomsByName[message.room] ?= name: message.room
    $rootScope.messages = room.messages ?= []
    $rootScope.messages.push message
  )
)

.controller('ChitChat', ($scope, $log, socketIo) ->
  $scope.roomNames = k for k of model.roomsByName
  $scope.roomName = 'home'  # TODO

  $scope.sendMessage = ->
    return unless $scope.messageText
    socketIo.emit 'message',
      room: $scope.roomName,
      body: $scope.messageText
    $scope.messageText = ''

  $scope.getARoom = (roomName) ->
    $scope.messages = model.roomsByName[roomName]
)

# socket.io wrapper: evaluate on() callback in $rootScope.$apply
.factory('socketIo', ($rootScope) ->
  socket = null

  r = (connectArgs...) ->
    socket = io.connect connectArgs...
    on: (event, fn) ->
      socket.on event, (args...) ->
        $rootScope.$apply ->
          fn args...
      this

  r.emit = (args...) -> socket.emit args...

  r
)
