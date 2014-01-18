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
  )
  .on('message', (message) ->
    room = model.roomsByName[message.room] ?= name: message.room
    messages = room.messages ?= []
    messages.push message
  )
)

.controller('ChitChat', ($scope, $log, socketIo) ->
  $scope.roomName = 'home'  # TODO

  $scope.getRoomNames = ->
    k for k of model.roomsByName
  $scope.getMessagesInSelectedRoom = ->
    model.roomsByName[$scope.roomName].messages

  $scope.sendMessage = ->
    return unless $scope.messageText
    socketIo.emit 'message',
      room: $scope.roomName,
      body: $scope.messageText
    $scope.messageText = ''
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
