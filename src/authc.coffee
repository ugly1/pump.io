# authc.js
#
# Authentication middleware
#
# Copyright 2011-2013, E14N https://e14n.com/
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
databank = require("databank")
Step = require("step")
_ = require("underscore")
bcrypt = require("bcrypt")
fs = require("fs")
path = require("path")
os = require("os")
randomString = require("./randomstring").randomString
Activity = require("./model/activity").Activity
ActivityObject = require("./model/activityobject").ActivityObject
User = require("./model/user").User
Client = require("./model/client").Client
HTTPError = require("./httperror").HTTPError
URLMaker = require("./urlmaker").URLMaker
NoSuchThingError = databank.NoSuchThingError

# Remove all properties of an object and its properties if the key starts with _
sanitizedJSON = (obj) ->
  clean = {}
  _.each obj, (value, key) ->
    unless _.has(obj, key)
      return
    else if key[0] is "_"
      return
    else if _.isObject(value) # includes arrays!
      clean[key] = sanitizedJSON(value)
    else clean[key] = value  unless _.isFunction(value)
    return

  clean

maybeAuth = (req, res, next) ->
  unless hasOAuth(req)
    
    # No client, no user
    next()
  else
    clientAuth req, res, next
  return

hasOAuth = (req) ->
  req and _.has(req, "headers") and _.has(req.headers, "authorization") and req.headers.authorization.match(/^OAuth/)

userOrClientAuth = (req, res, next) ->
  if hasToken(req)
    userAuth req, res, next
  else
    clientAuth req, res, next
  return

wrapRequest = (req, path) ->
  areq = _.clone(req)
  path = "/" + path  unless path[0] is "/"
  areq.originalUrl = path + req.originalUrl
  areq


# Accept either 2-legged or 3-legged OAuth
clientAuth = (req, res, next) ->
  log = req.log
  areq = undefined
  req.client = null
  res.local "client", null # init to null
  log.debug "Checking for 2-legged OAuth credentials"
  
  # If we're coming in the front door, and we have a path, provide it
  if req.header("Host").toLowerCase() is URLMaker.makeHost() and URLMaker.path
    areq = wrapRequest(req, URLMaker.path)
  else
    areq = req
  areq.authenticate ["client"], (error, authenticated) ->
    deetz = undefined
    if error
      log.error error
      next error
      return
    unless authenticated
      log.debug "Not authenticated"
      return
    log.debug "Authentication succeeded"
    deetz = areq.getAuthDetails()
    log.debug deetz
    if not deetz or not deetz.user or not deetz.user.id
      log.debug "Incorrect auth details."
      return
    Step (->
      req.app.provider.getClient deetz.user.id, this
      return
    ), ((err, client) ->
      throw err  if err
      req.client = client
      res.local "client", sanitizedJSON(req.client)
      if client.webfinger or client.host
        client.asActivityObject this
      else
        this null, null
      return
    ), (err, principal) ->
      if err
        log.error err
        next err
      else
        req.principal = principal
        res.local "principal", sanitizedJSON(principal)
        next()
      return

    return

  return

hasToken = (req) ->
  req and (_(req.headers).has("authorization") and req.headers.authorization.match(/oauth_token/)) or (req.query and req.query.oauth_token) or (req.body and req.headers["content-type"] is "application/x-www-form-urlencoded" and req.body.oauth_token)


# Accept only 3-legged OAuth
# XXX: It would be nice to merge these two functions
userAuth = (req, res, next) ->
  log = req.log
  areq = undefined
  req.principal = null
  res.local "principal", null # init to null
  req.principalUser = null
  res.local "principalUser", null # init to null
  req.client = null
  res.local "client", null # init to null
  log.debug "Checking for 3-legged OAuth credentials"
  
  # If we're coming in the front door, and we have a path, provide it
  if req.header("Host").toLowerCase() is URLMaker.makeHost() and URLMaker.path
    areq = wrapRequest(req, URLMaker.path)
  else
    areq = req
  areq.authenticate ["user"], (error, authenticated) ->
    deetz = undefined
    if error
      log.error error
      next error
      return
    unless authenticated
      log.debug "Authentication failed"
      return
    log.debug "Authentication succeeded"
    deetz = areq.getAuthDetails()
    log.debug deetz, "Authentication details"
    if not deetz or not deetz.user or not deetz.user.user or not deetz.user.client
      log.debug "Incorrect auth details."
      next new Error("Incorrect auth details")
      return
    
    # If email confirmation is required and not yet done, give an error.
    if req.app.config.requireEmail and not deetz.user.user.email
      next new HTTPError("Can't use the API until you confirm your email address.", 403)
      return
    req.principalUser = deetz.user.user
    res.local "principalUser", sanitizedJSON(req.principalUser)
    req.principal = req.principalUser.profile
    res.local "principal", sanitizedJSON(req.principal)
    req.client = deetz.user.client
    res.local "client", sanitizedJSON(req.client)
    log.debug
      principalUser: req.principalUser.nickname
      principal: req.principal
      client: req.client.title
    , "User authorization complete."
    next()
    return

  return


# Accept only 2-legged OAuth with
remoteUserAuth = (req, res, next) ->
  clientAuth req, res, (err) ->
    if err
      next err
    else unless req.principal
      next new HTTPError("Authentication required", 401)
    else
      next()
    return

  return

setPrincipal = (session, obj, callback) ->
  unless _.isObject(obj)
    callback new Error("Can't set principal to non-object")
    return
  session.principal =
    id: obj.id
    objectType: obj.objectType

  callback null
  return

getPrincipal = (session, callback) ->
  if not session or not _.has(session, "principal")
    callback null, null
    return
  ref = session.principal
  Step (->
    ActivityObject.getObject ref.objectType, ref.id, this
    return
  ), callback
  return

clearPrincipal = (session, callback) ->
  if not session or not _.has(session, "principal")
    callback null
    return
  delete session.principal

  callback null
  return

principal = (req, res, next) ->
  req.log.debug
    msg: "Checking for principal"
    session: req.session

  Step (->
    getPrincipal req.session, this
    return
  ), ((err, principal) ->
    throw err  if err
    if principal
      req.log.debug
        msg: "Setting session principal"
        principal: principal

      req.principal = principal
      res.local "principal", sanitizedJSON(req.principal)
      User.fromPerson principal.id, this
    else
      req.principal = null
      req.principalUser = null
      next()
    return
  ), (err, user) ->
    if err
      next err
    else
      
      # XXX: null on miss
      if user
        req.log.debug
          msg: "Setting session principal user"
          user: user

        req.principalUser = user
        
        # Make the profile a "live" object
        req.principalUser.profile = req.principal
        res.local "principalUser", sanitizedJSON(req.principalUser)
      next()
    return

  return

principalUserOnly = (req, res, next) ->
  if not _.has(req, "principalUser") or not req.principalUser
    next new HTTPError("Not logged in.", 401)
  else
    next()
  return

remoteWriteOAuth = remoteUserAuth
noneWriteOAuth = clientAuth
userWriteOAuth = userAuth
userReadAuth = (req, res, next) ->
  if hasOAuth(req)
    userAuth req, res, next
  else if req.session
    principal req, res, (err) ->
      if err
        next err
      else
        principalUserOnly req, res, next
      return

  else
    next new HTTPError("Not logged in.", 401)
  return

anyReadAuth = (req, res, next) ->
  if hasOAuth(req)
    userOrClientAuth req, res, next
  else if req.session
    principal req, res, (err) ->
      if err
        next err
      else unless req.principal
        next new HTTPError("Not logged in.", 401)
      else
        next()
      return

  else
    next new HTTPError("Not logged in.", 401)
  return

someReadAuth = (req, res, next) ->
  if hasOAuth(req)
    userAuth req, res, next
  else if req.session
    principal req, res, (err) ->
      if err
        next err
      else unless req.principal
        next new HTTPError("Not logged in.", 401)
      else
        next()
      return

  else
    next new HTTPError("Not logged in.", 401)
  return

exports.principal = principal
exports.setPrincipal = setPrincipal
exports.getPrincipal = getPrincipal
exports.clearPrincipal = clearPrincipal
exports.principalUserOnly = principalUserOnly
exports.userAuth = userAuth
exports.clientAuth = clientAuth
exports.userOrClientAuth = userOrClientAuth
exports.remoteUserAuth = remoteUserAuth
exports.maybeAuth = maybeAuth
exports.hasOAuth = hasOAuth
exports.remoteWriteOAuth = remoteWriteOAuth
exports.noneWriteOAuth = noneWriteOAuth
exports.userWriteOAuth = userWriteOAuth
exports.userReadAuth = userReadAuth
exports.anyReadAuth = anyReadAuth
exports.someReadAuth = someReadAuth
