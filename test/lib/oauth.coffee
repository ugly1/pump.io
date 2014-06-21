# oauth.js
#
# Utilities for generating clients, request tokens, and access tokens
#
# Copyright 2012-2013 E14N https://e14n.com/
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
cp = require("child_process")
urlfmt = require("url").format
path = require("path")
Step = require("step")
_ = require("underscore")
http = require("http")
version = require("../../lib/version").version
OAuth = require("oauth-evanp").OAuth
Browser = require("zombie")
httputil = require("./http")
OAuthError = (obj) ->
  Error.captureStackTrace this, OAuthError
  @name = "OAuthError"
  _.extend this, obj
  return

OAuthError:: = new Error()
OAuthError::constructor = OAuthError
OAuthError::toString = ->
  "OAuthError (" + @statusCode + "):" + @data

getOAuth = (hostname, port, client_id, client_secret) ->
  proto = (if (port is 443) then "https" else "http")
  rtendpoint = urlfmt(
    protocol: proto
    host: (if (port is 80 or port is 443) then hostname else hostname + ":" + port)
    pathname: "/oauth/request_token"
  )
  atendpoint = urlfmt(
    protocol: proto
    host: (if (port is 80 or port is 443) then hostname else hostname + ":" + port)
    pathname: "/oauth/access_token"
  )
  oa = new OAuth(rtendpoint, atendpoint, client_id, client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
    "User-Agent": "pump.io/" + version
  )
  oa

requestToken = (cl, hostname, port, cb) ->
  oa = undefined
  proto = undefined
  rtendpoint = undefined
  atendpoint = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  oa = getOAuth(hostname, port, cl.client_id, cl.client_secret)
  oa.getOAuthRequestToken (err, token, secret) ->
    if err
      cb new OAuthError(err), null
    else
      cb null,
        token: token
        token_secret: secret

    return

  return

newClient = (hostname, port, path, cb) ->
  rel = "/api/client/register"
  full = undefined
  
  # newClient(hostname, port, cb)
  unless cb
    cb = path
    path = ""
  
  # newClient(cb)
  unless cb
    cb = hostname
    hostname = "localhost"
    port = 4815
  if path
    full = path + rel
  else
    full = rel
  httputil.post hostname, port, full,
    type: "client_associate"
  , (err, res, body) ->
    cl = undefined
    if err
      cb err, null
    else
      try
        cl = JSON.parse(body)
        cb null, cl
      catch err
        cb err, null
    return

  return

authorize = (cl, rt, user, hostname, port, cb) ->
  browser = new Browser()
  url = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  url = urlfmt(
    protocol: (if (port is 443) then "https" else "http")
    host: (if (port is 80 or port is 443) then hostname else hostname + ":" + port)
    pathname: "/oauth/authorize"
    query:
      oauth_token: rt.token
  )
  browser.on "error", (err) ->
    cb err, null
    return

  browser.visit(url).then ->
    browser.fill("#username", user.nickname).fill("#password", user.password).pressButton "#authenticate", ->
      
      # is there an authorize button?
      if browser.button("#authorize")
        
        # if so, press it
        browser.pressButton("#authorize", ->
          cb null, browser.text("#verifier")
          return
        ).fail (err) ->
          cb err, null
          return

      else
        cb null, browser.text("#verifier")
      return

    return

  return

redeemToken = (cl, rt, verifier, hostname, port, cb) ->
  proto = undefined
  oa = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    oa = getOAuth(hostname, port, cl.client_id, cl.client_secret)
    oa.getOAuthAccessToken rt.token, rt.token_secret, verifier, this
    return
  ), (err, token, secret, res) ->
    pair = undefined
    if err
      if err instanceof Error
        cb err, null
      else
        cb new Error(err.data), null
    else
      pair =
        token: token
        token_secret: secret

      cb null, pair
    return

  return

accessToken = (cl, user, hostname, port, cb) ->
  rt = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    requestToken cl, hostname, port, this
    return
  ), ((err, res) ->
    throw err  if err
    rt = res
    authorize cl, rt, user, hostname, port, this
    return
  ), ((err, verifier) ->
    throw err  if err
    redeemToken cl, rt, verifier, hostname, port, this
    return
  ), cb
  return

register = (cl, nickname, password, hostname, port, path, callback) ->
  proto = undefined
  full = undefined
  rel = "/api/users"
  
  # register(cl, nickname, hostname, port, callback)
  unless callback
    callback = path
    path = null
  
  # register(cl, nickname, callback)
  unless callback
    callback = hostname
    hostname = "localhost"
    port = 4815
  proto = (if (port is 443) then "https" else "http")
  if path
    full = path + rel
  else
    full = rel
  httputil.postJSON proto + "://" + hostname + ":" + port + full,
    consumer_key: cl.client_id
    consumer_secret: cl.client_secret
  ,
    nickname: nickname
    password: password
  , (err, body, res) ->
    callback err, body
    return

  return

registerEmail = (cl, nickname, password, email, hostname, port, callback) ->
  proto = undefined
  unless port
    callback = hostname
    hostname = "localhost"
    port = 4815
  proto = (if (port is 443) then "https" else "http")
  httputil.postJSON proto + "://" + hostname + ":" + port + "/api/users",
    consumer_key: cl.client_id
    consumer_secret: cl.client_secret
  ,
    nickname: nickname
    password: password
    email: email
  , (err, body, res) ->
    callback err, body
    return

  return

newCredentials = (nickname, password, hostname, port, cb) ->
  cl = undefined
  user = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    newClient hostname, port, this
    return
  ), ((err, res) ->
    throw err  if err
    cl = res
    newPair cl, nickname, password, hostname, port, this
    return
  ), (err, res) ->
    if err
      cb err, null
    else
      _.extend res,
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret

      cb err, res
    return

  return

newPair = (cl, nickname, password, hostname, port, cb) ->
  user = undefined
  regd = undefined
  unless port
    cb = hostname
    hostname = "localhost"
    port = 4815
  Step (->
    register cl, nickname, password, hostname, port, this
    return
  ), (err, res) ->
    pair = undefined
    if err
      cb err, null
    else
      user = res
      pair =
        token: user.token
        token_secret: user.secret
        user: user

      delete user.token

      delete user.secret

      cb null, pair
    return

  return


# Call as setupApp(port, hostname, callback)
# setupApp(hostname, callback)
# setupApp(callback)
setupApp = (port, hostname, callback) ->
  unless hostname
    callback = port
    hostname = "localhost"
    port = 4815
  unless callback
    callback = hostname
    hostname = "localhost"
  port = port or 4815
  hostname = hostname or "localhost"
  config =
    port: port
    hostname: hostname

  setupAppConfig config, callback
  return

setupAppConfig = (config, callback) ->
  prop = undefined
  args = []
  credwait = {}
  objwait = {}
  config.port = config.port or 4815
  config.hostname = config.hostname or "localhost"
  for prop of config
    args.push prop + "=" + JSON.stringify(config[prop])
  child = cp.fork(path.join(__dirname, "app.js"), args)
  dummy =
    close: ->
      child.kill()
      return

    killCred: (webfinger, callback) ->
      timeout = setTimeout(->
        callback new Error("Timed out waiting for cred to die.")
        return
      , 30000)
      credwait[webfinger] =
        callback: callback
        timeout: timeout

      child.send
        cmd: "killcred"
        webfinger: webfinger

      return

    changeObject: (obj, callback) ->
      timeout = setTimeout(->
        callback new Error("Timed out waiting for object change.")
        return
      , 30000)
      objwait[obj.id] =
        callback: callback
        timeout: timeout

      child.send
        cmd: "changeobject"
        object: obj

      return

  child.on "error", (err) ->
    callback err, null
    return

  child.on "message", (msg) ->
    switch msg.cmd
      when "listening"
        callback null, dummy
      when "error"
        callback msg.value, null
      when "credkilled"
        clearTimeout credwait[msg.webfinger].timeout
        if msg.error
          credwait[msg.webfinger].callback new Error(msg.error)
        else
          credwait[msg.webfinger].callback null
      when "objectchanged"
        clearTimeout objwait[msg.id].timeout
        if msg.error
          objwait[msg.id].callback new Error(msg.error)
        else
          objwait[msg.id].callback null

  return

exports.requestToken = requestToken
exports.newClient = newClient
exports.register = register
exports.registerEmail = registerEmail
exports.newCredentials = newCredentials
exports.newPair = newPair
exports.accessToken = accessToken
exports.authorize = authorize
exports.redeemToken = redeemToken
exports.setupApp = setupApp
exports.setupAppConfig = setupAppConfig
