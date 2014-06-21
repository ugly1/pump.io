# distributor.js
#
# Distributes a newly-received activity to recipients
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
path = require("path")
_ = require("underscore")
Step = require("step")
databank = require("databank")
OAuth = require("oauth-evanp").OAuth
Queue = require("jankyqueue")
cluster = require("cluster")
View = require("express").View
Firehose = require("./firehose")
Mailer = require("./mailer")
version = require("./version").version
URLMaker = require("./urlmaker").URLMaker
ActivityObject = require("./model/activityobject").ActivityObject
Collection = require("./model/collection").Collection
User = require("./model/user").User
Person = require("./model/person").Person
Edge = require("./model/edge").Edge
Credentials = require("./model/credentials").Credentials
NoSuchThingError = databank.NoSuchThingError
QUEUE_MAX = 25
MAX_CHUNK = 100
VIEW_ROOT = path.join(__dirname, "..", "public", "template")
Distributor = (activity) ->
  dtor = this
  dinfo = (obj, msg) ->
    Distributor.log.info obj, msg  if Distributor.log
    return

  ddebug = (obj, msg) ->
    Distributor.log.debug obj, msg  if Distributor.log
    return

  dwarn = (obj, msg) ->
    Distributor.log.warn obj, msg  if Distributor.log
    return

  derror = (err, obj, message) ->
    if obj
      obj.err = err
    else
      obj = err: err
    Distributor.log.error obj, message  if Distributor.log
    return

  delivered = {}
  expanded = false
  q = new Queue(QUEUE_MAX)
  toRecipient = (recipient, callback) ->
    switch recipient.objectType
      when ActivityObject.PERSON
        toPerson recipient, callback
      when ActivityObject.COLLECTION
        toCollection recipient, callback
      when ActivityObject.GROUP
        toGroup recipient, callback
      else
        dwarn
          recipient: recipient
        , "Unknown recipient type"
        callback null
        return

  toPerson = (person, callback) ->
    deliverToPerson = (person, callback) ->
      Step (->
        User.fromPerson person.id, this
        return
      ), (err, user) ->
        throw err  if err
        if user
          toUser user, callback
        else
          toRemotePerson person, 0, callback
        return

      return

    if _(delivered).has(person.id)
      
      # skip dupes
      callback null
      return
    delivered[person.id] = 1
    q.enqueue deliverToPerson, [person], callback
    return

  toUser = (user, callback) ->
    Step (->
      group = @group()
      dinfo
        nickname: user.nickname
        id: activity.id
      , "Delivering activity to local user."
      user.addToInbox activity, group()
      _.each Distributor.plugins, (plugin) ->
        cb = group()
        try
          plugin.distributeActivityToUser activity, user, cb  if _.isFunction(plugin.distributeActivityToUser)
        catch err
          cb err
        return

      return
    ), (err) ->
      callback err
      inboxUpdates user  unless err
      return

    return

  toRemotePerson = (person, retries, callback) ->
    endpoint = undefined
    cred = undefined
    dinfo
      person: person.id
      activity: activity.id
    , "Delivering activity to remote person."
    Step (->
      unless expanded
        activity.actor.expandFeeds this
        expanded = true
      else
        this null
      return
    ), ((err) ->
      throw err  if err
      person.getInbox this
      return
    ), ((err, result) ->
      throw err  if err
      endpoint = result
      Credentials.getFor activity.actor.id, endpoint, this
      return
    ), ((err, results) ->
      sanitized = undefined
      oa = undefined
      toSend = undefined
      throw err  if err
      cred = results
      
      # FIXME: use Activity.sanitize() instead
      sanitized = _(activity).clone()
      delete sanitized.bto  if _(sanitized).has("bto")
      delete sanitized.bcc  if _(sanitized).has("bcc")
      oa = new OAuth(null, null, cred.client_id, cred.client_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
        "User-Agent": "pump.io/" + version
      )
      toSend = JSON.stringify(sanitized)
      oa.post endpoint, null, null, toSend, "application/json", this
      return
    ), (err, body, resp) ->
      if err
        derror
          person: person.id
          activity: activity.id
          endpoint: endpoint
          err: err
        , "Error delivering activity to remote person."
        if retries is 0 and err.statusCode is 401 # expired key
          ddebug
            person: person.id
            activity: activity.id
          , "Expired-credentials error; retrying."
          cred.del (err) ->
            if err
              derror
                person: person.id
                activity: activity.id
                err: err
              , "Error deleting expired credentials for remote person."
              callback err
            else
              ddebug
                person: person.id
                activity: activity.id
              , "Correctly deleted credentials."
              toRemotePerson person, retries + 1, callback
            return

        else
          err.endpoint = endpoint
          callback err
      else
        dinfo
          person: person.id
          activity: activity.id
        , "Successful remote delivery."
        callback null
      return

    return

  toCollection = (collection, callback) ->
    actor = activity.actor
    if collection.id is Collection.PUBLIC
      dinfo
        activity: activity.id
      , "Delivering activity to public."
      toFollowers callback
      return
    Step (->
      cb = this
      if actor and actor.objectType is "person" and actor instanceof Person
        actor.followersURL cb
      else
        cb null, null
      return
    ), ((err, url) ->
      throw err  if err
      if url and url is collection.id
        dinfo
          activity: activity.id
        , "Delivering activity to followers."
        toFollowers callback
      else
        
        # Usually stored by reference, so get the full object
        ActivityObject.getObject collection.objectType, collection.id, this
      return
    ), ((err, result) ->
      if err and err.name is "NoSuchThingError"
        callback null
      else if err
        throw err
      else
        
        # XXX: assigning to function param
        collection = result
        Collection.isList collection, this
      return
    ), (err, isList) ->
      if err
        callback err
      else if isList and (collection.author.id is actor.id)
        dinfo
          list: collection.id
          activity: activity.id
        , "Delivering activity to a list."
        toList collection, callback
      else
        
        # XXX: log, bemoan
        callback null
      return

    return

  toList = (list, callback) ->
    Step (->
      list.getStream this
      return
    ), ((err, str) ->
      throw err  if err
      str.eachObject ((obj, callback) ->
        Step (->
          ActivityObject.getObject obj.objectType, obj.id, this
          return
        ), ((err, full) ->
          throw err  if err
          toRecipient full, this
          return
        ), persevere(callback)
        return
      ), this
      return
    ), callback
    return

  toFollowers = (callback) ->
    str = undefined
    Step (->
      User.fromPerson activity.actor.id, this
      return
    ), ((err, user) ->
      throw err  if err
      user.followersStream this
      return
    ), ((err, results) ->
      throw err  if err
      str = results
      str.count this
      return
    ), ((err, cnt) ->
      counter = 0
      cb = this
      throw err  if err
      str.each ((id, callback) ->
        counter++
        Step (->
          Person.get id, this
          return
        ), ((err, person) ->
          throw err  if err
          toPerson person, this
          return
        ), persevere(callback)
        return
      ), (err) ->
        dinfo
          expected: cnt
          actual: counter
          activity: activity.id
        , "Delivery metrics"
        cb err
        return

      return
    ), callback
    return

  toGroup = (recipient, callback) ->
    group = undefined
    
    # If it's already been delivered to this group (say, entered in both to and cc),
    # skip
    if _(delivered).has(recipient.id)
      callback null
      return
    Step (->
      
      # Usually stored by reference, so get the full object
      ActivityObject.getObject recipient.objectType, recipient.id, this
      return
    ), ((err, results) ->
      if err and err.name is "NoSuchThingError"
        callback null
      else if err
        throw err
      else
        group = results
        group.isLocal this
      return
    ), ((err, isLocal) ->
      if err
        throw err
      else if isLocal
        toLocalGroup group, this
      else
        toRemoteGroup group, 0, this
      return
    ), callback
    return

  toLocalGroup = (group, callback) ->
    Step (->
      group.getInboxStream @parallel()
      group.getMembersStream @parallel()
      return
    ), ((err, inbox, members) ->
      throw err  if err
      dinfo
        activity: activity.id
        group: group.id
      , "Delivering to group"
      delivered[group.id] = 1
      
      # Dispatch on group inbox feed foreign-ID format
      if group._foreign_id
        sendUpdate URLMaker.makeURL("/api/group/inbox",
          id: group.id
        )
      
      # Dispatch on group inbox feed
      sendUpdate URLMaker.makeURL("/api/group/" + group._uuid + "/inbox")
      
      # Add it to the stream inbox
      inbox.deliver activity.id, @parallel()
      
      # Send it out to each member
      members.each ((id, callback) ->
        Person.get id, (err, person) ->
          if err
            
            # Log and continue
            derror err,
              person: id
            , "Error getting group member"
            callback null
          else
            toPerson person, persevere(callback)
          return

        return
      ), @parallel()
      return
    ), callback
    return

  toRemoteGroup = (group, retries, callback) ->
    endpoint = undefined
    cred = undefined
    dinfo
      group: group.id
      activity: activity.id
    , "Delivering activity to remote group."
    Step (->
      unless expanded
        activity.actor.expandFeeds this
        expanded = true
      else
        this null
      return
    ), ((err) ->
      throw err  if err
      group.getInbox this
      return
    ), ((err, result) ->
      throw err  if err
      endpoint = result
      Credentials.getFor activity.actor.id, endpoint, this
      return
    ), ((err, results) ->
      sanitized = undefined
      oa = undefined
      toSend = undefined
      throw err  if err
      cred = results
      
      # FIXME: use Activity.sanitize() instead
      sanitized = _(activity).clone()
      delete sanitized.bto  if _(sanitized).has("bto")
      delete sanitized.bcc  if _(sanitized).has("bcc")
      oa = new OAuth(null, null, cred.client_id, cred.client_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
        "User-Agent": "pump.io/" + version
      )
      toSend = JSON.stringify(sanitized)
      oa.post endpoint, null, null, toSend, "application/json", this
      return
    ), (err, body, resp) ->
      if err
        if retries is 0 and err.statusCode is 401 # expired key
          cred.del (err) ->
            if err
              callback err
            else
              toRemoteGroup group, retries + 1, callback
            return

        else
          callback err
      else
        callback null
      return

    return

  
  # Send a message to the dispatch process
  # to note an update of this feed with this activity
  sendUpdate = (url) ->
    if cluster.isWorker
      ddebug
        url: url
        activity: activity.id
      , "Dispatching activity to URL"
      cluster.worker.send
        cmd: "update"
        url: url
        activity: activity

    return

  directRecipients = (act) ->
    props = [
      "to"
      "bto"
    ]
    recipients = []
    props.forEach (prop) ->
      recipients = recipients.concat(act[prop])  if _(act).has(prop) and _(act[prop]).isArray()
      return

    
    # XXX: ensure uniqueness
    recipients

  
  # Send updates for each applicable inbox feed
  # for this user. Covers main inbox, major/minor inbox,
  # direct inbox, and major/minor direct inbox
  inboxUpdates = (user) ->
    isDirectTo = (user) ->
      recipients = directRecipients(activity)
      _.any recipients, (item) ->
        item.id is user.profile.id and item.objectType is user.profile.objectType


    sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox")
    if activity.isMajor()
      sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/major")
    else
      sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/minor")
    if isDirectTo(user)
      sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/direct")
      if activity.isMajor()
        sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/direct/major")
      else
        sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/inbox/direct/minor")
    return

  
  # Send updates for each applicable outbox feed
  # for this user. Covers main feed, major/minor feed
  outboxUpdates = (user) ->
    sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/feed")
    if activity.isMajor()
      sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/feed/major")
    else
      sendUpdate URLMaker.makeURL("/api/user/" + user.nickname + "/feed/minor")
    return

  cache = {}
  notifyByEmail = (user, activity, callback) ->
    options =
      defaultEngine: "utml"
      root: VIEW_ROOT

    hview = View.compile("activity-notification-html", cache, "activity-notification-html", options)
    tview = View.compile("activity-notification-text", cache, "activity-notification-text", options)
    html = undefined
    text = undefined
    
    # XXX: More specific template based on verb and object objectType
    try
      html = hview.fn(
        principal: user.profile
        principalUser: user
        activity: activity
      )
      text = tview.fn(
        principal: user.profile
        principalUser: user
        activity: activity
      )
    catch err
      callback err, null
      return
    
    # XXX: Better subject
    Mailer.sendEmail
      to: user.email
      subject: "Activity notification"
      text: text
      attachment:
        data: html
        type: "text/html"
        alternative: true
    , callback
    return

  persevere = (callback) ->
    (err) ->
      args = (if (arguments_.length > 1) then Array::slice.call(arguments_, 1) else [])
      derror err, {}, "Persevering."  if err
      args.unshift null
      callback.apply null, args
      return

  dtor.distribute = (callback) ->
    actor = activity.actor
    recipients = activity.recipients()
    toRecipients = (cb) ->
      Step (->
        i = undefined
        group = @group()
        i = 0
        while i < recipients.length
          toRecipient recipients[i], persevere(group())
          i++
        return
      ), cb
      return

    toDispatch = (cb) ->
      Step (->
        User.fromPerson actor.id, this
        return
      ), ((err, user) ->
        throw err  if err
        if user
          
          # Send updates
          outboxUpdates user
          
          # Also inbox!
          inboxUpdates user
        this null
        return
      ), cb
      return

    toEmail = (cb) ->
      direct = directRecipients(activity)
      people = _.where(direct,
        objectType: ActivityObject.PERSON
      )
      Step (->
        group = @group()
        _.each people, (person) ->
          user = undefined
          callback = persevere(group())
          Step (->
            User.fromPerson person.id, this
            return
          ), ((err, results) ->
            throw err  if err
            user = results
            unless user
              callback null
              return
            unless user.email
              callback null
              return
            user.expand this
            return
          ), (err) ->
            if err
              callback err
            else
              notifyByEmail user, activity, callback
            return

          return

        return
      ), cb
      return

    toFirehose = (cb) ->
      recipients = activity.recipients()
      pub = _.where(recipients,
        id: Collection.PUBLIC
      )
      
      # If it's not a public activity, skip
      if not pub or pub.length is 0
        cb null
        return
      
      # If the actor is a local user, ping the firehose
      Step (->
        User.fromPerson actor.id, this
        return
      ), ((err, user) ->
        throw err  if err
        unless user
          this null
        else
          Firehose.ping activity, this
        return
      ), persevere(cb)
      return

    Step (->
      unless expanded
        actor.expandFeeds this
        expanded = true
      else
        this null
      return
    ), ((err) ->
      group = @group()
      throw err  if err
      toRecipients persevere(group())
      toDispatch persevere(group())
      toFirehose persevere(group())
      toEmail persevere(group())
      _.each Distributor.plugins, (plugin) ->
        try
          plugin.distributeActivity activity, persevere(group())  if _.isFunction(plugin.distributeActivity)
        catch err
          derror err,
            plugin: plugin
          , "Error with plugin"
        return

      return
    ), callback
    return

  
  # Surface this
  dtor.toLocalGroup = (group, callback) ->
    toLocalGroup group, callback
    return

  return

Distributor.plugins = []
module.exports = Distributor
