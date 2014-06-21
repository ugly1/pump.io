# OAuthDataProvider for activity spam server
#
# Copyright 2011-2013 E14N https://e14n.com/
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
require "set-immediate"
NoSuchThingError = require("databank").NoSuchThingError
_ = require("underscore")
url = require("url")
Step = require("step")
User = require("./model/user").User
RequestToken = require("./model/requesttoken").RequestToken
AccessToken = require("./model/accesstoken").AccessToken
Nonce = require("./model/nonce").Nonce
Client = require("./model/client").Client
TIMELIMIT = 300 # +/- 5 min seems pretty generous
REQUESTTOKENTIMEOUT = 600 # 10 min, also pretty generous
Provider = (logParent, rawClients) ->
  prov = this
  log = (if (logParent) then logParent.child(component: "oauth-provider") else null)
  clients = _.map(rawClients, (client) ->
    cl = _.clone(client)
    _.extend cl,
      consumer_key: client.client_id
      secret: client.client_secret
      asActivityObject: (callback) ->
        cl = this
        ActivityObject = require("./model/activityobject").ActivityObject
        uuidv5 = require("./uuidv5")
        props = {}
        props._consumer_key = cl.consumer_key
        props.displayName = cl.title  if cl.title
        props.content = cl.description  if cl.description
        props.objectType = ActivityObject.APPLICATION
        props.id = "urn:uuid:" + uuidv5(client.client_id)
        ActivityObject.ensureObject props, callback
        return

    cl
  )
  prov.getClient = (client_id, callback) ->
    client = undefined
    
    # Is it in our configured array?
    if clients
      client = _.find(clients, (cl) ->
        cl.client_id is client_id
      )
      if client
        setImmediate ->
          callback null, client
          return

        return
    
    # Is it in our database?
    Client.get client_id, callback
    return

  prov.previousRequestToken = (token, callback) ->
    log.debug "getting previous request token for " + token  if log
    AccessToken.search
      request_token: token
    , (err, ats) ->
      if err
        callback err, null
      else if ats.length > 0
        callback new Error("Token has been used"), null
      else
        callback null, token
      return

    return

  prov.tokenByConsumer = (consumerKey, callback) ->
    log.debug "getting token for consumer key " + consumerKey  if log
    prov.getClient consumerKey, (err, client) ->
      if err
        callback err, null
      else
        RequestToken.search
          consumer_key: client.consumer_key
        , (err, rts) ->
          if rts.length > 0
            callback null, rts[0]
          else
            callback new Error("No RequestToken for that consumer_key"), null
          return

      return

    return

  prov.tokenByTokenAndConsumer = (token, consumerKey, callback) ->
    log.debug "getting token for consumer key " + consumerKey + " and token " + token  if log
    RequestToken.get token, (err, rt) ->
      if err
        callback err, null
      else if rt.consumer_key isnt consumerKey
        callback new Error("Consumer key mismatch"), null
      else
        callback null, rt
      return

    return

  prov.applicationByConsumerKey = (consumerKey, callback) ->
    log.debug "getting application for consumer key " + consumerKey  if log
    prov.getClient consumerKey, callback
    return

  prov.fetchAuthorizationInformation = (username, token, callback) ->
    log.debug "getting auth information for user " + username + " with token " + token  if log
    RequestToken.get token, (err, rt) ->
      if err
        callback err, null, null
      else if not _(rt).has("username") or rt.username isnt username
        callback new Error("Request token not associated with username '" + username + "'"), null, null
      else
        prov.getClient rt.consumer_key, (err, client) ->
          if err
            callback err, null, null
          else
            client.title = "(Unknown)"  unless _(client).has("title")
            client.description = "(Unknown)"  unless _(client).has("description")
            callback null, client, rt
          return

      return

    return

  prov.validToken = (accessToken, callback) ->
    log.debug "checking for valid token " + accessToken  if log
    AccessToken.get accessToken, callback
    return

  prov.tokenByTokenAndVerifier = (token, verifier, callback) ->
    log.debug "checking for valid request token " + token + " with verifier " + verifier  if log
    RequestToken.get token, (err, rt) ->
      if err
        callback err, null
      else if rt.verifier isnt verifier
        callback new Error("Wrong verifier"), null
      else
        callback null, rt
      return

    return

  prov.validateNotReplayClient = (consumerKey, accessToken, timestamp, nonce, callback) ->
    now = Math.floor(Date.now() / 1000)
    ts = undefined
    log.debug "checking for replay with consumer key " + consumerKey + ", token = " + accessToken  if log
    try
      ts = parseInt(timestamp, 10)
    catch err
      callback err, null
      return
    if Math.abs(ts - now) > TIMELIMIT
      callback null, false
      return
    Step (->
      prov.getClient consumerKey, this
      return
    ), ((err, client) ->
      throw err  if err
      unless accessToken
        this null, null
      else
        AccessToken.get accessToken, this
      return
    ), ((err, at) ->
      throw err  if err
      throw new Error("consumerKey and accessToken don't match")  if at and at.consumer_key isnt consumerKey
      Nonce.seenBefore consumerKey, accessToken, nonce, timestamp, this
      return
    ), (err, seen) ->
      if err
        callback err, null
      else
        callback null, not seen
      return

    return

  prov.userIdByToken = (token, callback) ->
    user = undefined
    client = undefined
    at = undefined
    log.debug "checking for user with token = " + token  if log
    Step (->
      AccessToken.get token, this
      return
    ), ((err, res) ->
      throw err  if err
      at = res
      prov.getClient at.consumer_key, this
      return
    ), ((err, res) ->
      throw err  if err
      client = res
      User.get at.username, this
      return
    ), (err, res) ->
      if err
        callback err, null
      else
        user = res
        callback null,
          id: at.username
          user: user
          client: client

      return

    return

  prov.authenticateUser = (username, password, oauthToken, callback) ->
    log.debug "authenticating user with username " + username + " and token " + oauthToken  if log
    User.checkCredentials username, password, (err, user) ->
      if err
        callback err, null
        return
      unless user
        callback new Error("Bad credentials"), null
        return
      RequestToken.get oauthToken, (err, rt) ->
        if err
          callback err, null
          return
        if rt.username and rt.username isnt username
          callback new Error("Token already associated with a different user"), null
          return
        rt.authenticated = true
        rt.save (err, rt) ->
          if err
            callback err, null
          else
            callback null, rt
          return

        return

      return

    return

  prov.associateTokenToUser = (username, token, callback) ->
    log.debug "associating username " + username + " with token " + token  if log
    RequestToken.get token, (err, rt) ->
      if err
        callback err, null
        return
      if rt.username and rt.username isnt username
        callback new Error("Token already associated"), null
        return
      rt.update
        username: username
      , (err, rt) ->
        if err
          callback err, null
        else
          callback null, rt
        return

      return

    return

  prov.generateRequestToken = (oauthConsumerKey, oauthCallback, callback) ->
    log.debug "getting a request token for " + oauthConsumerKey  if log
    if oauthCallback isnt "oob"
      parts = url.parse(oauthCallback)
      if not parts.host or not parts.protocol or (parts.protocol isnt "http:" and parts.protocol isnt "https:")
        callback new Error("Invalid callback URL"), null
        return
    prov.getClient oauthConsumerKey, (err, client) ->
      if err
        callback err, null
        return
      props =
        consumer_key: oauthConsumerKey
        callback: oauthCallback

      RequestToken.create props, callback
      return

    return

  prov.generateAccessToken = (oauthToken, callback) ->
    rt = undefined
    at = undefined
    log.debug "getting an access token for " + oauthToken  if log
    Step (->
      RequestToken.get oauthToken, this
      return
    ), ((err, results) ->
      throw err  if err
      rt = results
      throw new Error("Request token not associated")  unless rt.username
      
      # XXX: search AccessToken instead...?
      throw new Error("Request token already used")  if rt.access_token
      AccessToken.search
        consumer_key: rt.consumer_key
        username: rt.username
      , this
      return
    ), ((err, ats) ->
      props = undefined
      throw err  if err
      if not ats or ats.length is 0
        log.debug "creating a new access token for " + oauthToken  if log
        props =
          consumer_key: rt.consumer_key
          request_token: rt.token
          username: rt.username

        AccessToken.create props, this
      else
        log.debug "reusing access token " + ats[0].access_token + " for " + oauthToken  if log
        
        # XXX: keep an array of related request tokens, not just one
        ats[0].update
          request_token: rt.token
        , this
      return
    ), ((err, results) ->
      throw err  if err
      at = results
      
      # XXX: delete...?
      log.debug "saving access token for " + oauthToken  if log
      rt.update
        access_token: at.access_token
      , this
      return
    ), (err, rt) ->
      if err
        callback err, null
      else
        callback null, at
      return

    return

  prov.cleanRequestTokens = (consumerKey, callback) ->
    log.debug "cleaning up request tokens for " + consumerKey  if log
    Step (->
      prov.getClient consumerKey, this
      return
    ), ((err, client) ->
      throw err  if err
      RequestToken.search
        consumer_key: consumerKey
      , this
      return
    ), ((err, rts) ->
      id = undefined
      now = Date.now()
      touched = undefined
      group = @group()
      throw err  if err
      for id of rts
        touched = Date.parse(rts[id].updated)
        # ms -> sec
        rts[id].del group()  if now - touched > (REQUESTTOKENTIMEOUT * 1000)
      return
    ), (err) ->
      callback err, null
      return

    return

  prov.newTokenPair = (client, user, callback) ->
    rt = undefined
    at = undefined
    Step (->
      prov.generateRequestToken client.consumer_key, "oob", this
      return
    ), ((err, results) ->
      throw err  if err
      rt = results
      rt.update
        username: user.nickname
      , this
      return
    ), ((err, rt) ->
      props = undefined
      throw err  if err
      props =
        consumer_key: rt.consumer_key
        request_token: rt.token
        username: rt.username

      AccessToken.create props, this
      return
    ), ((err, results) ->
      throw err  if err
      at = results
      rt.update
        access_token: at.access_token
      , this
      return
    ), (err) ->
      if err
        callback err, null
      else
        callback null, at
      return

    return

  return

exports.Provider = Provider
