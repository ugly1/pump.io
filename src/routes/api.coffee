# routes/api.js
#
# The beating heart of a pumpin' good time
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

# Adds to globals
require "set-immediate"
databank = require("databank")
_ = require("underscore")
Step = require("step")
validator = require("validator")
OAuth = require("oauth-evanp").OAuth
check = validator.check
sanitize = validator.sanitize
filters = require("../lib/filters")
version = require("../lib/version").version
HTTPError = require("../lib/httperror").HTTPError
Stamper = require("../lib/stamper").Stamper
Mailer = require("../lib/mailer")
Scrubber = require("../lib/scrubber")
ActivitySpam = require("../lib/activityspam")
Activity = require("../lib/model/activity").Activity
AppError = require("../lib/model/activity").AppError
ActivityObject = require("../lib/model/activityobject").ActivityObject
Confirmation = require("../lib/model/confirmation").Confirmation
User = require("../lib/model/user").User
Person = require("../lib/model/person").Person
Proxy = require("../lib/model/proxy").Proxy
Credentials = require("../lib/model/credentials").Credentials
stream = require("../lib/model/stream")
Stream = stream.Stream
NotInStreamError = stream.NotInStreamError
URLMaker = require("../lib/urlmaker").URLMaker
Distributor = require("../lib/distributor")
Schlock = require("schlock")
mw = require("../lib/middleware")
authc = require("../lib/authc")
omw = require("../lib/objectmiddleware")
randomString = require("../lib/randomstring").randomString
finishers = require("../lib/finishers")
mm = require("../lib/mimemap")
saveUpload = require("../lib/saveupload").saveUpload
streams = require("../lib/streams")
reqUser = mw.reqUser
reqGenerator = mw.reqGenerator
sameUser = mw.sameUser
clientAuth = authc.clientAuth
userAuth = authc.userAuth
remoteUserAuth = authc.remoteUserAuth
remoteWriteOAuth = authc.remoteWriteOAuth
noneWriteOAuth = authc.noneWriteOAuth
userWriteOAuth = authc.userWriteOAuth
userReadAuth = authc.userReadAuth
anyReadAuth = authc.anyReadAuth
setPrincipal = authc.setPrincipal
fileContent = mw.fileContent
requestObject = omw.requestObject
requestObjectByID = omw.requestObjectByID
authorOnly = omw.authorOnly
authorOrRecipient = omw.authorOrRecipient
NoSuchThingError = databank.NoSuchThingError
AlreadyExistsError = databank.AlreadyExistsError
NoSuchItemError = databank.NoSuchItemError
addFollowed = finishers.addFollowed
addLiked = finishers.addLiked
addLikers = finishers.addLikers
addShared = finishers.addShared
firstFewReplies = finishers.firstFewReplies
firstFewShares = finishers.firstFewShares
DEFAULT_ITEMS = 20
MAX_ITEMS = DEFAULT_ITEMS * 10

# Initialize the app controller
addRoutes = (app) ->
  smw = (if (app.session) then [app.session] else [])
  
  # Proxy to a remote server
  app.get "/api/proxy/:uuid", smw, userReadAuth, reqProxy, proxyRequest
  
  # Users
  app.get "/api/user/:nickname", smw, anyReadAuth, reqUser, getUser
  app.put "/api/user/:nickname", userWriteOAuth, reqUser, sameUser, putUser
  app.del "/api/user/:nickname", userWriteOAuth, reqUser, sameUser, delUser
  app.get "/api/user/:nickname/profile", smw, anyReadAuth, reqUser, personType, getObject
  app.put "/api/user/:nickname/profile", userWriteOAuth, reqUser, sameUser, personType, reqGenerator, putObject
  
  # Feeds
  app.get "/api/user/:nickname/feed", smw, anyReadAuth, reqUser, userStream
  app.post "/api/user/:nickname/feed", userWriteOAuth, reqUser, sameUser, reqGenerator, postActivity
  app.get "/api/user/:nickname/feed/major", smw, anyReadAuth, reqUser, userMajorStream
  app.get "/api/user/:nickname/feed/minor", smw, anyReadAuth, reqUser, userMinorStream
  app.post "/api/user/:nickname/feed/major", userWriteOAuth, reqUser, sameUser, isMajor, reqGenerator, postActivity
  app.post "/api/user/:nickname/feed/minor", userWriteOAuth, reqUser, sameUser, isMinor, reqGenerator, postActivity
  
  # Inboxen
  app.get "/api/user/:nickname/inbox", smw, userReadAuth, reqUser, sameUser, userInbox
  app.post "/api/user/:nickname/inbox", remoteWriteOAuth, reqUser, postToInbox
  app.get "/api/user/:nickname/inbox/major", smw, userReadAuth, reqUser, sameUser, userMajorInbox
  app.get "/api/user/:nickname/inbox/minor", smw, userReadAuth, reqUser, sameUser, userMinorInbox
  app.get "/api/user/:nickname/inbox/direct", smw, userReadAuth, reqUser, sameUser, userDirectInbox
  app.get "/api/user/:nickname/inbox/direct/major", smw, userReadAuth, reqUser, sameUser, userMajorDirectInbox
  app.get "/api/user/:nickname/inbox/direct/minor", smw, userReadAuth, reqUser, sameUser, userMinorDirectInbox
  
  # Followers
  app.get "/api/user/:nickname/followers", smw, anyReadAuth, reqUser, userFollowers
  
  # Following
  app.get "/api/user/:nickname/following", smw, anyReadAuth, reqUser, userFollowing
  app.post "/api/user/:nickname/following", userWriteOAuth, reqUser, sameUser, reqGenerator, newFollow
  
  # Favorites
  app.get "/api/user/:nickname/favorites", smw, anyReadAuth, reqUser, userFavorites
  app.post "/api/user/:nickname/favorites", userWriteOAuth, reqUser, sameUser, reqGenerator, newFavorite
  
  # Lists
  app.get "/api/user/:nickname/lists/:type", smw, anyReadAuth, reqUser, userLists
  if app.config.uploaddir
    
    # Uploads
    app.get "/api/user/:nickname/uploads", smw, userReadAuth, reqUser, sameUser, userUploads
    app.post "/api/user/:nickname/uploads", userWriteOAuth, reqUser, sameUser, fileContent, newUpload
  
  # Global user list
  app.get "/api/users", smw, anyReadAuth, listUsers
  app.post "/api/users", noneWriteOAuth, reqGenerator, createUser
  
  # Info about yourself
  app.get "/api/whoami", smw, userReadAuth, whoami
  
  # Activities
  app.get "/api/activity/:uuid", smw, anyReadAuth, reqActivity, actorOrRecipient, getActivity
  app.put "/api/activity/:uuid", userWriteOAuth, reqActivity, actorOnly, putActivity
  app.del "/api/activity/:uuid", userWriteOAuth, reqActivity, actorOnly, delActivity
  
  # Collection members
  app.get "/api/collection/:uuid/members", smw, anyReadAuth, requestCollection, authorOrRecipient, collectionMembers
  app.post "/api/collection/:uuid/members", userWriteOAuth, requestCollection, authorOnly, reqGenerator, newMember
  
  # Group feeds
  app.get "/api/group/:uuid/members", smw, anyReadAuth, requestGroup, authorOrRecipient, groupMembers
  app.get "/api/group/:uuid/inbox", smw, anyReadAuth, requestGroup, authorOrRecipient, groupInbox
  app.get "/api/group/:uuid/documents", smw, anyReadAuth, requestGroup, authorOrRecipient, groupDocuments
  app.post "/api/group/:uuid/inbox", remoteWriteOAuth, requestGroup, postToGroupInbox
  
  # Group feeds with foreign ID
  app.get "/api/group/members", smw, anyReadAuth, requestGroupByID, authorOrRecipient, groupMembers
  app.get "/api/group/inbox", smw, anyReadAuth, requestGroupByID, authorOrRecipient, groupInbox
  app.get "/api/group/documents", smw, anyReadAuth, requestGroupByID, authorOrRecipient, groupDocuments
  
  # Object feeds with foreign ID
  app.get "/api/:type/likes", smw, anyReadAuth, requestObjectByID, authorOrRecipient, objectLikes
  app.get "/api/:type/replies", smw, anyReadAuth, requestObjectByID, authorOrRecipient, objectReplies
  app.get "/api/:type/shares", smw, anyReadAuth, requestObjectByID, authorOrRecipient, objectShares
  
  # Other objects
  app.get "/api/:type/:uuid", smw, anyReadAuth, requestObject, authorOrRecipient, getObject
  app.put "/api/:type/:uuid", userWriteOAuth, requestObject, authorOnly, reqGenerator, putObject
  app.del "/api/:type/:uuid", userWriteOAuth, requestObject, authorOnly, reqGenerator, deleteObject
  app.get "/api/:type/:uuid/likes", smw, anyReadAuth, requestObject, authorOrRecipient, objectLikes
  app.get "/api/:type/:uuid/replies", smw, anyReadAuth, requestObject, authorOrRecipient, objectReplies
  app.get "/api/:type/:uuid/shares", smw, anyReadAuth, requestObject, authorOrRecipient, objectShares
  
  # With foreign IDs; needs to be late for better matches
  app.get "/api/:type", smw, anyReadAuth, requestObjectByID, authorOrRecipient, getObject
  return


# XXX: use a common function instead of faking up params
requestCollection = (req, res, next) ->
  req.params.type = "collection"
  requestObject req, res, next
  return

requestGroup = (req, res, next) ->
  req.params.type = "group"
  requestObject req, res, next
  return

requestGroupByID = (req, res, next) ->
  req.params.type = "group"
  requestObjectByID req, res, next
  return

personType = (req, res, next) ->
  req.type = "person"
  next()
  return

isMajor = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  if activity.isMajor()
    next()
  else
    next new HTTPError("Only major activities to this feed.", 400)
  return

isMinor = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  unless activity.isMajor()
    next()
  else
    next new HTTPError("Only minor activities to this feed.", 400)
  return

userOnly = (req, res, next) ->
  person = req.person
  principal = req.principal
  if person and principal and person.id is principal.id and principal.objectType is "person"
    next()
  else
    next new HTTPError("Only the user can modify this profile.", 403)
  return

actorOnly = (req, res, next) ->
  act = req.activity
  if act and act.actor and act.actor.id is req.principal.id
    next()
  else
    next new HTTPError("Only the actor can modify this object.", 403)
  return

actorOrRecipient = (req, res, next) ->
  act = req.activity
  person = req.principal
  if act and act.actor and person and act.actor.id is person.id
    next()
  else
    act.checkRecipient person, (err, isRecipient) ->
      if err
        next err
      else unless isRecipient
        next new HTTPError("Only the actor and recipients can view this activity.", 403)
      else
        next()
      return

  return

getObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  profile = req.principal
  Step (->
    finishObject profile, obj, this
    return
  ), (err) ->
    if err
      next err
    else
      obj.sanitize()
      res.json obj
    return

  return

putObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  updates = Scrubber.scrubObject(req.body)
  act = new Activity(
    actor: req.principal
    generator: req.generator
    verb: "update"
    object: _(obj).extend(updates)
  )
  Step (->
    newActivity act, req.principalUser, this
    return
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->

    return

  return

deleteObject = (req, res, next) ->
  type = req.type
  obj = req[type]
  act = new Activity(
    actor: req.principal
    verb: "delete"
    generator: req.generator
    object: obj
  )
  Step (->
    newActivity act, req.principalUser, this
    return
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      res.json "Deleted"
      d = new Distributor(act)
      d.distribute (err) ->

    return

  return

contextEndpoint = (contextifier, streamCreator) ->
  (req, res, next) ->
    args = undefined
    try
      args = streamArgs(req, DEFAULT_ITEMS, MAX_ITEMS)
    catch e
      next e
      return
    streamCreator contextifier(req), req.principal, args, (err, collection) ->
      if err
        next err
      else
        res.json collection
      return

    return

objectReplies = contextEndpoint((req) ->
  objectType = req.type
  context =
    objectType: objectType
    obj: req[objectType]

  context.type = req.query.type  if req.query and req.query.type
  context
, streams.objectReplies)

# Feed of actors (usually persons) who have shared the object
# It's stored as a stream, so we get those
objectShares = contextEndpoint((req) ->
  type = req.type
  type: type
  obj: req[type]
, streams.objectShares)

# Feed of actors (usually persons) who have liked the object
# It's stored as a stream, so we get those
objectLikes = contextEndpoint((req) ->
  type = req.type
  type: type
  obj: req[type]
, streams.objectLikes)
getUser = (req, res, next) ->
  Step (->
    req.user.profile.expandFeeds this
    return
  ), ((err) ->
    throw err  if err
    unless req.principal
      
      # skip
      this null
    else if req.principal.id is req.user.profile.id
      
      # same user
      req.user.profile.pump_io = followed: false
      
      # skip
      this null
    else
      addFollowed req.principal, [req.user.profile], this
    return
  ), (err) ->
    next err  if err
    
    # If no user, or different user, hide email and settings
    if not req.principal or (req.principal.id isnt req.user.profile.id)
      delete req.user.email

      delete req.user.settings
    req.user.sanitize()
    res.json req.user
    return

  return

putUser = (req, res, next) ->
  newUser = req.body
  req.user.update newUser, (err, saved) ->
    if err
      next err
    else
      saved.sanitize()
      res.json saved
    return

  return

delUser = (req, res, next) ->
  user = req.user
  Step (->
    user.del this
    return
  ), ((err) ->
    throw err  if err
    usersStream this
    return
  ), ((err, str) ->
    throw err  if err
    str.remove user.nickname, this
    return
  ), (err) ->
    if err
      next err
    else
      res.json "Deleted."
    return

  return

reqActivity = (req, res, next) ->
  act = null
  uuid = req.params.uuid
  Activity.search
    _uuid: uuid
  , (err, results) ->
    if err
      next err
    else if results.length is 0 # not found
      next new HTTPError("Can't find an activity with id " + uuid, 404)
    else if results.length > 1
      next new HTTPError("Too many activities with ID = " + req.params.uuid, 500)
    else
      act = results[0]
      if act.hasOwnProperty("deleted")
        next new HTTPError("Deleted", 410)
      else
        act.expand (err) ->
          if err
            next err
          else
            req.activity = act
            next()
          return

    return

  return

getActivity = (req, res, next) ->
  principal = req.principal
  act = req.activity
  act.sanitize principal
  res.json act
  return

putActivity = (req, res, next) ->
  update = Scrubber.scrubActivity(req.body)
  req.activity.update update, (err, result) ->
    if err
      next err
    else
      result.sanitize req.principal
      res.json result
    return

  return

delActivity = (req, res, next) ->
  act = req.activity
  Step (->
    act.efface this
    return
  ), (err) ->
    if err
      next err
    else
      res.json "Deleted"
    return

  return


# Get the stream of all users
usersStream = (callback) ->
  Step (->
    Stream.get "user:all", this
    return
  ), ((err, str) ->
    if err
      if err.name is "NoSuchThingError"
        Stream.create
          name: "user:all"
        , this
      else
        throw err
    else
      callback null, str
    return
  ), (err, str) ->
    if err
      if err.name is "AlreadyExistsError"
        Stream.get "user:all", callback
      else
        callback err
    else
      callback null, str
    return

  return

thisService = (app) ->
  Service = require("../lib/model/service").Service
  new Service(
    objectType: Service.type
    url: URLMaker.makeURL("/")
    displayName: app.config.site or "pump.io"
  )

createUser = (req, res, next) ->
  user = undefined
  props = req.body
  email = undefined
  registrationActivity = (user, svc, callback) ->
    act = new Activity(
      actor: user.profile
      verb: Activity.JOIN
      object: svc
      generator: req.generator
    )
    newActivity act, user, callback
    return

  welcomeActivity = (user, svc, callback) ->
    Step (->
      res.render "welcome",
        page:
          title: "Welcome"

        profile: user.profile
        service: svc
        layout: false
      , this
      return
    ), ((err, text) ->
      throw err  if err
      act = new Activity(
        actor: svc
        verb: Activity.POST
        to: [user.profile]
        object:
          objectType: ActivityObject.NOTE
          displayName: "Welcome to " + svc.displayName
          content: text
      )
      initActivity act, this
      return
    ), (err, act) ->
      if err
        callback err, null
      else
        callback null, act
      return

    return

  sendConfirmationEmail = (user, email, callback) ->
    Step (->
      Confirmation.create
        nickname: user.nickname
        email: email
      , this
      return
    ), ((err, confirmation) ->
      confirmationURL = undefined
      throw err  if err
      confirmationURL = URLMaker.makeURL("/main/confirm/" + confirmation.code)
      res.render "confirmation-email-html",
        principal: user.profile
        principalUser: user
        confirmation: confirmation
        confirmationURL: confirmationURL
        layout: false
      , @parallel()
      res.render "confirmation-email-text",
        principal: user.profile
        principalUser: user
        confirmation: confirmation
        confirmationURL: confirmationURL
        layout: false
      , @parallel()
      return
    ), ((err, html, text) ->
      throw err  if err
      Mailer.sendEmail
        to: email
        subject: "Confirm your email address for " + req.app.config.site
        text: text
        attachment:
          data: html
          type: "text/html"
          alternative: true
      , this
      return
    ), (err, message) ->
      callback err
      return

    return

  defaultLists = (user, callback) ->
    Step ((err, str) ->
      lists = [
        "Friends"
        "Family"
        "Acquaintances"
        "Coworkers"
      ]
      group = @group()
      throw err  if err
      _.each lists, (list) ->
        act = new Activity(
          verb: Activity.CREATE
          to: [
            objectType: ActivityObject.COLLECTION
            id: user.profile.followers.url
          ]
          object:
            objectType: ActivityObject.COLLECTION
            displayName: list
            objectTypes: ["person"]
        )
        newActivity act, user, group()
        return

      return
    ), callback
    return

  if req.app.config.disableRegistration
    next new HTTPError("No registration allowed.", 403)
    return
  
  # Email validation
  if req.app.config.requireEmail
    if not _.has(props, "email") or not _.isString(props.email) or props.email.length is 0
      next new HTTPError("No email address", 400)
      return
    else
      try
        check(props.email).isEmail()
        email = props.email
        delete props.email
      catch e
        next new HTTPError(e.message, 400)
        return
  Step (->
    User.create props, this
    return
  ), ((err, value) ->
    if err
      
      # Try to be more specific
      if err instanceof User.BadPasswordError
        throw new HTTPError(err.message, 400)
      else if err instanceof User.BadNicknameError
        throw new HTTPError(err.message, 400)
      else if err.name is "AlreadyExistsError"
        throw new HTTPError(err.message, 409) # conflict
      else
        throw err
    user = value
    usersStream this
    return
  ), ((err, str) ->
    throw err  if err
    str.deliver user.nickname, this
    return
  ), ((err) ->
    throw err  if err
    user.expand this
    return
  ), ((err) ->
    throw err  if err
    if req.app.config.requireEmail
      sendConfirmationEmail user, email, this
    else
      
      # skip if we don't require email
      this null
    return
  ), ((err) ->
    svc = undefined
    throw err  if err
    svc = thisService(req.app)
    registrationActivity user, svc, @parallel()
    welcomeActivity user, svc, @parallel()
    defaultLists user, @parallel()
    return
  ), ((err, reg, welcome, lists) ->
    rd = undefined
    wd = undefined
    group = @group()
    throw err  if err
    rd = new Distributor(reg)
    rd.distribute group()
    wd = new Distributor(welcome)
    wd.distribute group()
    _.each lists, (list) ->
      d = new Distributor(list)
      d.distribute group()
      return

    return
  ), ((err) ->
    throw err  if err
    req.app.provider.newTokenPair req.client, user, this
    return
  ), (err, pair) ->
    if err
      next err
    else
      
      # Hide the password for output
      user.sanitize()
      user.token = pair.access_token
      user.secret = pair.token_secret
      
      # If called as /main/register; see ./web.js
      # XXX: Bad hack
      if req.session
        setPrincipal req.session, user.profile, (err) ->
          if err
            next err
          else
            res.json user
          return

      else
        res.json user
    return

  return

listUsers = (req, res, next) ->
  url = URLMaker.makeURL("api/users")
  collection =
    displayName: "Users of this service"
    id: url
    objectTypes: ["user"]
    links:
      first:
        href: url

      self:
        href: url

  args = undefined
  str = undefined
  try
    args = streamArgs(req, DEFAULT_ITEMS, MAX_ITEMS)
  catch e
    next e
    return
  Step (->
    usersStream this
    return
  ), ((err, result) ->
    throw err  if err
    str = result
    str.count this
    return
  ), ((err, totalUsers) ->
    throw err  if err
    collection.totalItems = totalUsers
    if totalUsers is 0
      collection.items = []
      res.json collection
      return
    else
      if _(args).has("before")
        str.getIDsGreaterThan args.before, args.count, this
      else if _(args).has("since")
        str.getIDsLessThan args.since, args.count, this
      else
        str.getIDs args.start, args.end, this
    return
  ), ((err, userIds) ->
    throw err  if err
    User.readArray userIds, this
    return
  ), (err, users) ->
    i = undefined
    throw err  if err
    _.each users, (user) ->
      user.sanitize()
      delete user.email  if not req.principal or req.principal.id isnt user.profile.id
      return

    collection.items = users
    if users.length > 0
      collection.links.prev = href: url + "?since=" + encodeURIComponent(users[0].nickname)
      collection.links.next = href: url + "?before=" + encodeURIComponent(users[users.length - 1].nickname)  if (_(args).has("start") and args.start + users.length < collection.totalItems) or (_(args).has("before") and users.length >= args.count) or (_(args).has("since"))
    res.json collection
    return

  return

postActivity = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  activity = new Activity(props)
  finishAndSend = (profile, activity, callback) ->
    dupe = new Activity(_.clone(activity))
    Step (->
      finishProperty profile, dupe, "object", @parallel()
      finishProperty profile, dupe, "target", @parallel()
      return
    ), (err, object, target) ->
      if err
        callback err
      else
        dupe.sanitize req.principal
        
        # ...then show (possibly modified) results.
        res.json dupe
        callback null
      return

    return

  distributeActivity = (activity, callback) ->
    dupe = new Activity(_.clone(activity))
    d = new Distributor(dupe)
    d.distribute callback
    return

  
  # Add a default actor
  activity.actor = req.user.profile  unless _(activity).has("actor")
  
  # If the actor is incorrect, error
  if activity.actor.id isnt req.user.profile.id
    next new HTTPError("Invalid actor", 400)
    return
  
  # XXX: we overwrite anything here
  activity.generator = req.generator
  
  # Default verb
  activity.verb = "post"  if not _(activity).has("verb") or _(activity.verb).isNull()
  Step (->
    newActivity activity, req.user, this
    return
  ), ((err, results) ->
    throw err  if err
    activity = results
    finishAndSend req.principal, activity, @parallel()
    distributeActivity activity, @parallel()
    return
  ), (err) ->
    if err
      next err
    else

    return

  return


# Done!
remotes = new Schlock()
ensureRemoteActivity = (principal, props, retries, callback) ->
  act = undefined
  lastErr = undefined
  unless callback
    callback = retries
    retries = 0
  Step (->
    remotes.writeLock props.id, this
    return
  ), ((err) ->
    if err
      
      # If we can't lock, leave here
      callback err
      return
    Activity.get props.id, this
    return
  ), ((err, activity) ->
    if err and err.name is "NoSuchThingError"
      newRemoteActivity principal, props, this
    else this null, activity  unless err
    return
  ), ((err, activity) ->
    lastErr = err
    act = activity
    remotes.writeUnlock props.id, this
    return
  ), (err) ->
    
    # Ignore err; unlock errors don't matter
    if lastErr
      if retries is 0
        ensureRemoteActivity principal, props, retries + 1, callback
      else
        callback lastErr, null
    else
      callback null, act
    return

  return

newRemoteActivity = (principal, props, callback) ->
  activity = new Activity(props)
  Step (->
    
    # Default verb
    activity.verb = "post"  if not _(activity).has("verb") or _(activity.verb).isNull()
    
    # Add a received timestamp
    activity.received = Stamper.stamp()
    
    # TODO: return a 202 Accepted here?
    
    # First, ensure recipients
    activity.ensureRecipients this
    return
  ), ((err) ->
    throw err  if err
    
    # apply the activity
    activity.apply principal, this
    return
  ), ((err) ->
    if err
      if err.name is "AppError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchThingError"
        throw new HTTPError(err.message, 400)
      else if err.name is "AlreadyExistsError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchItemError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    
    # ...then persist...
    activity.save this
    return
  ), callback
  return

validateActor = (client, principal, actor) ->
  if client.webfinger
    throw new HTTPError("Actor is invalid since " + actor.id + " is not " + principal.id, 400)  unless ActivityObject.canonicalID(actor.id) is ActivityObject.canonicalID(principal.id)
  else throw new HTTPError("Actor is invalid since " + actor.id + " is not " + principal.id, 400)  if ActivityObject.canonicalID(actor.id) isnt "https://" + client.hostname + "/" and ActivityObject.canonicalID(actor.id) isnt "http://" + client.hostname + "/"  if client.hostname
  true

postToInbox = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  act = undefined
  user = req.user
  
  # Check for actor
  next new HTTPError("Invalid actor", 400)  unless _(props).has("actor")
  try
    validateActor req.client, req.principal, props.actor
  catch err
    next err
    return
  Step (->
    ensureRemoteActivity req.principal, props, this
    return
  ), ((err, activity) ->
    throw err  if err
    act = activity
    
    # throws on mismatch
    validateActor req.client, req.principal, act.actor
    user.addToInbox activity, this
    return
  ), ((err) ->
    throw err  if err
    act.checkRecipient user.profile, this
    return
  ), ((err, isRecipient) ->
    throw err  if err
    if isRecipient
      this null
    else
      act.addReceived user.profile, this
    return
  ), (err) ->
    if err
      next err
    else
      act.sanitize req.principal
      
      # ...then show (possibly modified) results.
      # XXX: don't distribute
      res.json act
    return

  return

validateGroupRecipient = (group, act) ->
  props = [
    "to"
    "cc"
    "bto"
    "bcc"
  ]
  recipients = []
  props.forEach (prop) ->
    recipients = recipients.concat(act[prop])  if _(act).has(prop) and _(act[prop]).isArray()
    return

  throw new HTTPError("Group " + group.id + " is not a recipient of activity " + act.id, 400)  unless _.some(recipients, (item) ->
    item.id is group.id and item.objectType is group.objectType
  )
  true

postToGroupInbox = (req, res, next) ->
  props = Scrubber.scrubActivity(req.body)
  act = undefined
  group = req.group
  
  # Check for actor
  next new HTTPError("Invalid actor", 400)  unless _(props).has("actor")
  try
    validateActor req.client, req.principal, props.actor
    validateGroupRecipient req.group, props
  catch err
    next err
    return
  Step (->
    ensureRemoteActivity req.principal, props, this
    return
  ), ((err, activity) ->
    
    # These throw on invalid input
    validateActor req.client, req.principal, activity.actor
    validateGroupRecipient req.group, activity
    this null, activity
    return
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.sanitize req.principal
      
      # ...then show (possibly modified) results.
      # XXX: don't distribute
      res.json act
      d = new Distributor(act)
      d.toLocalGroup req.group, (err) ->
        req.log.error err
        return

    return

  return

initActivity = (activity, callback) ->
  Step (->
    
    # First, ensure recipients
    activity.ensureRecipients this
    return
  ), ((err) ->
    throw err  if err
    ActivitySpam.test activity, this
    return
  ), ((err, isSpam, probability) ->
    throw err  if err
    
    # XXX: do some social trust metrics
    throw new HTTPError("Looks like spam", 400)  if isSpam
    
    # apply the activity
    activity.apply null, this
    return
  ), ((err) ->
    if err
      if err.name is "AppError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchThingError"
        throw new HTTPError(err.message, 400)
      else if err.name is "AlreadyExistsError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NoSuchItemError"
        throw new HTTPError(err.message, 400)
      else if err.name is "NotInStreamError"
        throw new HTTPError(err.message, 400)
      else
        throw err
    
    # ...then persist...
    activity.save this
    return
  ), (err, saved) ->
    if err
      callback err, null
    else
      callback null, activity
    return

  return

newActivity = (activity, user, callback) ->
  activity.actor = user.profile  unless _(activity).has("actor")
  Step (->
    initActivity activity, this
    return
  ), ((err, saved) ->
    throw err  if err
    activity = saved
    user.addToOutbox activity, @parallel()
    user.addToInbox activity, @parallel()
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, activity
    return

  return

streamEndpoint = (streamCreator) ->
  (req, res, next) ->
    args = undefined
    try
      args = streamArgs(req, DEFAULT_ITEMS, MAX_ITEMS)
    catch e
      next e
      return
    streamCreator
      user: req.user
    , req.principal, args, (err, collection) ->
      if err
        next err
      else
        res.json collection
      return

    return

userStream = streamEndpoint(streams.userStream)
userMajorStream = streamEndpoint(streams.userMajorStream)
userMinorStream = streamEndpoint(streams.userMinorStream)
userInbox = streamEndpoint(streams.userInbox)
userMajorInbox = streamEndpoint(streams.userMajorInbox)
userMinorInbox = streamEndpoint(streams.userMinorInbox)
userDirectInbox = streamEndpoint(streams.userDirectInbox)
userMajorDirectInbox = streamEndpoint(streams.userMajorDirectInbox)
userMinorDirectInbox = streamEndpoint(streams.userMinorDirectInbox)
userFollowers = contextEndpoint((req) ->
  user: req.user
  author: req.person
, streams.userFollowers)
userFollowing = contextEndpoint((req) ->
  user: req.user
  author: req.person
, streams.userFollowing)
userFavorites = contextEndpoint((req) ->
  user: req.user
  author: req.person
, streams.userFavorites)
userUploads = contextEndpoint((req) ->
  user: req.user
  author: req.person
, streams.userUploads)
userLists = contextEndpoint((req) ->
  user: req.user
  type: req.params.type
, streams.userLists)
newFollow = (req, res, next) ->
  obj = Scrubber.scrubObject(req.body)
  act = new Activity(
    actor: req.user.profile
    verb: "follow"
    object: obj
    generator: req.generator
  )
  Step (->
    newActivity act, req.user, this
    return
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->

    return

  return

newFavorite = (req, res, next) ->
  obj = Scrubber.scrubObject(req.body)
  act = new Activity(
    actor: req.user.profile
    verb: "favorite"
    object: obj
    generator: req.generator
  )
  Step (->
    newActivity act, req.user, this
    return
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->

    return

  return

newUpload = (req, res, next) ->
  user = req.principalUser
  mimeType = req.uploadMimeType
  fileName = req.uploadFile
  uploadDir = req.app.config.uploaddir
  Step (->
    saveUpload user, mimeType, fileName, uploadDir, this
    return
  ), (err, obj) ->
    if err
      next err
    else
      obj.sanitize()
      res.json obj
    return

  return

collectionMembers = contextEndpoint((req) ->
  context =
    collection: req.collection
    author: req.collection.author

  if req.query.type
    context.type = req.query.type
  else context.type = req.collection.objectTypes[0]  if req.collection.objectTypes and req.collection.objectTypes.length > 0
  context
, streams.collectionMembers)
groupMembers = contextEndpoint((req) ->
  context =
    group: req.group
    author: req.group.author

  context
, streams.groupMembers)
groupInbox = contextEndpoint((req) ->
  context = group: req.group
  context
, streams.groupInbox)
groupDocuments = contextEndpoint((req) ->
  context =
    group: req.group
    author: req.group.author

  context
, streams.groupDocuments)
newMember = (req, res, next) ->
  coll = req.collection
  obj = Scrubber.scrubObject(req.body)
  act = new Activity(
    verb: "add"
    object: obj
    target: coll
    generator: req.generator
  )
  Step (->
    newActivity act, req.principalUser, this
    return
  ), (err, act) ->
    d = undefined
    if err
      next err
    else
      act.object.sanitize()
      res.json act.object
      d = new Distributor(act)
      d.distribute (err) ->

    return

  return


# Since most stream endpoints take the same arguments,
# consolidate validation and parsing here
streamArgs = (req, defaultCount, maxCount) ->
  args = {}
  try
    maxCount = 10 * defaultCount  if _(maxCount).isUndefined()
    if _(req.query).has("count")
      check(req.query.count, "Count must be between 0 and " + maxCount).isInt().min(0).max maxCount
      args.count = sanitize(req.query.count).toInt()
    else
      args.count = defaultCount
    
    # XXX: Check "before" and "since" for injection...?
    # XXX: Check "before" and "since" for URI...?
    if _(req.query).has("before")
      check(req.query.before).notEmpty()
      args.before = sanitize(req.query.before).trim()
    if _(req.query).has("since")
      throw new Error("Can't have both 'before' and 'since' parameters")  if _(args).has("before")
      check(req.query.since).notEmpty()
      args.since = sanitize(req.query.since).trim()
    if _(req.query).has("offset")
      throw new Error("Can't have both 'before' and 'offset' parameters")  if _(args).has("before")
      throw new Error("Can't have both 'since' and 'offset' parameters")  if _(args).has("since")
      check(req.query.offset, "Offset must be an integer greater than or equal to zero").isInt().min 0
      args.start = sanitize(req.query.offset).toInt()
    args.start = 0  if not _(req.query).has("offset") and not _(req.query).has("since") and not _(req.query).has("before")
    args.end = args.start + args.count  if _(args).has("start")
    args.q = req.query.q  if _.has(req.query, "q")
    return args
  catch e
    throw new HTTPError(e.message, 400)
  return

whoami = (req, res, next) ->
  res.redirect "/api/user/" + req.principalUser.nickname + "/profile", 302
  return

reqProxy = (req, res, next) ->
  id = req.params.uuid
  Step (->
    Proxy.search
      id: id
    , this
    return
  ), (err, proxies) ->
    if err
      next err
    else if not proxies or proxies.length is 0
      next new HTTPError("No such proxy", 404)
    else if proxies.length > 1
      next new HTTPError("Too many proxies", 500)
    else
      req.proxy = proxies[0]
      next()
    return

  return

proxyRequest = (req, res, next) ->
  principal = req.principal
  proxy = req.proxy
  req.log.debug
    url: proxy.url
    principal: principal.id
  , "Getting object through proxy."
  
  # XXX: check local cache first
  Step (->
    Credentials.getFor principal.id, proxy.url, this
    return
  ), ((err, cred) ->
    oa = undefined
    headers = undefined
    throw err  if err
    headers = "User-Agent": "pump.io/" + version
    headers["If-Modified-Since"] = req.headers["if-modified-since"]  if req.headers["if-modified-since"]
    headers["If-None-Match"] = req.headers["if-none-match"]  if req.headers["if-none-match"]
    # nonce size; use default
    oa = new OAuth(null, null, cred.client_id, cred.client_secret, "1.0", null, "HMAC-SHA1", null, headers)
    oa.get proxy.url, null, null, this
    return
  ), (err, pbody, pres) ->
    toCopy = undefined
    if err
      if err.statusCode is 304
        res.statusCode = 304
        res.end()
      else
        next new HTTPError("Unable to retrieve proxy data", 500)
    else
      res.setHeader "Content-Type", pres.headers["content-type"]  if pres.headers["content-type"]
      res.setHeader "Last-Modified", pres.headers["last-modified"]  if pres.headers["last-modified"]
      res.setHeader "ETag", pres.headers["etag"]  if pres.headers["etag"]
      res.setHeader "Expires", pres.headers["expires"]  if pres.headers["expires"]
      res.setHeader "Cache-Control", pres.headers["cache-control"]  if pres.headers["cache-control"]
      
      # XXX: save to local cache
      req.log.debug
        headers: pres.headers
      , "Received object"
      res.send pbody
    return

  return

finishProperty = (profile, obj, prop, callback) ->
  unless obj[prop]
    setImmediate ->
      callback null
      return

    return
  Step (->
    finishObject profile, obj[prop], this
    return
  ), callback
  return

finishObject = (profile, obj, callback) ->
  Step (->
    obj.expandFeeds this
    return
  ), ((err) ->
    throw err  if err
    addLiked profile, [obj], @parallel()
    addLikers profile, [obj], @parallel()
    addShared profile, [obj], @parallel()
    firstFewReplies profile, [obj], @parallel()
    firstFewShares profile, [obj], @parallel()
    addFollowed profile, [obj], @parallel()  if obj.isFollowable()
    return
  ), (err) ->
    callback err
    return

  return

exports.addRoutes = addRoutes
exports.createUser = createUser
