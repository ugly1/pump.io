# activityobject.js
#
# utility superclass for activity stuff
#
# Copyright 2012, E14N https://e14n.com/
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
_ = require("underscore-contrib")
Step = require("step")
NoSuchThingError = databank.NoSuchThingError
AlreadyExistsError = databank.AlreadyExistsError
DatabankObject = databank.DatabankObject
uuid = require("node-uuid")
URLMaker = require("../urlmaker").URLMaker
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
Stream = require("./stream").Stream
urlparse = require("url").parse
UnknownTypeError = (type) ->
  Error.captureStackTrace this, UnknownTypeError
  @name = "UnknownTypeError"
  @type = type
  @message = "Unknown type: " + type
  return

UnknownTypeError:: = new Error()
UnknownTypeError::constructor = UnknownTypeError
ActivityObject = (properties) ->
  ActivityObject.init this, properties
  return

ActivityObject.init = DatabankObject.init
ActivityObject:: = new DatabankObject({})
ActivityObject.beforeCreate = (props, callback) ->
  type = @type
  props.objectType = type  unless _.has(props, "objectType")
  now = Stamper.stamp()
  
  # Keep a timestamp for when we created something
  props._created = now
  Step (->
    User = require("./user").User
    unless _(props).getPath([
      "links"
      "self"
      "href"
    ])
      props._uuid = IDMaker.makeID()
      if props.id
        props._foreign_id = true
      else
        props.id = ActivityObject.makeURI(type, props._uuid)
      props.published = now  unless props.published
      props.updated = now  unless props.updated
      props.links = {}  unless _.has(props, "links")
      if props._foreign_id
        props.links.self = href: URLMaker.makeURL("api/" + type,
          id: props.id
        )
      else
        props.links.self = href: URLMaker.makeURL("api/" + type + "/" + props._uuid)
      _.each [
        "likes"
        "replies"
        "shares"
      ], (feed) ->
        unless _.has(props, feed)
          if props._foreign_id
            props[feed] = url: URLMaker.makeURL("api/" + type + "/" + feed,
              id: props.id
            )
          else
            props[feed] = url: URLMaker.makeURL("api/" + type + "/" + props._uuid + "/" + feed)
        return

      if not _.has(props, "url") and _.has(props, "author") and _.isObject(props.author)
        if _.has(props.author, "preferredUsername") and _.isString(props.author.preferredUsername)
          props.url = URLMaker.makeURL([
            props.author.preferredUsername
            type
            props._uuid
          ].join("/"))
          this null, null
        else
          User.fromPerson props.author.id, this
      else
        this null, null
    else
      _.each [
        "likes"
        "replies"
        "shares"
      ], (feed) ->
        
        # For non-new stuff, clear out volatile data
        ActivityObject.trimCollection props, feed
        return

      this null, null
    return
  ), ((err, user) ->
    throw err  if err
    if user
      props.url = URLMaker.makeURL([
        user.nickname
        type
        props._uuid
      ].join("/"))
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty props, "author", @parallel()
    ActivityObject.compressProperty props, "inReplyTo", @parallel()
    return
  ), ((err) ->
    throw err  if err
    ActivityObject.validate props
    this null
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props
    return

  return

ActivityObject::afterUpdate = ActivityObject::afterSave = (callback) ->
  @expand callback
  return

ActivityObject::afterGet = (callback) ->
  obj = this
  obj.inReplyTo = ActivityObject.toObject(obj.inReplyTo)  if obj.inReplyTo
  @expand callback
  return

ActivityObject::afterCreate = (callback) ->
  obj = this
  Step (->
    Stream.create
      name: "activityobject:replies:" + obj.id
    , @parallel()
    Stream.create
      name: "activityobject:shares:" + obj.id
    , @parallel()
    return
  ), ((err, replies, shares) ->
    throw err  if err
    obj.expand this
    return
  ), ((err) ->
    throw err  if err
    if not _(obj).has("inReplyTo") or not _(obj.inReplyTo).isObject()
      callback null
    else
      ActivityObject.ensureObject obj.inReplyTo, this
    return
  ), ((err, irt) ->
    throw err  if err
    irt.getRepliesStream this
    return
  ), ((err, replies) ->
    compressed = undefined
    throw err  if err
    compressed =
      id: obj.id
      objectType: obj.objectType

    replies.deliverObject compressed, this
    return
  ), callback
  return

ActivityObject::afterDel = ActivityObject::afterEfface = (callback) ->
  obj = this
  Step (->
    if not _(obj).has("inReplyTo") or not _(obj.inReplyTo).isObject()
      callback null
    else
      ActivityObject.getObject obj.inReplyTo.objectType, obj.inReplyTo.id, this
    return
  ), ((err, irt) ->
    throw err  if err
    irt.getRepliesStream this
    return
  ), ((err, replies) ->
    compressed = undefined
    throw err  if err
    compressed =
      id: obj.id
      objectType: obj.objectType

    replies.removeObject compressed, this
    return
  ), callback
  return

ActivityObject::expand = (callback) ->
  obj = this
  Step (->
    ActivityObject.expandProperty obj, "author", @parallel()
    ActivityObject.expandProperty obj, "inReplyTo", @parallel()
    return
  ), callback
  return

ActivityObject::beforeSave = (callback) ->
  obj = this
  now = Stamper.stamp()
  @updated = now
  ActivityObject.trimCollection this, "likes"
  ActivityObject.trimCollection this, "replies"
  ActivityObject.trimCollection this, "shares"
  
  # Save the author by reference; don't save the whole thing
  Step (->
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty obj, "author", this
    return
  ), ((err) ->
    throw err  if err
    ActivityObject.compressProperty obj, "inReplyTo", this
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, obj
    return

  return

ActivityObject::beforeUpdate = (props, callback) ->
  immutable = [
    "id"
    "objectType"
    "_uuid"
    "published"
  ]
  i = undefined
  prop = undefined
  i = 0
  while i < immutable.length
    prop = immutable[i]
    delete props[prop]  if props.hasOwnProperty(prop)
    i++
  ActivityObject.trimCollection props, "likes"
  ActivityObject.trimCollection props, "replies"
  ActivityObject.trimCollection props, "shares"
  now = Stamper.stamp()
  props.updated = now
  Step (->
    
    # Save the author by reference; don't save the whole thing
    ActivityObject.compressProperty props, "author", this
    return
  ), ((err) ->
    throw err  if err
    ActivityObject.compressProperty props, "inReplyTo", this
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, props
    return

  return


# For now, we make HTTP URIs. Maybe someday we'll
# do something else. I like HTTP URIs, though.
ActivityObject.makeURI = (type, uuid) ->
  URLMaker.makeURL "api/" + type + "/" + uuid

ActivityObject.toClass = (type) ->
  module = undefined
  className = undefined
  return require("./other").Other  if not type or ActivityObject.objectTypes.indexOf(type.toLowerCase()) is -1
  module = require("./" + type)
  className = type.substring(0, 1).toUpperCase() + type.substring(1, type.length).toLowerCase()
  module[className]

ActivityObject.toObject = (props, defaultType) ->
  Cls = undefined
  type = undefined
  
  # Try rational fallbacks
  type = props.objectType or defaultType or ActivityObject.NOTE
  Cls = ActivityObject.toClass(type)
  new Cls(props)

ActivityObject.getObject = (type, id, callback) ->
  Cls = undefined
  Cls = ActivityObject.toClass(type)
  Cls.get id, callback
  return

ActivityObject.createObject = (obj, callback) ->
  Cls = undefined
  type = obj.objectType
  Cls = ActivityObject.toClass(type)
  Cls.create obj, callback
  return

ActivityObject.ensureObject = (obj, callback) ->
  type = obj.objectType
  Cls = undefined
  id = obj.id
  url = obj.url
  tryDiscover = (obj, cb) ->
    Step (->
      ActivityObject.discover obj, this
      return
    ), (err, remote) ->
      if err
        tryCreate obj, cb
      else
        tryCreate remote, cb
      return

    return

  tryCreate = (obj, cb) ->
    Step (->
      Cls.create obj, this
      return
    ), (err, result) ->
      if err and err.name is "AlreadyExistsError"
        ActivityObject.ensureObject obj, cb
      else if err
        cb err, null
      else
        cb null, result
      return

    return

  softGet = (Cls, id, cb) ->
    Step (->
      Cls.get id, this
      return
    ), (err, result) ->
      if err and err.name is "NoSuchThingError"
        cb null, null
      else unless err
        cb null, result
      else
        cb err, null
      return

    return

  findOne = (Cls, criteria, cb) ->
    Step (->
      Cls.search criteria, this
      return
    ), (err, results) ->
      throw err  if err
      if not results or results.length is 0
        cb null, null
      else
        cb null, results[0]
      return

    return

  
  # Since this is a major entry point, check our arguments
  if not _.isString(id) and not _.isUndefined(id)
    callback new TypeError("ID is not a string: " + id), null
    return
  if not _.isString(url) and not _.isUndefined(url)
    callback new TypeError("URL is not a string: " + url), null
    return
  unless _.isString(type)
    callback new TypeError("Type is not a string: " + type), null
    return
  Cls = ActivityObject.toClass(type)
  Step (->
    if _.isString(id)
      softGet Cls, id, this
    else if _.isString(url)
      
      # XXX: we could use other fields here to guide search
      findOne Cls,
        url: url
      , this
    else
      
      # XXX: without a unique identifier, just punt
      this null, null
    return
  ), (err, result) ->
    delta = undefined
    throw err  if err
    unless result
      unless ActivityObject.isLocal(obj)
        tryDiscover obj, callback
      else
        
        # XXX: Log this; it's unusual
        tryCreate obj, callback
    else if not ActivityObject.isLocal(obj) and not ActivityObject.isReference(obj) and (ActivityObject.isReference(result) or obj.updated > result.updated)
      delta = ActivityObject.delta(result, obj)
      result.update delta, (err) ->
        if err
          callback err, null
        else
          callback null, result
        return

    else
      callback null, result
    return

  return

ActivityObject.isReference = (value) ->
  refKeys = [
    "id"
    "objectType"
    "updated"
    "published"
    "_uuid"
    "_created"
    "links"
  ]
  nonRef = _.difference(_.keys(value), refKeys)
  nonRef.length is 0

ActivityObject.delta = (current, proposed) ->
  dupe = _.clone(proposed)
  _.each dupe, (value, key) ->
    
    # XXX: accept updates of object data
    if _.isObject(value) and _.isEqual(current[key], value)
      delete dupe[key]
    else delete dupe[key]  if current[key] is value
    return

  dupe

ActivityObject.ensureProperty = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _.isObject(obj[name])
    callback new TypeError(name + " property of " + obj + " is not an object")
    return
  Step (->
    ActivityObject.ensureObject obj[name], this
    return
  ), (err, sub) ->
    if err
      callback err
    else
      obj[name] = sub
      callback null
    return

  return

ActivityObject.compressProperty = (obj, name, callback) ->
  Step (->
    ActivityObject.ensureProperty obj, name, this
    return
  ), (err) ->
    Cls = undefined
    sub = undefined
    if err
      callback err
    else unless _(obj).has(name)
      callback null
    else
      sub = obj[name]
      Cls = ActivityObject.toClass(sub.objectType)
      unless Cls
        callback new UnknownTypeError(sub.objectType)
      else
        obj[name] = new Cls(
          id: sub.id
          objectType: sub.objectType
        )
        callback null
    return

  return

ActivityObject.ensureArray = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _(obj[name]).isArray()
    callback new Error("Property '" + name + "' of object '" + obj.id + "' is not an array")
    return
  Step (->
    i = undefined
    group = @group()
    i = 0
    while i < obj[name].length
      ActivityObject.ensureObject obj[name][i], group()
      i++
    return
  ), (err, subs) ->
    Cls = undefined
    if err
      callback err
    else
      obj[name] = subs
      callback null
    return

  return

ActivityObject.compressArray = (obj, name, callback) ->
  
  # Easy enough!
  Step (->
    ActivityObject.ensureArray obj, name, this
    return
  ), (err) ->
    Cls = undefined
    subs = undefined
    if err
      callback err
    else unless obj[name]
      callback null
    else
      subs = obj[name]
      obj[name] = new Array(subs.length)
      i = 0
      while i < subs.length
        Cls = ActivityObject.toClass(subs[i].objectType)
        unless Cls
          callback new UnknownTypeError(subs[i].objectType)
          return
        else
          obj[name][i] = new Cls(
            id: subs[i].id
            objectType: subs[i].objectType
          )
        i++
      callback null
    return

  return

ActivityObject.expandProperty = (obj, name, callback) ->
  ref = undefined
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  ref = obj[name]
  unless _.isObject(ref)
    callback new Error(obj.toString() + ": " + name + " property is not an object")
    return
  unless _.isString(ref.id)
    callback new Error(obj.toString() + ": " + name + " property has no unique identifier")
    return
  unless _.isString(ref.objectType)
    callback new Error(obj.toString() + ": " + name + " property has no object type")
    return
  Step (->
    ActivityObject.getObject ref.objectType, ref.id, this
    return
  ), (err, sub) ->
    if err
      callback err
    else
      obj[name] = sub
      callback null
    return

  return

ActivityObject.expandArray = (obj, name, callback) ->
  
  # Easy enough!
  unless _(obj).has(name)
    callback null
    return
  unless _(obj[name]).isArray()
    callback new Error("Property '" + name + "' of object '" + obj.id + "' is not an array")
    return
  Step (->
    i = undefined
    group = @group()
    i = 0
    while i < obj[name].length
      ActivityObject.getObject obj[name][i].objectType, obj[name][i].id, group()
      i++
    return
  ), (err, subs) ->
    Cls = undefined
    if err
      callback err
    else
      obj[name] = subs
      callback null
    return

  return

ActivityObject::favoritedBy = (id, callback) ->
  obj = this
  Step (->
    obj.getFavoritersStream this
    return
  ), ((err, stream) ->
    throw err  if err
    stream.deliver id, this
    return
  ), (err) ->
    if err
      callback err
    else
      callback null
    return

  return

ActivityObject::unfavoritedBy = (id, callback) ->
  obj = this
  Step (->
    obj.getFavoritersStream this
    return
  ), ((err, stream) ->
    throw err  if err
    stream.remove id, this
    return
  ), (err) ->
    if err
      callback err
    else
      callback null
    return

  return

ActivityObject.getObjectStream = (className, streamName, start, end, callback) ->
  ids = undefined
  Cls = ActivityObject.toClass(className)
  Step (->
    Stream.get streamName, this
    return
  ), ((err, stream) ->
    throw err  if err
    stream.getIDs start, end, this
    return
  ), ((err, results) ->
    throw err  if err
    ids = results
    if ids.length is 0
      callback null, []
    else
      Cls.readAll ids, this
    return
  ), (err, map) ->
    i = undefined
    objects = []
    if err
      if err.name is "NoSuchThingError"
        callback null, []
      else
        callback err, null
    else
      objects = new Array(ids.length)
      
      # Try to get it in the right order
      i = 0
      while i < ids.length
        objects[i] = map[ids[i]]
        i++
      callback null, objects
    return

  return

ActivityObject::getFavoritersStream = (callback) ->
  obj = this
  name = "favoriters:" + obj.id
  Step (->
    Stream.get name, this
    return
  ), ((err, stream) ->
    if err and err.name is "NoSuchThingError"
      Stream.create
        name: name
      , this
    else if err
      throw err
    else
      this null, stream
    return
  ), callback
  return

ActivityObject::getFavoriters = (start, end, callback) ->
  ActivityObject.getObjectStream "person", "favoriters:" + @id, start, end, callback
  return

ActivityObject::favoritersCount = (callback) ->
  Stream.count "favoriters:" + @id, (err, count) ->
    if err and err.name is "NoSuchThingError"
      callback null, 0
    else if err
      callback err, null
    else
      callback null, count
    return

  return

ActivityObject::expandFeeds = (callback) ->
  obj = this
  Step (->
    obj.repliesCount @parallel()
    obj.favoritersCount @parallel()
    obj.sharesCount @parallel()
    return
  ), (err, repliesCount, favoritersCount, sharesCount) ->
    if err
      callback err
    else
      obj.replies.totalItems = repliesCount  if obj.replies
      obj.likes.totalItems = favoritersCount  if obj.likes
      obj.shares.totalItems = sharesCount  if obj.shares
      callback null
    return

  return

ActivityObject::getSharesStream = (callback) ->
  obj = this
  name = "activityobject:shares:" + obj.id
  Stream.get name, callback
  return

ActivityObject::getRepliesStream = (callback) ->
  obj = this
  name = "activityobject:replies:" + obj.id
  Stream.get name, callback
  return

ActivityObject::getReplies = (start, end, callback) ->
  obj = this
  full = []
  Step (->
    obj.getRepliesStream this
    return
  ), ((err, stream) ->
    throw err  if err
    stream.getObjects start, end, this
    return
  ), ((err, compressed) ->
    i = undefined
    group = @group()
    throw err  if err
    i = 0
    while i < compressed.length
      ActivityObject.getObject compressed[i].objectType, compressed[i].id, group()
      i++
    return
  ), ((err, results) ->
    i = undefined
    group = @group()
    throw err  if err
    full = results
    i = 0
    while i < full.length
      full[i].expandFeeds group()
      i++
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, full
    return

  return

ActivityObject::sharesCount = (callback) ->
  obj = this
  Step (->
    obj.getSharesStream this
    return
  ), ((err, str) ->
    throw err  if err
    str.count this
    return
  ), callback
  return

ActivityObject::repliesCount = (callback) ->
  name = "activityobject:replies:" + @id
  Stream.count name, (err, count) ->
    if err and err.name is "NoSuchThingError"
      callback null, 0
    else if err
      callback err, null
    else
      callback null, count
    return

  return

ActivityObject::keepers = ->
  [
    "id"
    "objectType"
    "author"
    "published"
    "updated"
    "_uuid"
    "inReplyTo"
  ]


# Default hooks for efface()
ActivityObject::beforeEfface = (callback) ->
  callback null
  return

ActivityObject::efface = (callback) ->
  keepers = @keepers()
  obj = this
  Step (->
    obj.beforeEfface this
    return
  ), ((err) ->
    throw err  if err
    _.each obj, (value, key) ->
      delete obj[key]  unless _.contains(keepers, key)
      return

    now = Stamper.stamp()
    obj.deleted = obj.updated = now
    obj.save this
    return
  ), ((err) ->
    obj.afterEfface this
    return
  ), callback
  return

ActivityObject.canonicalID = (id) ->
  return "acct:" + id  if id.indexOf("@") isnt -1 and id.substr(0, 5) isnt "acct:"
  id

ActivityObject.sameID = (id1, id2) ->
  ActivityObject.canonicalID(id1) is ActivityObject.canonicalID(id2)


# Clean up stuff that shouldn't go through to the outside world.
# By convention, we start these properties with a "_".
ActivityObject::sanitize = ->
  obj = this
  objects = [
    "author"
    "location"
    "inReplyTo"
  ]
  arrays = [
    "attachments"
    "tags"
  ]
  
  # Sanitize stuff starting with _
  _.each obj, (value, key) ->
    delete obj[key]  if key[0] is "_"
    return

  
  # Sanitize object properties
  _.each objects, (prop) ->
    obj[prop].sanitize()  if _.isObject(obj[prop]) and _.isFunction(obj[prop].sanitize)
    return

  
  # Sanitize array properties
  _.each arrays, (prop) ->
    if _.isArray(obj[prop])
      _.each obj[prop], (item) ->
        item.sanitize()  if _.isObject(item) and _.isFunction(item.sanitize)
        return

    return

  return

ActivityObject.trimCollection = (obj, prop) ->
  if _(obj).has(prop)
    if _(obj[prop]).isObject()
      delete obj[prop].totalItems

      delete obj[prop].items

      delete obj[prop].pump_io
    else
      delete obj[prop]
  return

ActivityObject::isFollowable = ->
  obj = this
  followableTypes = [ActivityObject.PERSON]
  if _.contains(followableTypes, obj.objectType)
    true
  else if _.has(obj, "links") and _.has(obj.links, "activity-outbox")
    true
  else
    false

ActivityObject.validate = (props) ->
  dateprops = [
    "published"
    "updated"
  ]
  uriarrayprops = [
    "downstreamDuplicates"
    "upstreamDuplicates"
  ]
  htmlprops = [
    "content"
    "summary"
  ]
  oprops = [
    "inReplyTo"
    "author"
  ]
  
  # XXX: validate that id is a really-truly URI
  throw new TypeError("no id in activity object")  unless _.isString(props.id)
  
  # XXX: validate that objectType is an URI or in our whitelist
  throw new TypeError("no objectType in activity object")  unless _.isString(props.objectType)
  
  # XXX: validate that displayName is not HTML
  throw new TypeError("displayName property is not a string")  if _.has(props, "displayName") and not _.isString(props.displayName)
  
  # XXX: validate that url is an URL
  throw new TypeError("url property is not a string")  if _.has(props, "url") and not _.isString(props.url)
  _.each oprops, (name) ->
    if _.has(props, name)
      unless _.isObject(props[name])
        throw new TypeError(name + " property is not an activity object")
      else
        ActivityObject.validate props[name]
    return

  
  # Validate attachments
  if _.has(props, "attachments")
    throw new TypeError("attachments is not an array")  unless _.isArray(props.attachments)
    _.each props.attachments, (attachment) ->
      throw new TypeError("attachment is not an object")  unless _.isObject(attachment)
      ActivityObject.validate attachment
      return

  _.each uriarrayprops, (uriarrayprop) ->
    if _.has(props, uriarrayprop)
      throw new TypeError(uriarrayprop + " is not an array")  unless _.isArray(props[uriarrayprop])
      throw new TypeError(uriarrayprop + " member is not a string")  if _.some(props[uriarrayprop], (str) ->
        not _.isString(str)
      )
    return

  
  # XXX: validate that duplicates are URIs
  if _.has(props, "image")
    throw new TypeError("image property is not an object")  unless _.isObject(props.image)
    ActivityObject.validateMediaLink props.image
  _.each dateprops, (dateprop) ->
    
    # XXX: validate the date
    throw new TypeError(dateprop + " property is not a string")  unless _.isString(props[dateprop])  if _.has(props, dateprop)
    return

  _.each htmlprops, (name) ->
    
    # XXX: validate HTML
    throw new TypeError(name + " property is not a string")  if _.has(props, name) and not _.isString(props[name])
    return

  return

ActivityObject.validateMediaLink = (props) ->
  np = [
    "width"
    "height"
    "duration"
  ]
  throw new TypeError("url property of media link is not a string")  unless _.isString(props.url)
  _.each np, (nprop) ->
    throw new TypeError(nprop + " property of media link is not a number")  if _.has(props, nprop) and not _.isNumber(props[nprop])
    return

  return

ActivityObject.objectTypes = [
  "alert"
  "application"
  "article"
  "audio"
  "badge"
  "binary"
  "bookmark"
  "collection"
  "comment"
  "device"
  "event"
  "file"
  "game"
  "group"
  "image"
  "issue"
  "job"
  "note"
  "offer"
  "organization"
  "page"
  "person"
  "place"
  "process"
  "product"
  "question"
  "review"
  "service"
  "task"
  "video"
]
objectType = undefined
i = undefined

# Constants-like members for activity object types
i = 0
while i < ActivityObject.objectTypes.length
  objectType = ActivityObject.objectTypes[i]
  ActivityObject[objectType.toUpperCase().replace("-", "_")] = objectType
  i++
ActivityObject.baseSchema =
  pkey: "id"
  fields: [
    "_created"
    "_uuid"
    "attachments"
    "author"
    "content"
    "displayName"
    "downstreamDuplicates"
    "id"
    "image"
    "inReplyTo"
    "likes"
    "links"
    "objectType"
    "published"
    "replies"
    "shares"
    "summary"
    "updated"
    "upstreamDuplicates"
    "url"
  ]
  indices: [
    "_uuid"
    "url"
  ]

ActivityObject.subSchema = (withoutFields, addFields, addIndices) ->
  base = ActivityObject.baseSchema
  schema =
    pkey: base.pkey
    indices: _.clone(base.indices)

  if withoutFields
    schema.fields = _.difference(base.fields, withoutFields)
  else
    schema.fields = base.fields
  schema.fields = _.union(schema.fields, addFields)  if addFields
  schema.indices = _.union(schema.indices, addIndices)  if addIndices
  schema


# We skip these for discovery
ActivityObject.isDomainToSkip = (hostname) ->
  examples = [
    "example.com"
    "example.org"
    "example.net"
  ]
  namespaces = ["activityschema.org"]
  tlds = [
    "example"
    "invalid"
  ]
  parts = undefined
  return true  if _.contains(examples, hostname.toLowerCase())
  return true  if _.contains(namespaces, hostname.toLowerCase())
  parts = hostname.split(".")
  return true  if _.contains(tlds, parts[parts.length - 1])
  false

ActivityObject.isLocal = (obj) ->
  obj.id and (ActivityObject.domainOf(obj.id) is URLMaker.hostname)

ActivityObject.domainOf = (id) ->
  proto = ActivityObject.protocolOf(id)
  parts = undefined
  domain = undefined
  switch proto
    when "http", "https"
      parts = urlparse(id)
      domain = parts.hostname
    when "acct", "mailto"
      parts = id.split("@")
      domain = parts[1]  if parts.length > 1
    when "tag"
      parts = id.match(/tag:(.*?),/)
      domain = parts[0]  if parts
    else
  domain

ActivityObject.protocolOf = (id) ->
  return null  unless id
  return null  if id.indexOf(":") is -1
  id.substr 0, id.indexOf(":")

ActivityObject.mergeLinks = (jrd, obj) ->
  feeds = [
    "followers"
    "following"
    "links"
    "favorites"
    "likes"
    "replies"
    "shares"
  ]
  _.each jrd.links, (link) ->
    rel = link.rel
    if _.contains(feeds, rel)
      obj[rel] = url: link.href
    else
      obj.links = {}  unless obj.links
      obj.links[rel] = href: link.href
    return

  return

ActivityObject.getRemoteObject = (url, retries, callback) ->
  Host = require("./host").Host
  host = undefined
  unless callback
    callback = retries
    retries = 0
  Step (->
    hostname = urlparse(url).hostname
    Host.ensureHost hostname, this
    return
  ), ((err, results) ->
    throw err  if err
    host = results
    host.getOAuth this
    return
  ), ((err, oa) ->
    throw err  if err
    oa.get url, null, null, this
    return
  ), ((err, body, resp) ->
    parsed = undefined
    Credentials = undefined
    if err
      if err.statusCode is 401 and retries is 0
        
        # There's an error with the host key. Delete and retry
        Credentials = require("./credentials").Credentials
        Credentials.getForHost URLMaker.hostname, host, (err, cred) ->
          throw err  if err
          cred.del (err) ->
            throw err  if err
            ActivityObject.getRemoteObject url, retries + 1, callback
            return

          return

      else
        throw err
    else
      throw new Error("Bad content type: " + resp.headers["content-type"])  if not resp.headers["content-type"] or resp.headers["content-type"].substr(0, 16) isnt "application/json"
      parsed = JSON.parse(body)
      this null, parsed
    return
  ), callback
  return

ActivityObject.discover = (obj, callback) ->
  proto = ActivityObject.protocolOf(obj.id)
  wf = undefined
  if not _.contains([
    "http"
    "https"
    "acct"
  ], proto) or ActivityObject.isDomainToSkip(ActivityObject.domainOf(obj.id))
    callback new Error("Can't do discovery on " + obj.id), null
    return
  wf = require("webfinger")
  Step (->
    wf.webfinger obj.id, this
    return
  ), ((err, jrd) ->
    selfies = undefined
    throw err  if err
    ActivityObject.mergeLinks jrd, obj
    selfies = _.filter(jrd.links, (link) ->
      link.rel is "self"
    )
    if selfies.length > 0
      ActivityObject.getRemoteObject selfies[0].href, this
    else
      this null, obj
    return
  ), callback
  return

exports.ActivityObject = ActivityObject
exports.UnknownTypeError = UnknownTypeError
