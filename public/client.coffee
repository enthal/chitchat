model =
  roomsByName: {}

angular.module('chitchat', [])

.run( ($rootScope, $location, socketIo) ->
  socketIo()
  .on('connect',    -> $rootScope.isConnected = true)
  .on('disconnect', -> $rootScope.isConnected = false)
  .on('authenticatedAs', (me) ->
    $rootScope.me = me
    $rootScope.isAuthenticated = true
  )
  .on('messages', (roomsByName) ->
    console.log 'roomsByName', roomsByName
    model.roomsByName = roomsByName
  )
  .on('message', (message) ->
    room = model.roomsByName[message.room] ?= name: message.room
    messages = room.messages ?= []
    messages.push message
  )
)

.controller('ChitChat', ($scope, $log, socketIo) ->
  $scope.roomName = null

  $scope.getRoomNames = ->
    k for k of model.roomsByName

  $scope.getMessagesInSelectedRoom = ->
    model.roomsByName[$scope.roomName]?.messages

  $scope.makeNewRoom = ->
    name = $scope.newRoomNameText
    model.roomsByName[$scope.roomName = name] ?= name: name

  $scope.sendMessage = ->
    return unless $scope.messageText
    socketIo.emit 'message',
      room: $scope.roomName,
      body: $scope.messageText
      user:
        id:          $scope.$root.me.id
        displayName: $scope.$root.me.displayName
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
