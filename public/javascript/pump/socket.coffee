# pump/socket.js
#
# Socket module for the pump.io client UI
#
# Copyright 2011-2012, E14N https://e14n.com/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
((_, $, Backbone, Pump) ->
  Pump.getStreams = ->
    streams = {}
    if Pump.body
      _.extend streams, Pump.body.content.getStreams()  if Pump.body.content
      _.extend streams, Pump.body.nav.getStreams()  if Pump.body.nav
    streams

  
  # Refreshes the current visible streams
  Pump.refreshStreams = ->
    streams = Pump.getStreams()
    _.each streams, (stream, name) ->
      stream.getPrev()
      return

    return

  Pump.updateStream = (url, activity) ->
    streams = Pump.getStreams()
    target = _.find(streams, (stream) ->
      stream.url() is url
    )
    act = undefined
    if target
      act = Pump.Activity.unique(activity)
      target.items.unshift act
    return

  
  # When we get a challenge from the socket server,
  # We prepare an OAuth request and send it
  Pump.riseToChallenge = (url, method) ->
    message =
      action: url
      method: method
      parameters: [[
        "oauth_version"
        "1.0"
      ]]

    Pump.ensureCred (err, cred) ->
      pair = undefined
      secrets = undefined
      if err
        Pump.error "Error getting OAuth credentials."
        return
      message.parameters.push [
        "oauth_consumer_key"
        cred.clientID
      ]
      secrets = consumerSecret: cred.clientSecret
      pair = Pump.getUserCred()
      if pair
        message.parameters.push [
          "oauth_token"
          pair.token
        ]
        secrets.tokenSecret = pair.secret
      OAuth.setTimestampAndNonce message
      OAuth.SignatureMethod.sign message, secrets
      Pump.socket.send JSON.stringify(
        cmd: "rise"
        message: message
      )
      return

    return

  
  # Our socket.io socket
  Pump.socket = null
  Pump.setupSocket = ->
    here = window.location
    sock = undefined
    if Pump.socket
      Pump.socket.close()
      Pump.socket = null
    sock = new SockJS(here.protocol + "//" + here.host + "/main/realtime/sockjs")
    sock.onopen = ->
      Pump.socket = sock
      Pump.followStreams()
      return

    sock.onmessage = (e) ->
      data = JSON.parse(e.data)
      switch data.cmd
        when "update"
          Pump.updateStream data.url, data.activity
        when "challenge"
          Pump.riseToChallenge data.url, data.method

    sock.onclose = ->
      
      # XXX: reconnect?
      Pump.socket = null
      return

    return

  Pump.followStreams = ->
    return  unless Pump.config.sockjs
    return  unless Pump.socket
    streams = Pump.getStreams()
    _.each streams, (stream, name) ->
      Pump.socket.send JSON.stringify(
        cmd: "follow"
        url: stream.url()
      )
      return

    return

  Pump.unfollowStreams = ->
    return  unless Pump.config.sockjs
    return  unless Pump.socket
    streams = Pump.getStreams()
    _.each streams, (stream, name) ->
      Pump.socket.send JSON.stringify(
        cmd: "unfollow"
        url: stream.url()
      )
      return

    return

  return
) window._, window.$, window.Backbone, window.Pump
