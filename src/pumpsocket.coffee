# pumpsocket.js
#
# Our own socket.io application interface
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
sockjs = require("sockjs")
cluster = require("cluster")
uuid = require("node-uuid")
Step = require("step")
_ = require("underscore")
oauth = require("oauth-evanp")
randomString = require("./randomstring").randomString
URLMaker = require("./urlmaker").URLMaker
finishers = require("./finishers")
Activity = require("./model/activity").Activity
addFollowed = finishers.addFollowed
addLiked = finishers.addLiked
addLikers = finishers.addLikers
addShared = finishers.addShared
firstFewReplies = finishers.firstFewReplies
firstFewShares = finishers.firstFewShares
connect = (app, log) ->
  slog = log.child(component: "sockjs")
  options =
    sockjs_url: "/javascript/sockjs.min.js"
    prefix: "/main/realtime/sockjs"
    log: (severity, message) ->
      if _.isFunction(slog[severity])
        slog[severity] message
      else
        slog.info message
      return

  server = undefined
  id2url = {}
  url2id = {}
  id2conn = {}
  follow = (url, id) ->
    unless _.has(url2id, url)
      cluster.worker.send
        cmd: "follow"
        url: url

      url2id[url] = [id]
    url2id[url].push id  unless _.contains(url2id[url], id)
    id2url[id].push url  unless _.contains(id2url[id], url)
    return

  unfollow = (url, id) ->
    if _.has(url2id, url) and _.contains(url2id[url], id)
      url2id[url].splice url2id[url].indexOf(id), 1
      if url2id[url].length is 0
        cluster.worker.send
          cmd: "unfollow"
          url: url

        delete url2id[url]
    id2url[id].splice id2url[id].indexOf(url), 1  if _.contains(id2url[id], url)
    return

  challenge = (conn) ->
    Step (->
      randomString 8, this
      return
    ), (err, str) ->
      url = undefined
      if err
        
        # <sad trombone>
        conn.log.error
          err: err
        , "Error creating random string"
        conn.close()
      else
        url = URLMaker.makeURL("/main/realtime/sockjs/" + str + "/challenge")
        conn.challengeURL = url
        conn.write JSON.stringify(
          cmd: "challenge"
          url: url
          method: "GET"
        )
      return

    return

  rise = (conn, message) ->
    client = undefined
    params = _.object(message.parameters)
    conn.log.debug
      riseMessage: message
    , "Client rose to challenge"
    unless message.action is conn.challengeURL
      conn.log.error
        challenge: conn.challengeURL
        response: message.action
      , "Bad challenge URL"
      conn.close()
      return
    
    # Wipe the URL so we don't recheck
    conn.challengeURL = null
    if _.has(params, "oauth_token")
      validateUser message, (err, user, client) ->
        if err
          conn.log.error
            err: err
          , "Failed user authentication"
          conn.close()
        else
          conn.log.info
            user: user
            client: client
          , "User authentication succeeded."
          conn.user = user
          conn.client = client
          conn.write JSON.stringify(
            cmd: "authenticated"
            user: user.nickname
          )
        return

    else
      validateClient message, (err, client) ->
        if err
          conn.log.error
            err: err
          , "Failed client authentication"
          conn.close()
        else
          conn.log.info
            client: client
          , "Client authentication succeeded."
          delete conn.user  if _.has(conn, "user")
          conn.client = client
          conn.write JSON.stringify(cmd: "authenticated")
        return

    return

  checkSignature = (message, client, token, cb) ->
    params = _.object(message.parameters)
    oa = new oauth.OAuth(null, null, params.oauth_consumer_key, client.secret, null, null, params.oauth_signature_method)
    sent = params.oauth_signature
    signature = undefined
    copy = _.clone(params)
    normalized = undefined
    
    # Remove the signature
    delete copy.oauth_signature

    
    # Normalize into a string
    normalized = oa._normaliseRequestParams(copy)
    signature = oa._getSignature(message.method, message.action, normalized, (if token then token.token_secret else null))
    if signature is sent
      cb null
    else
      cb new Error("Bad OAuth signature")
    return

  validateClient = (message, cb) ->
    params = _.object(message.parameters)
    client = undefined
    Step (->
      server.provider.validateNotReplayClient params.oauth_consumer_key, null, params.oauth_timestamp, params.oauth_nonce, this
      return
    ), ((err, result) ->
      throw err  if err
      throw new Error("Seen this nonce before!")  unless result
      server.provider.applicationByConsumerKey params.oauth_consumer_key, this
      return
    ), ((err, application) ->
      throw err  if err
      client = application
      checkSignature message, application, null, this
      return
    ), (err) ->
      if err
        cb err, null
      else
        cb null, client
      return

    return

  validateUser = (message, cb) ->
    params = _.object(message.parameters)
    client = undefined
    token = undefined
    user = undefined
    Step (->
      server.provider.validToken params.oauth_token, this
      return
    ), ((err, result) ->
      throw err  if err
      token = result
      server.provider.validateNotReplayClient params.oauth_consumer_key, params.oauth_token, params.oauth_timestamp, params.oauth_nonce, this
      return
    ), ((err, result) ->
      throw err  if err
      throw new Error("Seen this nonce before!")  unless result
      server.provider.applicationByConsumerKey params.oauth_consumer_key, this
      return
    ), ((err, application) ->
      throw err  if err
      client = application
      checkSignature message, client, token, this
      return
    ), ((err) ->
      throw err  if err
      server.provider.userIdByToken params.oauth_token, this
      return
    ), (err, doc) ->
      if err
        cb err, null, null
      else
        cb null, doc.user, doc.client
      return

    return

  cluster.worker.on "message", (msg) ->
    ids = undefined
    if msg.cmd is "update"
      ids = url2id[msg.url]
      slog.info
        activity: msg.activity.id
        connections: (if (ids) then ids.length else 0)
      , "Delivering activity to connections"
      if ids and ids.length
        _.each ids, (id) ->
          act = undefined
          profile = undefined
          conn = id2conn[id]
          return  unless conn
          act = new Activity(msg.activity)
          Step (->
            profile = (if (conn.user) then conn.user.profile else null)
            act.checkRecipient profile, this
            return
          ), ((err, ok) ->
            throw err  if err
            unless ok
              conn.log.info
                activity: msg.activity.id
              , "No access; not delivering activity"
              return
            addLiked profile, [act.object], @parallel()
            addLikers profile, [act.object], @parallel()
            addShared profile, [act.object], @parallel()
            firstFewReplies profile, [act.object], @parallel()
            firstFewShares profile, [act.object], @parallel()
            addFollowed profile, [act.object], @parallel()  if act.object.isFollowable()
            return
          ), (err) ->
            tosend = undefined
            if err
              conn.log.error
                err: err
              , "Error finishing object"
            else
              tosend = _.pick(msg, "cmd", "url")
              tosend.activity = act
              conn.log.info
                activity: msg.activity.id
              , "Delivering activity"
              conn.write JSON.stringify(tosend)
            return

          return

    return

  server = sockjs.createServer(options)
  
  # Note this is a utility for us; SockJS uses the log() function
  # we pass in through options
  server.log = slog
  server.log.debug "Setting up sockjs server."
  
  # snatch the provider
  server.provider = app.provider
  server.on "connection", (conn) ->
    if conn is null
      server.log.info "Connection event without a connection."
      return
    id = conn.id
    conn.log = server.log.child(
      connection_id: id
      component: "sockjs"
    )
    conn.log.info "Connected"
    id2conn[id] = conn
    id2url[id] = []
    conn.on "close", ->
      _.each id2url[id], (url) ->
        unfollow url, id
        return

      delete id2url[id]

      delete id2conn[id]

      id = null
      conn.log.info "Disconnected"
      return

    conn.on "data", (message) ->
      data = JSON.parse(message)
      switch data.cmd
        when "follow"
          conn.log.info
            url: data.url
          , "Follow"
          follow data.url, id
        when "unfollow"
          conn.log.info
            url: data.url
          , "Unfollow"
          unfollow data.url, id
        when "rise"
          conn.log.info
            url: data.message.action
          , "Rise"
          rise conn, data.message
        when "request"
          conn.log.info "Request"
          challenge conn
        else
          conn.log.warn
            cmd: data.cmd
          , "Unrecognized command; ignoring."
      return

    
    # Send a challenge on connection
    challenge conn
    return

  server.installHandlers app, options
  return

exports.connect = connect
