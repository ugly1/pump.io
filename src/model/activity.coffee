# activity.js
#
# data object representing an activity
#
# Copyright 2011,2012 E14N https://e14n.com/
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
URLMaker = require("../urlmaker").URLMaker
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
ActivityObject = require("./activityobject").ActivityObject
Edge = require("./edge").Edge
Share = require("./share").Share
Favorite = require("./favorite").Favorite
DatabankObject = databank.DatabankObject
NoSuchThingError = databank.NoSuchThingError
NotInStreamError = require("./stream").NotInStreamError
sanitize = validator.sanitize
AppError = (msg) ->
  Error.captureStackTrace this, AppError
  @name = "AppError"
  @message = msg
  return

AppError:: = new Error()
AppError::constructor = AppError
Activity = DatabankObject.subClass("activity")
Activity.schema =
  pkey: "id"
  fields: [
    "actor"
    "content"
    "generator"
    "icon"
    "id"
    "object"
    "published"
    "provider"
    "target"
    "title"
    "url"
    "_uuid"
    "to"
    "cc"
    "bto"
    "bcc"
    "_received"
    "updated"
    "verb"
  ]
  indices: [
    "actor.id"
    "object.id"
    "_uuid"
  ]

oprops = [
  "actor"
  "generator"
  "provider"
  "object"
  "target"
  "context"
  "location"
  "source"
]
aprops = [
  "to"
  "cc"
  "bto"
  "bcc"
]
Activity.init = (inst, properties) ->
  i = undefined
  DatabankObject.init inst, properties
  inst.verb = "post"  unless inst.verb
  inst.actor = ActivityObject.toObject(inst.actor, ActivityObject.PERSON)  if inst.actor
  _.each _.without(oprops, "actor"), (prop) ->
    inst[prop] = ActivityObject.toObject(inst[prop])  if inst[prop] and _.isObject(inst[prop]) and (inst[prop] not instanceof ActivityObject)
    return

  _.each aprops, (aprop) ->
    addrs = inst[aprop]
    if addrs and _.isArray(addrs)
      _.each addrs, (addr, i) ->
        addrs[i] = ActivityObject.toObject(addr, ActivityObject.PERSON)  if addr and _.isObject(addr) and (addr instanceof ActivityObject)
        return

    return

  return

Activity::apply = (defaultActor, callback) ->
  act = this
  verb = undefined
  method = undefined
  camelCase = (str) ->
    parts = str.split("-")
    upcase = parts.map((part) ->
      part.substring(0, 1).toUpperCase() + part.substring(1, part.length).toLowerCase()
    )
    upcase.join ""

  
  # Ensure an actor
  act.actor = act.actor or defaultActor
  
  # Find the apply method
  verb = act.verb
  
  # On unknown verb, skip
  unless _.contains(Activity.verbs, verb)
    callback null
    return
  
  # Method like applyLike or applyStopFollowing
  method = "apply" + camelCase(verb)
  
  # Do we know how to apply it?
  unless _.isFunction(act[method])
    callback null
    return
  act[method] callback
  return

Activity::applyPost = (callback) ->
  act = this
  postNew = (object, callback) ->
    ActivityObject.createObject act.object, callback
    return

  postExisting = (object, callback) ->
    Step (->
      Activity.postOf object, this
      return
    ), (err, post) ->
      throw err  if err
      if post
        callback new Error("Already posted"), null
      else
        callback null, act.object
      return

    return

  
  # Force author data
  @object.author = @actor
  
  # Is this it...?
  Step (->
    ActivityObject.getObject act.object.objectType, act.object.id, this
    return
  ), ((err, obj) ->
    if err and err.name is "NoSuchThingError"
      postNew act.object, this
    else if err and err.name isnt "NoSuchThingError"
      throw err
    else postExisting act.object, this  unless err
    return
  ), (err, obj) ->
    if err
      callback err, null
    else if act.target
      addToTarget act.actor, act.object, act.target, callback
    else
      callback null, obj
    return

  return

Activity::applyCreate = Activity::applyPost
Activity::applyFollow = (callback) ->
  act = this
  User = require("./user").User
  user = undefined
  unless @actor.id
    callback new AppError("No actor ID for activity " + act.id)
    return
  else unless @object.id
    callback new AppError("No object ID for activity " + act.id)
    return
  Step (->
    Edge.create
      from: act.actor
      to: act.object
    , this
    return
  ), ((err, edge) ->
    throw err  if err
    ActivityObject.ensureObject act.actor, @parallel()
    ActivityObject.ensureObject act.object, @parallel()
    return
  ), ((err, follower, followed) ->
    throw err  if err
    User.fromPerson follower.id, @parallel()
    User.fromPerson followed.id, @parallel()
    return
  ), ((err, followerUser, followedUser) ->
    group = @group()
    throw err  if err
    followerUser.addFollowing act.object.id, group()  if followerUser
    followedUser.addFollower act.actor.id, group()  if followedUser
    return
  ), (err) ->
    if err
      callback err
    else
      callback null
    return

  return

Activity::applyStopFollowing = (callback) ->
  act = this
  User = require("./user").User
  user = undefined
  unless @actor.id
    callback new AppError("No actor ID for activity " + act.id)
    return
  else unless @object.id
    callback new AppError("No object ID for activity " + act.id)
    return
  
  # XXX: OStatus if necessary
  Step (->
    Edge.get Edge.id(act.actor.id, act.object.id), this
    return
  ), ((err, edge) ->
    throw err  if err
    edge.del this
    return
  ), ((err) ->
    throw err  if err
    ActivityObject.ensureObject act.actor, @parallel()
    ActivityObject.ensureObject act.object, @parallel()
    return
  ), ((err, follower, followed) ->
    throw err  if err
    User.fromPerson follower.id, @parallel()
    User.fromPerson followed.id, @parallel()
    return
  ), ((err, followerUser, followedUser) ->
    group = @group()
    throw err  if err
    followerUser.removeFollowing act.object.id, group()  if followerUser
    followedUser.removeFollower act.actor.id, group()  if followedUser
    return
  ), (err) ->
    if err
      callback err
    else
      callback null
    return

  return

Activity::applyFavorite = (callback) ->
  act = this
  User = require("./user").User
  Step (->
    Favorite.create
      from: act.actor
      to: act.object
    , this
    return
  ), ((err, fave) ->
    throw err  if err
    ActivityObject.ensureObject act.object, this
    return
  ), ((err, object) ->
    throw err  if err
    object.favoritedBy act.actor.id, this
    return
  ), ((err) ->
    throw err  if err
    User.fromPerson act.actor.id, this
    return
  ), ((err, user) ->
    throw err  if err
    if user
      user.addToFavorites act.object, this
    else
      this null
    return
  ), callback
  return

Activity::applyLike = Activity::applyFavorite
Activity::applyUnfavorite = (callback) ->
  act = this
  User = require("./user").User
  Step (->
    Favorite.get Favorite.id(act.actor.id, act.object.id), this
    return
  ), ((err, favorite) ->
    throw err  if err
    favorite.del this
    return
  ), ((err) ->
    throw err  if err
    ActivityObject.ensureObject act.object, this
    return
  ), ((err, obj) ->
    throw err  if err
    obj.unfavoritedBy act.actor.id, this
    return
  ), ((err) ->
    throw err  if err
    User.fromPerson act.actor.id, this
    return
  ), ((err, user) ->
    throw err  if err
    if user
      user.removeFromFavorites act.object, this
    else
      this null
    return
  ), callback
  return

Activity::applyUnlike = Activity::applyUnfavorite
Activity::applyDelete = (callback) ->
  act = this
  Step (->
    ActivityObject.getObject act.object.objectType, act.object.id, this
    return
  ), ((err, toDelete) ->
    throw err  if err
    throw new AppError("Can't delete " + toDelete.id + ": not author.")  if not _.has(toDelete, "author") or not _.isObject(toDelete.author) or (toDelete.author.id isnt act.actor.id)
    toDelete.efface this
    return
  ), (err, ts) ->
    if err
      callback err
    else
      callback null
    return

  return

Activity::applyUpdate = (callback) ->
  act = this
  Step (->
    ActivityObject.getObject act.object.objectType, act.object.id, this
    return
  ), ((err, toUpdate) ->
    throw err  if err
    if _.has(toUpdate, "author") and _.isObject(toUpdate.author)
      
      # has an author; check if it's the actor
      throw new AppError("Can't update " + toUpdate.id + ": not author.")  if toUpdate.author.id isnt act.actor.id
    else
      
      # has no author; only OK if it's the actor updating their own profile
      throw new AppError("Can't update " + toUpdate.id + ": not you.")  if act.actor.id isnt act.object.id
    toUpdate.update act.object, this
    return
  ), (err, result) ->
    if err
      callback err
    else
      act.object = result
      callback null
    return

  return

Activity::applyAdd = (callback) ->
  act = this
  addToTarget act.actor, act.object, act.target, callback
  return

addToTarget = (actor, object, target, callback) ->
  addToCollection = (actor, object, target, callback) ->
    user = undefined
    Step (->
      Collection = require("./collection").Collection
      Collection.isList target, this
      return
    ), ((err, result) ->
      throw err  if err
      user = result
      unless user
        
        # It's not our list, so we don't care.
        callback null, null
      else
        
        # XXX: we don't guard targets we don't know the author of
        throw new AppError("Can't add to " + target.id + ": not author.")  if target.author and target.author.id isnt actor.id
        
        # XXX: we don't guard targets with unknown types
        throw new AppError("Can't add to " + target.id + ": incorrect type.")  if _(target).has("objectTypes") and _(target.objectTypes).isArray() and target.objectTypes.indexOf(object.objectType) is -1
        target.getStream this
      return
    ), ((err, stream) ->
      throw err  if err
      stream.deliverObject
        id: object.id
        objectType: object.objectType
      , this
      return
    ), (err) ->
      if err
        callback err
      else
        callback null
      return

    return

  addToGroup = (actor, object, target, callback) ->
    str = undefined
    Step (->
      Membership = require("./membership").Membership
      Membership.isMember actor, target, this
      return
    ), ((err, isMember) ->
      throw err  if err
      throw new AppError("Actor is not a member of the group.")  unless isMember
      target.getDocumentsStream this
      return
    ), ((err, results) ->
      throw err  if err
      str = results
      str.hasObject
        id: object.id
        objectType: object.objectType
      , this
      return
    ), ((err, hasObject) ->
      throw err  if err
      throw new AppError("Group already contains object.")  if hasObject
      str.deliverObject
        id: object.id
        objectType: object.objectType
      , this
      return
    ), callback
    return

  Step (->
    ActivityObject.ensureObject object, @parallel()
    ActivityObject.ensureObject target, @parallel()
    return
  ), ((err, toAdd, target) ->
    throw err  if err
    switch target.objectType
      when ActivityObject.COLLECTION
        addToCollection actor, toAdd, target, this
      when ActivityObject.GROUP
        addToGroup actor, toAdd, target, this
      else
        throw new AppError("Can't add to " + target.id + ": don't know how to add to type '" + target.objectType + "'")
    return
  ), callback
  return

Activity::applyRemove = (callback) ->
  act = this
  removeFromCollection = (actor, object, target, callback) ->
    throw new AppError("Can't remove from " + target.id + ": not author.")  if target.author.id isnt actor.id
    throw new AppError("Can't remove from " + target.id + ": incorrect type.")  if not _(target).has("objectTypes") or not _(target.objectTypes).isArray() or target.objectTypes.indexOf(object.objectType) is -1
    Step (->
      target.getStream this
      return
    ), ((err, stream) ->
      throw err  if err
      stream.removeObject
        id: object.id
        objectType: object.objectType
      , this
      return
    ), (err) ->
      if err
        callback err
      else
        callback null
      return

    return

  removeFromGroup = (actor, object, target, callback) ->
    str = undefined
    Step (->
      Membership = require("./membership").Membership
      Membership.isMember actor, target, this
      return
    ), ((err, isMember) ->
      throw err  if err
      throw new AppError("Actor is not a member of the group.")  unless isMember
      target.getDocumentsStream this
      return
    ), ((err, results) ->
      throw err  if err
      str = results
      str.removeObject
        id: object.id
        objectType: object.objectType
      , this
      return
    ), callback
    return

  Step (->
    ActivityObject.ensureObject act.object, @parallel()
    ActivityObject.getObject act.target.objectType, act.target.id, @parallel()
    return
  ), ((err, toRemove, target) ->
    throw err  if err
    switch target.objectType
      when ActivityObject.COLLECTION
        removeFromCollection act.actor, toRemove, target, this
        return
      when ActivityObject.GROUP
        removeFromGroup act.actor, toRemove, target, this
        return
      else
        throw new AppError("Can't remove from " + target.id + ": don't know how to remove from a '" + target.objectType + "'.")
    return
  ), callback
  return

Activity::applyShare = (callback) ->
  act = this
  Step (->
    ActivityObject.ensureObject act.object, this
    return
  ), ((err, obj) ->
    throw err  if err
    obj.getSharesStream this
    return
  ), ((err, str) ->
    ref = undefined
    throw err  if err
    ref =
      objectType: act.actor.objectType
      id: act.actor.id

    str.deliverObject ref, this
    return
  ), ((err) ->
    share = undefined
    throw err  if err
    share = new Share(
      sharer: act.actor
      shared: act.object
    )
    share.save this
    return
  ), callback
  return

Activity::applyUnshare = (callback) ->
  act = this
  Step (->
    ActivityObject.ensureObject act.object, this
    return
  ), ((err, obj) ->
    throw err  if err
    obj.getSharesStream this
    return
  ), ((err, str) ->
    ref = undefined
    throw err  if err
    ref =
      objectType: act.actor.objectType
      id: act.actor.id

    str.removeObject ref, this
    return
  ), ((err) ->
    throw err  if err
    Share.get Share.id(act.actor, act.object), this
    return
  ), ((err, share) ->
    throw err  if err
    share.del this
    return
  ), callback
  return


# For joining something.
# Although the object can be a few things (like services)
# we only monitor when someone joins a group.
Activity::applyJoin = (callback) ->
  act = this
  Membership = require("./membership").Membership
  group = undefined
  joinLocal = (callback) ->
    Step (->
      Activity.postOf group, this
      return
    ), ((err, post) ->
      throw err  if err
      throw new Error("No authorization info for group " + group.displayName)  unless post
      post.checkRecipient act.actor, this
      return
    ), ((err, isRecipient) ->
      throw err  if err
      throw new Error(act.actor.displayName + " is not allowed to join group " + group.displayName)  unless isRecipient
      Membership.create
        member: act.actor
        group: group
      , this
      return
    ), ((err, mem) ->
      throw err  if err
      group.getMembersStream this
      return
    ), ((err, str) ->
      throw err  if err
      str.deliver act.actor.id, this
      return
    ), callback
    return

  joinRemote = (callback) ->
    Step (->
      Membership.create
        member: act.actor
        group: group
      , this
      return
    ), callback
    return

  
  # We just care about groups
  unless act.object.objectType is ActivityObject.GROUP
    callback null
    return
  
  # Record the membership
  Step (->
    ActivityObject.ensureObject act.object, this
    return
  ), ((err, results) ->
    throw err  if err
    group = results
    group.isLocal this
    return
  ), ((err, isLocal) ->
    throw err  if err
    if isLocal
      joinLocal this
    else
      joinRemote this
    return
  ), callback
  return


# For leaving something.
# Although the object can be a few things (like services)
# we only monitor when someone joins a group.
Activity::applyLeave = (callback) ->
  act = this
  group = undefined
  
  # We just care about groups
  unless act.object.objectType is ActivityObject.GROUP
    callback null
    return
  
  # Record the membership
  Step (->
    ActivityObject.ensureObject act.object, this
    return
  ), ((err, results) ->
    Membership = require("./membership").Membership
    throw err  if err
    group = results
    Membership.get Membership.id(act.actor.id, group.id), this
    return
  ), ((err, membership) ->
    throw err  if err
    membership.del this
    return
  ), ((err) ->
    User = require("./user").User
    throw err  if err
    if not group.author or not group.author.id
      callback null
    else
      User.fromPerson group.author.id, this
    return
  ), ((err, user) ->
    throw err  if err
    unless user
      callback null
    else
      group.getMembersStream this
    return
  ), ((err, str) ->
    throw err  if err
    str.remove act.actor.id, this
    return
  ), callback
  return

Activity::recipients = ->
  act = this
  props = [
    "to"
    "cc"
    "bto"
    "bcc"
    "_received"
  ]
  recipients = []
  props.forEach (prop) ->
    recipients = recipients.concat(act[prop])  if _(act).has(prop) and _(act[prop]).isArray()
    return

  
  # XXX: ensure uniqueness
  recipients


# Set default recipients
Activity::ensureRecipients = (callback) ->
  act = this
  recipients = act.recipients()
  setToFollowers = (act, callback) ->
    Step (->
      ActivityObject.ensureObject act.actor, this
      return
    ), ((err, actor) ->
      throw err  if err
      actor.followersURL this
      return
    ), (err, url) ->
      if err
        callback err
      else unless url
        callback new Error("no followers url")
      else
        act.cc = [
          objectType: "collection"
          id: url
        ]
        callback null
      return

    return

  
  # If we've got recipients, cool.
  if recipients.length > 0
    callback null
    return
  
  # Modification verbs use same as original post
  # Note: skip update/delete of self; handled below
  if (act.verb is Activity.DELETE or act.verb is Activity.UPDATE) and (not act.actor or not act.object or act.actor.id isnt act.object.id)
    Step (->
      ActivityObject.getObject act.object.objectType, act.object.id, this
      return
    ), ((err, orig) ->
      throw err  if err
      Activity.postOf orig, this
      return
    ), (err, post) ->
      props = [
        "to"
        "cc"
        "bto"
        "bcc"
      ]
      if err
        callback err
      else unless post
        callback new Error("no original post")
      else
        props.forEach (prop) ->
          act[prop] = post[prop]  if post.hasOwnProperty(prop)
          return

        callback null
      return

  else if act.verb is Activity.FAVORITE or act.verb is Activity.UNFAVORITE or act.verb is Activity.LIKE or act.verb is Activity.DISLIKE
    Step (->
      ActivityObject.getObject act.object.objectType, act.object.id, this
      return
    ), ((err, orig) ->
      if err and err.name is "NoSuchThingError"
        setToFollowers act, callback
      else if err
        throw err
      else
        Activity.postOf orig, this
      return
    ), (err, post) ->
      props = [
        "to"
        "cc"
        "bto"
        "bcc"
      ]
      if err and err.name is "NoSuchThingError"
        setToFollowers act, callback
      else if err
        callback err
      else unless post
        setToFollowers act, callback
      else
        props.forEach (prop) ->
          act[prop] = post[prop]  if post.hasOwnProperty(prop)
          return

        callback null
      return

  else if act.object and act.object.objectType is ActivityObject.PERSON and (not act.actor or act.actor.id isnt act.object.id)
    
    # XXX: cc? bto?
    act.to = [act.object]
    if act.actor.followers and act.actor.followers.url
      act.cc = [
        id: act.actor.followers.url
        objectType: "collection"
      ]
    callback null
  else if act.object and act.object.objectType is ActivityObject.GROUP and act.verb isnt Activity.CREATE
    
    # XXX: cc? bto?
    act.to = [act.object]
    if act.actor.followers and act.actor.followers.url
      act.cc = [
        id: act.actor.followers.url
        objectType: "collection"
      ]
    callback null
  else if act.target and act.target.objectType is ActivityObject.GROUP and (act.verb is Activity.ADD or act.verb is Activity.REMOVE or act.verb is Activity.POST)
    
    # XXX: cc? bto?
    act.to = [act.target]
    callback null
  else if act.object and act.object.inReplyTo
    
    # Replies use same as original post
    Step (->
      ActivityObject.ensureObject act.object.inReplyTo, this
      return
    ), ((err, orig) ->
      throw err  if err
      Activity.postOf orig, this
      return
    ), (err, post) ->
      props = [
        "to"
        "cc"
        "bto"
        "bcc"
      ]
      if err
        callback err
      else unless post
        callback new Error("no original post")
      else
        props.forEach (prop) ->
          if post.hasOwnProperty(prop)
            act[prop] = []
            post[prop].forEach (addr) ->
              act[prop].push addr  if addr.id isnt act.actor.id
              return

          return

        act.to = []  unless act.to
        act.to.push post.actor
        callback null
      return

  else if act.actor and act.actor.objectType is ActivityObject.PERSON
    
    # Default is to user's followers
    setToFollowers act, callback
  else
    callback new Error("Can't ensure recipients.")
  return


# XXX: identical to save
Activity.beforeCreate = (props, callback) ->
  now = Stamper.stamp()
  props.updated = now
  props.published = now  unless props.published
  unless props.id
    props._uuid = IDMaker.makeID()
    props.id = ActivityObject.makeURI("activity", props._uuid)
    props.links = {}  unless _(props).has("links")
    props.links.self = href: URLMaker.makeURL("api/activity/" + props._uuid)
    props.url = URLMaker.makeURL(props.actor.preferredUsername + "/activity/" + props._uuid)  if _.has(props, "author") and _.isObject(props.author) and _.has(props.author, "preferredUsername") and _.isString(props.author.preferredUsername)
    
    # default verb
    props.verb = "post"  unless props.verb
  callback new Error("Activity has no actor"), null  unless props.actor
  callback new Error("Activity has no object"), null  unless props.object
  
  # This can be omitted
  props.location.objectType = ActivityObject.PLACE  if props.location and not props.location.objectType
  Step (->
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.ensureProperty props, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.ensureArray props, prop, group()
      return

    return
  ), ((err) ->
    throw err  if err
    props.content = Activity.makeContent(props)  unless props.content
    this null
    return
  ), ((err) ->
    throw err  if err
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.compressProperty props, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.compressArray props, prop, group()
      return

    return
  ), ((err) ->
    throw err  if err
    try
      Activity.validate props
      this null
    catch e
      this e
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props
    return

  return


# XXX: i18n, real real bad
Activity.makeContent = (props) ->
  content = undefined
  nameOf = (obj) ->
    if _.has(obj, "displayName")
      obj.displayName
    else unless _.has(obj, "objectType")
      "an object"
    else if [
      "a"
      "e"
      "i"
      "o"
      "u"
    ].indexOf(obj.objectType[0]) isnt -1
      "an " + obj.objectType
    else
      "a " + obj.objectType

  reprOf = (obj) ->
    name = sanitize(nameOf(obj)).escape()
    if _.has(obj, "url")
      "<a href='" + obj.url + "'>" + name + "</a>"
    else
      name

  pastOf = (verb) ->
    last = verb[verb.length - 1]
    irreg =
      at: "was at"
      build: "built"
      checkin: "checked into"
      find: "found"
      give: "gave"
      leave: "left"
      lose: "lost"
      "make-friend": "made a friend of"
      play: "played"
      read: "read"
      "remove-friend": "removed as a friend"
      "rsvp-maybe": "may attend"
      "rsvp-no": "will not attend"
      "rsvp-yes": "will attend"
      sell: "sold"
      send: "sent"
      "stop-following": "stopped following"
      submit: "submitted"
      tag: "tagged"
      win: "won"

    return irreg[verb]  if _.has(irreg, verb)
    switch last
      when "y"
        return verb.substr(0, verb.length - 1) + "ied"
      when "e"
        verb + "d"
      else
        verb + "ed"

  content = reprOf(props.actor) + " " + pastOf(props.verb or "post") + " " + reprOf(props.object)
  content = content + " in reply to " + reprOf(props.object.inReplyTo)  if _.has(props.object, "inReplyTo")
  content = content + " to " + reprOf(props.target)  if _.has(props.object, "target")
  content

Activity::beforeUpdate = (props, callback) ->
  now = Stamper.stamp()
  props.updated = now
  Step (->
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.compressProperty props, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.compressArray props, prop, group()
      return

    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props
    return

  return


# When save()'ing an activity, ensure the actor and object
# are persisted, then save them by reference.
Activity::beforeSave = (callback) ->
  now = Stamper.stamp()
  act = this
  act.updated = now
  unless act.id
    act._uuid = IDMaker.makeID()
    act.id = ActivityObject.makeURI("activity", act._uuid)
    act.links = {}  unless _(act).has("links")
    act.links.self = href: URLMaker.makeURL("api/activity/" + act._uuid)
    
    # FIXME: assumes person data was set and that it's a local actor
    act.url = URLMaker.makeURL(act.actor.preferredUsername + "/activity/" + act._uuid)
    act.published = now  unless act.published
  unless act.actor
    callback new Error("Activity has no actor")
    return
  unless act.object
    callback new Error("Activity has no object")
    return
  Step (->
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.ensureProperty act, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.ensureArray act, prop, group()
      return

    return
  ), ((err) ->
    throw err  if err
    act.content = Activity.makeContent(act)  unless act.content
    this null
    return
  ), ((err) ->
    throw err  if err
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.compressProperty act, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.compressArray act, prop, group()
      return

    return
  ), ((err) ->
    throw err  if err
    try
      Activity.validate act
      this null
    catch e
      this e
    return
  ), (err) ->
    if err
      callback err
    else
      callback null
    return

  return

Activity::toString = ->
  act = this
  unless _.has(act, "verb")
    "[activity]"
  else unless _.has(act, "id")
    "[" + act.verb + " activity]"
  else
    "[" + act.verb + " activity " + act.id + "]"


# When get()'ing an activity, also get the actor and the object,
# which are saved by reference
Activity::afterCreate = Activity::afterSave = Activity::afterUpdate = (callback) ->
  @expand callback
  return


# After getting, we check for old style or behaviour
Activity::afterGet = (callback) ->
  act = this
  Step (->
    Upgrader = require("../upgrader")
    Upgrader.upgradeActivity act, this
    return
  ), ((err) ->
    throw err  if err
    act.expand this
    return
  ), callback
  return

Activity::expand = (callback) ->
  act = this
  Step (->
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.expandProperty act, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.expandArray act, prop, group()
      return

    return
  ), ((err) ->
    throw err  if err
    act.object.expandFeeds this
    return
  ), (err) ->
    if err
      callback err
    else
      
      # Implied
      delete act.object.author  if act.verb is "post" and _(act.object).has("author")
      callback null
    return

  return

Activity::compress = (callback) ->
  act = this
  Step (->
    group = @group()
    _.each oprops, (prop) ->
      ActivityObject.compressProperty act, prop, group()
      return

    _.each aprops, (prop) ->
      ActivityObject.compressArray act, prop, group()
      return

    return
  ), (err) ->
    if err
      callback err
    else
      callback null
    return

  return

Activity::efface = (callback) ->
  keepers = [
    "actor"
    "object"
    "_uuid"
    "id"
    "published"
    "deleted"
    "updated"
  ]
  prop = undefined
  obj = this
  for prop of obj
    delete obj[prop]  if obj.hasOwnProperty(prop) and keepers.indexOf(prop) is -1
  now = Stamper.stamp()
  obj.deleted = obj.updated = now
  obj.save callback
  return


# Sanitize for going out over the wire
Activity::sanitize = (principal) ->
  act = this
  i = undefined
  j = undefined
  
  # Remove bcc and bto for non-user
  if not principal or (principal.id isnt @actor.id)
    delete @bcc  if @bcc
    delete @bto  if @bto
  
  # Remove properties with initial underscore
  _.each act, (value, key) ->
    delete act[key]  if key[0] is "_"
    return

  
  # Sanitize object properties
  _.each oprops, (prop) ->
    act[prop].sanitize()  if _.isObject(act[prop]) and _.isFunction(act[prop].sanitize)
    return

  
  # Sanitize array properties
  _.each aprops, (prop) ->
    if _.isArray(act[prop])
      _.each act[prop], (item) ->
        item.sanitize()  if _.isObject(item) and _.isFunction(item.sanitize)
        return

    return

  return


# Is the person argument a recipient of this activity?
# Checks to, cc, bto, bcc
# If the public is a recipient, always works (even null)
# Otherwise if the person is a direct recipient, true.
# Otherwise if the person is in a list that's a recipient, true.
# Otherwise if the actor's followers list is a recipient, and the
# person is a follower, true.
# Otherwise false.
Activity::checkRecipient = (person, callback) ->
  act = this
  i = undefined
  addrProps = [
    "to"
    "cc"
    "bto"
    "bcc"
    "_received"
  ]
  recipientsOfType = (type) ->
    i = undefined
    j = undefined
    addrs = undefined
    rot = []
    i = 0
    while i < addrProps.length
      if _(act).has(addrProps[i])
        addrs = act[addrProps[i]]
        j = 0
        while j < addrs.length
          rot.push addrs[j]  if addrs[j].objectType is type
          j++
      i++
    rot

  recipientWithID = (id) ->
    i = undefined
    j = undefined
    addrs = undefined
    i = 0
    while i < addrProps.length
      if _(act).has(addrProps[i])
        addrs = act[addrProps[i]]
        j = 0
        while j < addrs.length
          return addrs[j]  if addrs[j].id is id
          j++
      i++
    null

  isInLists = (person, callback) ->
    isInList = (list, callback) ->
      Step (->
        Collection.isList list, this
        return
      ), ((err, isList) ->
        throw err  if err
        unless isList
          callback null, false
        else
          list.getStream this
        return
      ), ((err, str) ->
        val = JSON.stringify(
          id: person.id
          objectType: person.objectType
        )
        throw err  if err
        str.indexOf val, this
        return
      ), (err, i) ->
        if err
          if err.name is "NotInStreamError"
            callback null, false
          else
            callback err, null
        else
          callback null, true
        return

      return

    Step (->
      i = undefined
      group = @group()
      lists = recipientsOfType(ActivityObject.COLLECTION)
      i = 0
      while i < lists.length
        isInList lists[i], group()
        i++
      return
    ), (err, inLists) ->
      if err
        callback err, null
      else
        callback null, inLists.some((b) ->
          b
        )
      return

    return

  isInGroups = (person, callback) ->
    isInGroup = (group, callback) ->
      Step (->
        Membership = require("./membership").Membership
        Membership.get Membership.id(person.id, group.id), this
        return
      ), (err, ship) ->
        if err and err.name is "NoSuchThingError"
          callback null, false
        else if err
          callback err, null
        else
          callback null, true
        return

      return

    Step (->
      i = undefined
      group = @group()
      groups = recipientsOfType(ActivityObject.GROUP)
      i = 0
      while i < groups.length
        isInGroup groups[i], group()
        i++
      return
    ), (err, inGroups) ->
      if err
        callback err, null
      else
        callback null, inGroups.some((b) ->
          b
        )
      return

    return

  isInFollowers = (person, callback) ->
    if not _(act).has("actor") or act.actor.objectType isnt ActivityObject.PERSON
      callback null, false
      return
    Step (->
      act.actor.followersURL this
      return
    ), ((err, url) ->
      throw err  if err
      if not url or not recipientWithID(url)
        callback null, false
      else
        Edge = require("./edge").Edge
        Edge.get Edge.id(person.id, act.actor.id), this
      return
    ), (err, edge) ->
      if err and err.name is "NoSuchThingError"
        callback null, false
      else unless err
        callback null, true
      else
        callback err, null
      return

    return

  persons = undefined
  Collection = require("./collection").Collection
  
  # Check for public
  pub = recipientWithID(Collection.PUBLIC)
  return callback(null, true)  if pub
  
  # if not public, then anonymous user can't be a recipient
  return callback(null, false)  unless person
  
  # Always OK for author to view their own activity
  return callback(null, true)  if _.has(act, "actor") and person.id is act.actor.id
  
  # Check for exact match
  persons = recipientsOfType("person")
  i = 0
  while i < persons.length
    return callback(null, true)  if persons[i].id is person.id
    i++
  
  # From here on, things go async
  Step (->
    isInLists person, @parallel()
    isInFollowers person, @parallel()
    isInGroups person, @parallel()
    return
  ), (err, inlists, infollowers, ingroups) ->
    if err
      callback err, null
    else
      callback null, inlists or infollowers or ingroups
    return

  return

Activity::isMajor = ->
  alwaysVerbs = [
    Activity.SHARE
    Activity.CHECKIN
  ]
  exceptVerbs = {}
  return true  if alwaysVerbs.indexOf(@verb) isnt -1
  exceptVerbs[Activity.POST] = [
    ActivityObject.COMMENT
    ActivityObject.COLLECTION
  ]
  exceptVerbs[Activity.CREATE] = [
    ActivityObject.COMMENT
    ActivityObject.COLLECTION
  ]
  return true  if exceptVerbs.hasOwnProperty(@verb) and exceptVerbs[@verb].indexOf(@object.objectType) is -1
  false


# XXX: we should probably just cache this somewhere
Activity.postOf = (activityObject, callback) ->
  verbSearch = (verb, object, cb) ->
    Step (->
      Activity.search
        verb: verb
        "object.id": object.id
      , this
      return
    ), (err, acts) ->
      matched = undefined
      if err
        cb err, null
      else if acts.length is 0
        cb null, null
      else
        
        # get first author match
        act = _.find(acts, (act) ->
          act.actor and object.author and act.actor.id is object.author.id
        )
        cb null, act
      return

    return

  Step (->
    verbSearch Activity.POST, activityObject, this
    return
  ), ((err, act) ->
    throw err  if err
    if act
      callback null, act
    else
      verbSearch Activity.CREATE, activityObject, this
    return
  ), (err, act) ->
    if err
      callback err, null
    else
      callback null, act
    return

  return

Activity::addReceived = (receiver, callback) ->
  act = this
  act._received = []  unless _.has(act, "_received")
  act._received.push
    id: receiver.id
    objectType: receiver.objectType

  Step (->
    act.save this
    return
  ), (err, updated) ->
    callback err
    return

  return

Activity::fire = (callback) ->
  activity = this
  User = require("./user").User
  Distributor = require("../distributor")
  Step (->
    
    # First, ensure recipients
    activity.ensureRecipients this
    return
  ), ((err) ->
    throw err  if err
    activity.apply null, this
    return
  ), ((err) ->
    throw err  if err
    
    # ...then persist...
    activity.save this
    return
  ), ((err, saved) ->
    throw err  if err
    activity = saved
    User.fromPerson activity.actor.id, this
    return
  ), ((err, user) ->
    throw err  if err
    unless user
      this null
    else
      user.addToOutbox activity, @parallel()
      user.addToInbox activity, @parallel()
    return
  ), ((err) ->
    d = undefined
    throw err  if err
    d = new Distributor(activity)
    d.distribute this
    return
  ), callback
  return

Activity.validate = (props) ->
  _.each oprops, (name) ->
    if _.has(props, name)
      unless _.isObject(props[name])
        throw new TypeError(name + " property is not an object.")
      else
        try
          ActivityObject.validate props[name]
        catch err
          
          # rethrow an error with more data
          throw new TypeError(name + ": " + err.message)
    return

  _.each aprops, (name) ->
    if _.has(props, name)
      unless _.isArray(props[name])
        throw new TypeError(name + " property is not an object.")
      else
        _.each props[name], (item, i) ->
          try
            ActivityObject.validate item
          catch err
            
            # rethrow an error with more data
            throw new TypeError(name + "[" + i + "]: " + err.message)
          return

    return

  return

Activity.verbs = [
  "accept"
  "access"
  "acknowledge"
  "add"
  "agree"
  "append"
  "approve"
  "archive"
  "assign"
  "at"
  "attach"
  "attend"
  "author"
  "authorize"
  "borrow"
  "build"
  "cancel"
  "close"
  "complete"
  "confirm"
  "consume"
  "checkin"
  "close"
  "create"
  "delete"
  "deliver"
  "deny"
  "disagree"
  "dislike"
  "experience"
  "favorite"
  "find"
  "follow"
  "give"
  "host"
  "ignore"
  "insert"
  "install"
  "interact"
  "invite"
  "join"
  "leave"
  "like"
  "listen"
  "lose"
  "make-friend"
  "open"
  "play"
  "post"
  "present"
  "purchase"
  "qualify"
  "read"
  "receive"
  "reject"
  "remove"
  "remove-friend"
  "replace"
  "request"
  "request-friend"
  "resolve"
  "return"
  "retract"
  "rsvp-maybe"
  "rsvp-no"
  "rsvp-yes"
  "satisfy"
  "save"
  "schedule"
  "search"
  "sell"
  "send"
  "share"
  "sponsor"
  "start"
  "stop-following"
  "submit"
  "tag"
  "terminate"
  "tie"
  "unfavorite"
  "unlike"
  "unsatisfy"
  "unsave"
  "unshare"
  "update"
  "use"
  "watch"
  "win"
]
i = 0
verb = undefined

# Constants-like members for activity verbs
i = 0
while i < Activity.verbs.length
  verb = Activity.verbs[i]
  Activity[verb.toUpperCase().replace("-", "_")] = verb
  i++
exports.Activity = Activity
exports.AppError = AppError
