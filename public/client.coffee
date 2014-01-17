messages = []

angular.module('chitchat', [])

.run( ($rootScope, socketIo) ->
  socketIo(':1338')
  .on('connect',    -> $rootScope.isConnected = true)
  .on('disconnect', -> $rootScope.isConnected = false)
  .on('messages', (new_messages) ->
    messages.length = 0
    messages.push m  for m in new_messages
  )
  .on('message', (message) ->
    messages.push message
  )
)

.controller('ChitChat', ($scope, $log, socketIo) ->
  $scope.messages = messages
  $scope.sendMessage = ->
    return unless $scope.messageText
    socketIo.emit 'message', body:$scope.messageText
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
