socket = io.connect ':1338'
messages = []

angular.module('chitchat', [])

.run( ($rootScope) ->
  socket
  .on('connect',    -> $rootScope.$apply -> $rootScope.isConnected = true)
  .on('disconnect', -> $rootScope.$apply -> $rootScope.isConnected = false)
  .on('messages', (new_messages) ->
    $rootScope.$apply ->
      messages.length = 0
      messages.push m  for m in new_messages
  )
  .on('message', (message) ->
    $rootScope.$apply ->
      messages.push message
  )
)
.controller('ChitChat', ($scope, $log) ->
  $scope.messages = messages
  $scope.sendMessage = ->
    return unless $scope.messageText
    socket.emit 'message', body:$scope.messageText
    $scope.messageText = ''
)
