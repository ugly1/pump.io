# routes/web.js
#
# Spurtin' out pumpy goodness all over your browser window
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
databank = require("databank")
Step = require("step")
_ = require("underscore")
validator = require("validator")
check = validator.check
Mailer = require("../lib/mailer")
URLMaker = require("../lib/urlmaker").URLMaker
filters = require("../lib/filters")
Activity = require("../lib/model/activity").Activity
ActivityObject = require("../lib/model/activityobject").ActivityObject
User = require("../lib/model/user").User
Recovery = require("../lib/model/recovery").Recovery
Collection = require("../lib/model/collection").Collection
RemoteRequestToken = require("../lib/model/remoterequesttoken").RemoteRequestToken
RemoteAccessToken = require("../lib/model/remoteaccesstoken").RemoteAccessToken
Host = require("../lib/model/host").Host
mw = require("../lib/middleware")
omw = require("../lib/objectmiddleware")
authc = require("../lib/authc")
he = require("../lib/httperror")
Scrubber = require("../lib/scrubber")
finishers = require("../lib/finishers")
su = require("../lib/saveupload")
saveUpload = su.saveUpload
saveAvatar = su.saveAvatar
streams = require("../lib/streams")
api = require("./api")
HTTPError = he.HTTPError
reqUser = mw.reqUser
reqGenerator = mw.reqGenerator
principal = authc.principal
setPrincipal = authc.setPrincipal
clearPrincipal = authc.clearPrincipal
principalUserOnly = authc.principalUserOnly
clientAuth = authc.clientAuth
userAuth = authc.userAuth
someReadAuth = authc.someReadAuth
NoSuchThingError = databank.NoSuchThingError
createUser = api.createUser
addLiked = finishers.addLiked
addShared = finishers.addShared
addLikers = finishers.addLikers
firstFewReplies = finishers.firstFewReplies
firstFewShares = finishers.firstFewShares
addFollowed = finishers.addFollowed
requestObject = omw.requestObject
principalActorOrRecipient = omw.principalActorOrRecipient
principalAuthorOrRecipient = omw.principalAuthorOrRecipient
addRoutes = (app) ->
  app.get "/", app.session, principal, addMessages, showMain
  app.post "/main/javascript-disabled", app.session, principal, showJavascriptDisabled
  app.get "/main/register", app.session, principal, showRegister
  app.post "/main/register", app.session, principal, clientAuth, reqGenerator, createUser
  app.get "/main/login", app.session, principal, addMessages, showLogin
  app.post "/main/login", app.session, clientAuth, handleLogin
  app.post "/main/logout", app.session, someReadAuth, handleLogout
  app.post "/main/renew", app.session, userAuth, renewSession
  app.get "/main/remote", app.session, principal, showRemote
  app.post "/main/remote", app.session, handleRemote
  if app.config.haveEmail
    app.get "/main/recover", app.session, showRecover
    app.get "/main/recover-sent", app.session, showRecoverSent
    app.post "/main/recover", app.session, handleRecover
    app.get "/main/recover/:code", app.session, recoverCode
    app.post "/main/redeem-code", app.session, clientAuth, redeemCode
  app.get "/main/authorized/:hostname", app.session, reqHost, reqToken, authorized
  if app.config.uploaddir
    app.post "/main/upload", app.session, principal, principalUserOnly, uploadFile
    app.post "/main/upload-avatar", app.session, principal, principalUserOnly, uploadAvatar
  app.get "/:nickname", app.session, principal, addMessages, reqUser, showStream
  app.get "/:nickname/favorites", app.session, principal, addMessages, reqUser, showFavorites
  app.get "/:nickname/followers", app.session, principal, addMessages, reqUser, showFollowers
  app.get "/:nickname/following", app.session, principal, addMessages, reqUser, showFollowing
  app.get "/:nickname/lists", app.session, principal, addMessages, reqUser, showLists
  app.get "/:nickname/list/:uuid", app.session, principal, addMessages, reqUser, showList
  
  # For things that you can only see if you're logged in,
  # we redirect to the login page, then let you go there
  app.get "/main/settings", loginRedirect("/main/settings")
  app.get "/main/account", loginRedirect("/main/account")
  app.get "/main/messages", loginRedirect("/main/messages")
  app.post "/main/proxy", app.session, principal, principalNotUser, proxyActivity
  
  # These are catchalls and should go at the end to prevent conflicts
  app.get "/:nickname/activity/:uuid", app.session, principal, addMessages, requestActivity, reqUser, userIsActor, principalActorOrRecipient, showActivity
  app.get "/:nickname/:type/:uuid", app.session, principal, addMessages, requestObject, reqUser, userIsAuthor, principalAuthorOrRecipient, showObject
  return

loginRedirect = (rel) ->
  (req, res, next) ->
    res.redirect "/main/login?continue=" + rel
    return

showMain = (req, res, next) ->
  if req.principalUser
    req.log.debug
      msg: "Showing inbox for logged-in user"
      user: req.principalUser

    showInbox req, res, next
  else
    req.log.debug msg: "Showing welcome page"
    res.render "main",
      page:
        title: "Welcome"
        url: req.originalUrl

  return

showInbox = (req, res, next) ->
  user = req.principalUser
  Step (->
    streams.userMajorInbox
      user: user
    , req.principal, @parallel()
    streams.userMinorInbox
      user: user
    , req.principal, @parallel()
    return
  ), (err, major, minor) ->
    if err
      next err
    else
      res.render "inbox",
        page:
          title: "Home"
          url: req.originalUrl

        major: major
        minor: minor
        user: user
        data:
          major: major
          minor: minor

    return

  return

showRegister = (req, res, next) ->
  if req.principal
    res.redirect "/"
  else if req.app.config.disableRegistration
    next new HTTPError("No registration allowed.", 403)
  else
    res.render "register",
      page:
        title: "Register"
        url: req.originalUrl

  return

showLogin = (req, res, next) ->
  res.render "login",
    page:
      title: "Login"
      url: req.originalUrl

  return

handleLogout = (req, res, next) ->
  Step (->
    clearPrincipal req.session, this
    return
  ), (err) ->
    if err
      next err
    else
      req.principalUser = null
      req.principal = null
      res.json "OK"
    return

  return

showJavascriptDisabled = (req, res, next) ->
  res.render "javascript-disabled",
    page:
      title: "Javascript disabled"

  return

showRemote = (req, res, next) ->
  res.render "remote",
    page:
      title: "Remote login"
      url: req.originalUrl

  return

handleRemote = (req, res, next) ->
  webfinger = req.body.webfinger
  continueTo = req.body.continueTo
  hostname = undefined
  parts = undefined
  host = undefined
  try
    check(webfinger).isEmail()
  catch e
    next new HTTPError(e.message, 400)
    return
  
  # Save relative URL to return to
  req.session.continueTo = continueTo  if continueTo and continueTo.length > 0
  parts = webfinger.split("@", 2)
  if parts.length < 2
    next new HTTPError("Bad format for webfinger", 400)
    return
  hostname = parts[1]
  Step (->
    Host.ensureHost hostname, this
    return
  ), ((err, result) ->
    throw err  if err
    host = result
    host.getRequestToken this
    return
  ), (err, rt) ->
    if err
      next err
    else
      res.redirect host.authorizeURL(rt)
    return

  return

requestActivity = (req, res, next) ->
  uuid = req.params.uuid
  activity = undefined
  Step (->
    Activity.search
      _uuid: uuid
    , this
    return
  ), ((err, activities) ->
    throw err  if err
    throw new NoSuchThingError("activity", uuid)  if activities.length is 0
    throw new Error("Too many activities with ID = " + uuid)  if activities.length > 1
    activity = activities[0]
    activity.expand this
    return
  ), (err) ->
    if err
      next err
    else
      req.activity = activity
      next()
    return

  return

userIsActor = (req, res, next) ->
  user = req.user
  person = req.person
  activity = req.activity
  actor = undefined
  if not activity or not activity.actor
    next new HTTPError("No such activity", 404)
    return
  actor = activity.actor
  if person and actor and person.id is actor.id
    next()
  else
    next new HTTPError("person " + person.id + " is not the actor of " + activity.id, 404)
    return
  return

showActivity = (req, res, next) ->
  activity = req.activity
  if activity.isMajor()
    res.render "major-activity-page",
      page:
        title: activity.content
        url: req.originalUrl

      principal: principal
      activity: activity

  else
    res.render "minor-activity-page",
      page:
        title: activity.content
        url: req.originalUrl

      principal: principal
      activity: activity

  return

showStream = (req, res, next) ->
  Step (->
    streams.userMajorStream
      user: req.user
    , req.principal, @parallel()
    streams.userMinorStream
      user: req.user
    , req.principal, @parallel()
    addFollowed req.principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
    return
  ), (err, major, minor) ->
    if err
      next err
    else
      res.render "user",
        page:
          title: req.user.profile.displayName
          url: req.originalUrl

        major: major
        minor: minor
        profile: req.user.profile
        data:
          major: major
          minor: minor
          profile: req.user.profile
          headless: true

    return

  return

showFavorites = (req, res, next) ->
  Step (->
    streams.userFavorites
      user: req.user
    , req.principal, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
    return
  ), (err, objects) ->
    if err
      next err
    else
      res.render "favorites",
        page:
          title: req.user.nickname + " favorites"
          url: req.originalUrl

        favorites: objects
        profile: req.user.profile
        data:
          favorites: objects
          profile: req.user.profile

    return

  return

showFollowers = (req, res, next) ->
  Step (->
    streams.userFollowers
      user: req.user
      author: req.user.profile
    , req.principal, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
    return
  ), (err, followers) ->
    if err
      next err
    else
      res.render "followers",
        page:
          title: req.user.nickname + " followers"
          url: req.originalUrl

        followers: followers
        profile: req.user.profile
        data:
          profile: req.user.profile
          followers: followers

    return

  return

showFollowing = (req, res, next) ->
  Step (->
    streams.userFollowing
      user: req.user
      author: req.user.profile
    , req.principal, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
    return
  ), (err, following) ->
    if err
      next err
    else
      res.render "following",
        page:
          title: req.user.nickname + " following"
          url: req.originalUrl

        following: following
        profile: req.user.profile
        data:
          profile: req.user.profile
          following: following

    return

  return

handleLogin = (req, res, next) ->
  user = null
  Step (->
    User.checkCredentials req.body.nickname, req.body.password, this
    return
  ), ((err, result) ->
    throw err  if err
    throw new HTTPError("Incorrect username or password", 401)  unless result
    user = result
    setPrincipal req.session, user.profile, this
    return
  ), ((err) ->
    throw err  if err
    user.expand this
    return
  ), ((err) ->
    throw err  if err
    user.profile.expandFeeds this
    return
  ), ((err) ->
    throw err  if err
    req.app.provider.newTokenPair req.client, user, this
    return
  ), (err, pair) ->
    if err
      next err
    else
      user.sanitize()
      user.token = pair.access_token
      user.secret = pair.token_secret
      res.json user
    return

  return

showLists = (req, res, next) ->
  user = req.user
  principal = req.principal
  Step (->
    streams.userLists
      user: user
      type: "person"
    , principal, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
    return
  ), (err, lists) ->
    if err
      next err
    else
      res.render "lists",
        page:
          title: req.user.profile.displayName + " - Lists"
          url: req.originalUrl

        profile: req.user.profile
        list: null
        lists: lists
        data:
          profile: req.user.profile
          list: null
          lists: lists

    return

  return

showList = (req, res, next) ->
  user = req.user
  principal = req.principal
  getList = (uuid, callback) ->
    list = undefined
    Step (->
      Collection.search
        _uuid: req.params.uuid
      , this
      return
    ), ((err, results) ->
      throw err  if err
      throw new HTTPError("Not found", 404)  if results.length is 0
      throw new HTTPError("Too many lists", 500)  if results.length > 1
      list = results[0]
      throw new HTTPError("User " + user.nickname + " is not author of " + list.id, 400)  unless list.author.id is user.profile.id
      
      # Make it a real object
      list.author = user.profile
      streams.collectionMembers
        collection: list
      , principal, this
      return
    ), (err, collection) ->
      if err
        callback err, null
      else
        list.members = collection
        callback null, list
      return

    return

  Step (->
    streams.userLists
      user: user
      type: "person"
    , principal, @parallel()
    getList req.param.uuid, @parallel()
    addFollowed principal, [req.user.profile], @parallel()
    req.user.profile.expandFeeds @parallel()
    return
  ), (err, lists, list) ->
    if err
      next err
    else
      res.render "list",
        page:
          title: req.user.profile.displayName + " - Lists"
          url: req.originalUrl

        profile: req.user.profile
        lists: lists
        list: list
        members: list.members
        data:
          profile: req.user.profile
          lists: lists
          members: list.members
          list: list

    return

  return


# uploadFile and uploadAvatar are almost identical except for the function
# they use to save the file. So, this generator makes the two functions

# XXX: if they diverge any more, make them separate functions
uploader = (saver) ->
  (req, res, next) ->
    user = req.principalUser
    uploadDir = req.app.config.uploaddir
    mimeType = undefined
    fileName = undefined
    params = {}
    if req.xhr
      if _.has(req.headers, "x-mime-type")
        mimeType = req.headers["x-mime-type"]
      else
        mimeType = req.uploadMimeType
      fileName = req.uploadFile
      params.title = req.query.title  if _.has(req.query, "title")
      params.description = Scrubber.scrub(req.query.description)  if _.has(req.query, "description")
    else
      mimeType = req.files.qqfile.type
      fileName = req.files.qqfile.path
    req.log.debug "Uploading " + fileName + " of type " + mimeType
    Step (->
      saver user, mimeType, fileName, uploadDir, params, this
      return
    ), (err, obj) ->
      data = undefined
      if err
        req.log.error err
        data =
          success: false
          error: err.message

        res.send JSON.stringify(data),
          "Content-Type": "text/plain"
        , 500
      else
        req.log.debug "Upload successful"
        obj.sanitize()
        req.log.debug obj
        data =
          success: true
          obj: obj

        res.send JSON.stringify(data),
          "Content-Type": "text/plain"
        , 200
      return

    return

uploadFile = uploader(saveUpload)
uploadAvatar = uploader(saveAvatar)
userIsAuthor = (req, res, next) ->
  user = req.user
  person = req.person
  type = req.type
  obj = req[type]
  author = obj.author
  if person and author and person.id is author.id
    next()
  else
    next new HTTPError("No " + type + " by " + user.nickname + " with uuid " + obj._uuid, 404)
    return
  return

showObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  person = req.person
  profile = req.principal
  Step (->
    obj.expandFeeds this
    return
  ), ((err) ->
    throw err  if err
    addLiked profile, [obj], @parallel()
    addShared profile, [obj], @parallel()
    addLikers profile, [obj], @parallel()
    firstFewReplies profile, [obj], @parallel()
    firstFewShares profile, [obj], @parallel()
    addFollowed profile, [obj], @parallel()  if obj.isFollowable()
    return
  ), (err) ->
    title = undefined
    if err
      next err
    else
      if obj.displayName
        title = obj.displayName
      else
        title = type + " by " + person.displayName
      res.render "object",
        page:
          title: title
          url: req.originalUrl

        object: obj
        data:
          object: obj

    return

  return

renewSession = (req, res, next) ->
  principal = req.principal
  user = req.principalUser
  Step (->
    
    # We only need to set this if it's not already set
    setPrincipal req.session, principal, this
    return
  ), (err) ->
    if err
      next err
    else
      
      # principalUser is sanitized by userAuth()
      res.json user
    return

  return

reqHost = (req, res, next) ->
  hostname = req.params.hostname
  Step (->
    Host.get hostname, this
    return
  ), (err, host) ->
    if err
      next err
    else
      req.host = host
      next()
    return

  return

reqToken = (req, res, next) ->
  token = req.query.oauth_token
  host = req.host
  Step (->
    RemoteRequestToken.get RemoteRequestToken.key(host.hostname, token), this
    return
  ), (err, rt) ->
    if err
      next err
    else
      req.rt = rt
      next()
    return

  return

authorized = (req, res, next) ->
  rt = req.rt
  host = req.host
  verifier = req.query.oauth_verifier
  principal = undefined
  pair = undefined
  Step (->
    host.getAccessToken rt, verifier, this
    return
  ), ((err, results) ->
    throw err  if err
    pair = results
    host.whoami pair.token, pair.secret, this
    return
  ), ((err, obj) ->
    throw err  if err
    
    # XXX: test id and url for hostname
    ActivityObject.ensureObject obj, this
    return
  ), ((err, results) ->
    at = undefined
    throw err  if err
    principal = results
    at = new RemoteAccessToken(
      id: principal.id
      type: principal.objectType
      token: pair.token
      secret: pair.secret
      hostname: host.hostname
    )
    at.save this
    return
  ), ((err, at) ->
    throw err  if err
    setPrincipal req.session, principal, this
    return
  ), (err) ->
    continueTo = undefined
    if err
      next err
    else if req.session.continueTo
      continueTo = req.session.continueTo
      delete req.session.continueTo

      res.redirect continueTo
    else
      res.redirect "/"
    return

  return

principalNotUser = (req, res, next) ->
  unless req.principal
    next new HTTPError("No principal", 401)
  else if req.principalUser
    next new HTTPError("Only for remote users", 401)
  else
    next()
  return

proxyActivity = (req, res, next) ->
  principal = req.principal
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  at = undefined
  host = undefined
  oa = undefined
  
  # XXX: we overwrite anything here
  activity.generator = req.generator
  if not _.has(principal, "links") or not _.has(principal.links, "activity-outbox") or not _.has(principal.links["activity-outbox"], "href")
    next new Error("No activity outbox endpoint for " + principal.id, 400)
    return
  Step (->
    RemoteAccessToken.get principal.id, this
    return
  ), ((err, results) ->
    throw err  if err
    at = results
    Host.ensureHost at.hostname, this
    return
  ), ((err, results) ->
    throw err  if err
    host = results
    host.getOAuth this
    return
  ), ((err, results) ->
    throw err  if err
    oa = results
    oa.post principal.links["activity-outbox"].href, at.token, at.secret, JSON.stringify(activity), "application/json", this
    return
  ), (err, doc, response) ->
    act = undefined
    if err
      if err.statusCode
        next new Error("Remote OAuth error code " + err.statusCode + ": " + err.data)
      else
        next err
    else
      act = new Activity(JSON.parse(doc))
      act.sanitize principal
      res.json act
    return

  return


# Middleware to add messages to the interface
addMessages = (req, res, next) ->
  user = req.principalUser
  
  # We only do this for registered users
  unless user
    next null
    return
  Step (->
    streams.userMajorDirectInbox
      user: user
    , req.principal, @parallel()
    streams.userMinorDirectInbox
      user: user
    , req.principal, @parallel()
    return
  ), (err, messages, notifications) ->
    if err
      next err
    else
      res.local "messages", messages
      res.local "notifications", notifications
      next()
    return

  return

showRecover = (req, res, next) ->
  res.render "recover",
    page:
      title: "Recover your password"

  return

showRecoverSent = (req, res, next) ->
  res.render "recover-sent",
    page:
      title: "Recovery email sent"

  return

handleRecover = (req, res, next) ->
  user = null
  recovery = undefined
  nickname = req.body.nickname
  force = req.body.force
  Step (->
    req.log.debug
      nickname: nickname
    , "checking for user to recover"
    User.get nickname, this
    return
  ), ((err, result) ->
    if err
      if err.name is "NoSuchThingError"
        req.log.debug
          nickname: nickname
        , "No such user, can't recover"
        res.status 400
        res.json
          sent: false
          noSuchUser: true
          error: "There is no user with that nickname."

        return
      else
        throw err
    user = result
    unless user.email
      req.log.debug
        nickname: nickname
      , "User has no email address; can't recover."
      
      # Done
      res.status 400
      res.json
        sent: false
        noEmail: true
        error: "This user account has no email address."

      return
    if force
      req.log.debug
        nickname: nickname
      , "Forcing recovery regardless of existing recovery records."
      this null, []
    else
      req.log.debug
        nickname: nickname
      , "Checking for existing recovery records."
      
      # Do they have any outstanding recovery requests?
      Recovery.search
        nickname: nickname
        recovered: false
      , this
    return
  ), ((err, recoveries) ->
    stillValid = undefined
    throw err  if err
    if not recoveries or recoveries.length is 0
      req.log.debug
        nickname: nickname
      , "No existing recovery records; continuing."
      this null
      return
    stillValid = _.filter(recoveries, (reco) ->
      Date.now() - Date.parse(reco.timestamp) < Recovery.TIMEOUT
    )
    if stillValid.length > 0
      req.log.debug
        nickname: nickname
        count: stillValid.length
      , "Have an existing, valid recovery record."
      
      # Done
      res.status 409
      res.json
        sent: false
        existing: true
        error: "You already requested a password recovery."

    else
      req.log.debug
        nickname: nickname
      , "Have old recovery records but they're timed out."
      this null
    return
  ), ((err) ->
    throw err  if err
    req.log.debug
      nickname: nickname
    , "Creating a new recovery record."
    Recovery.create
      nickname: nickname
    , this
    return
  ), ((err, recovery) ->
    recoveryURL = undefined
    throw err  if err
    req.log.debug
      nickname: nickname
    , "Generating recovery email output."
    recoveryURL = URLMaker.makeURL("/main/recover/" + recovery.code)
    res.render "recovery-email-html",
      principal: user.profile
      principalUser: user
      recovery: recovery
      recoveryURL: recoveryURL
      layout: false
    , @parallel()
    res.render "recovery-email-text",
      principal: user.profile
      principalUser: user
      recovery: recovery
      recoveryURL: recoveryURL
      layout: false
    , @parallel()
    return
  ), ((err, html, text) ->
    throw err  if err
    req.log.debug
      nickname: nickname
    , "Sending recovery email."
    Mailer.sendEmail
      to: user.email
      subject: "Recover password for " + req.app.config.site
      text: text
      attachment:
        data: html
        type: "text/html"
        alternative: true
    , this
    return
  ), (err) ->
    if err
      next err
    else
      req.log.debug
        nickname: nickname
      , "Finished with recovery"
      res.json sent: true
    return

  return

recoverCode = (req, res, next) ->
  code = req.params.code
  res.render "recover-code",
    page:
      title: "One moment please"

    code: code

  return

redeemCode = (req, res, next) ->
  code = req.body.code
  recovery = undefined
  user = undefined
  Step (->
    Recovery.get code, this
    return
  ), ((err, results) ->
    throw err  if err
    recovery = results
    throw new Error("This recovery code was already used.")  if recovery.recovered
    throw new Error("This recovery code is too old.")  if Date.now() - Date.parse(recovery.timestamp) > Recovery.TIMEOUT
    User.get recovery.nickname, this
    return
  ), ((err, results) ->
    throw err  if err
    user = results
    setPrincipal req.session, user.profile, this
    return
  ), ((err) ->
    throw err  if err
    user.expand this
    return
  ), ((err) ->
    throw err  if err
    user.profile.expandFeeds this
    return
  ), ((err) ->
    throw err  if err
    req.app.provider.newTokenPair req.client, user, this
    return
  ), ((err, pair) ->
    throw err  if err
    user.token = pair.access_token
    user.secret = pair.token_secret
    
    # Now that we're done, mark this recovery code as done
    recovery.recovered = true
    recovery.save this
    return
  ), (err) ->
    if err
      req.log.error err
      res.status 400
      res.json error: err.message
    else
      res.json user
    return

  return

exports.addRoutes = addRoutes
