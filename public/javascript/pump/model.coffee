# pump/model.js
#
# Backbone models for the pump.io client UI
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
  
  # Override backbone sync to use OAuth
  Backbone.sync = (method, model, options) ->
    getValue = (object, prop) ->
      if _.isFunction(object[prop])
        object[prop]()
      else if object[prop]
        object[prop]
      else if object.has and object.has(prop)
        object.get prop
      else
        null

    methodMap =
      create: "POST"
      update: "PUT"
      delete: "DELETE"
      read: "GET"

    type = methodMap[method]
    
    # Default options, unless specified.
    options = options or {}
    
    # Default JSON-request options.
    params =
      type: type
      dataType: "json"

    
    # Ensure that we have a URL.
    unless options.url
      if type is "POST"
        params.url = getValue(model.collection, "url")
      else if model.proxyURL
        params.url = model.proxyURL
      else
        params.url = getValue(model, "url")
      throw new Error("No URL")  if not params.url or not _.isString(params.url)
    
    # Ensure that we have the appropriate request data.
    if not options.data and model and (method is "create" or method is "update")
      params.contentType = "application/json"
      params.data = JSON.stringify(model.toJSON())
    
    # Don't process data on a non-GET request.
    params.processData = false  if params.type isnt "GET" and not Backbone.emulateJSON
    params = _.extend(params, options)
    Pump.ajax params
    null

  
  # A little bit of model sugar
  # Create Model attributes for our object-y things
  Pump.Model = Backbone.Model.extend(
    activityObjects: []
    activityObjectBags: []
    activityObjectStreams: []
    activityStreams: []
    peopleStreams: []
    listStreams: []
    people: []
    initialize: ->
      obj = this
      neverNew = -> # XXX: neverNude
        false

      initer = (obj, model) ->
        (name) ->
          raw = obj.get(name)
          if raw
            
            # use unique for cached stuff
            if model.unique
              obj[name] = model.unique(raw)
            else
              obj[name] = new model(raw)
            obj[name].isNew = neverNew
          obj.on "change:" + name, (changed) ->
            raw = obj.get(name)
            if obj[name] and obj[name].set
              obj[name].set raw
            else if raw
              if model.unique
                obj[name] = model.unique(raw)
              else
                obj[name] = new model(raw)
              obj[name].isNew = neverNew
            return

          return

      _.each obj.activityObjects, initer(obj, Pump.ActivityObject)
      _.each obj.activityObjectBags, initer(obj, Pump.ActivityObjectBag)
      _.each obj.activityObjectStreams, initer(obj, Pump.ActivityObjectStream)
      _.each obj.activityStreams, initer(obj, Pump.ActivityStream)
      _.each obj.peopleStreams, initer(obj, Pump.PeopleStream)
      _.each obj.listStreams, initer(obj, Pump.ListStream)
      _.each obj.people, initer(obj, Pump.Person)
      return

    toJSONRef: ->
      obj = this
      id: obj.get(obj.idAttribute)
      objectType: obj.getObjectType()

    getObjectType: ->
      obj = this
      obj.get "objectType"

    toJSON: (seen) ->
      obj = this
      id = obj.get(obj.idAttribute)
      json = _.clone(obj.attributes)
      jsoner = (name) ->
        json[name] = obj[name].toJSON(seenNow)  if _.has(obj, name)
        return

      seenNow = undefined
      if seen and id and _.contains(seen, id)
        json = obj.toJSONRef()
      else
        if seen
          seenNow = seen.slice(0)
        else
          seenNow = []
        seenNow.push id  if id
        _.each obj.activityObjects, jsoner
        _.each obj.activityObjectBags, jsoner
        _.each obj.activityObjectStreams, jsoner
        _.each obj.activityStreams, jsoner
        _.each obj.peopleStreams, jsoner
        _.each obj.listStreams, jsoner
        _.each obj.people, jsoner
      json

    set: (props) ->
      model = this
      Pump.debug "Setting property 'items' for model " + model.id  if _.has(props, "items")
      Backbone.Model::set.apply model, arguments_

    merge: (props) ->
      model = this
      complicated = model.complicated()
      Pump.debug "Merging " + model.id + " with " + (props.id or props.url or props.nickname or "unknown")
      _.each props, (value, key) ->
        unless model.has(key)
          model.set key, value
        else if _.contains(complicated, key) and model[key] and _.isFunction(model[key].merge)
          model[key].merge value
        else

        return

      return

    
    # XXX: resolve non-complicated stuff
    complicated: ->
      attrs = [
        "activityObjects"
        "activityObjectBags"
        "activityObjectStreams"
        "activityStreams"
        "peopleStreams"
        "listStreams"
        "people"
      ]
      names = []
      model = this
      _.each attrs, (attr) ->
        names = names.concat(model[attr])  if _.isArray(model[attr])
        return

      names
  ,
    cache: {}
    keyAttr: "id" # works for activities and activityobjects
    unique: (props) ->
      inst = undefined
      cls = this
      key = props[cls.keyAttr]
      if key and _.has(cls.cache, key)
        inst = cls.cache[key]
        
        # Check the updated flag
        inst.merge props
      else
        inst = new cls(props)
        cls.cache[key] = inst  if key
        inst.on "change:" + cls.keyAttr, (model, key) ->
          oldKey = model.previous(cls.keyAttr)
          delete cls.cache[oldKey]  if oldKey and _.has(cls.cache, oldKey)
          cls.cache[key] = inst
          return

      inst

    clearCache: ->
      @cache = {}
      return
  )
  
  # An array of objects, usually the "items" in a stream
  Pump.Items = Backbone.Collection.extend(
    constructor: (models, options) ->
      items = this
      
      # Use unique() to get unique items
      models = _.map(models, (raw) ->
        items.model.unique raw
      )
      Backbone.Collection.apply this, [
        models
        options
      ]
      return

    url: ->
      items = this
      items.stream.url()

    toJSON: (seen) ->
      items = this
      items.map (item) ->
        item.toJSON seen


    merge: (props) ->
      items = this
      unique = undefined
      if _.isArray(props)
        Pump.debug "Merging items of " + items.url() + " of length " + items.length + " with array of length " + props.length
        unique = props.map((item) ->
          items.model.unique item
        )
        items.add unique
      else
        Pump.debug "Non-array passed to items.merge()"
      return
  )
  
  # A stream of objects. It maps to the ActivityStreams collection
  # representation -- some wrap-up data like url and totalItems, plus an array of items.
  Pump.Stream = Pump.Model.extend(
    people: ["author"]
    itemsClass: Pump.Items
    idAttribute: "url"
    getObjectType: ->
      obj = this
      "collection"

    initialize: ->
      str = this
      items = str.get("items")
      Pump.Model::initialize.apply str
      
      # We should always have items
      if _.isArray(items)
        str.items = new str.itemsClass(items)
      else
        str.items = new str.itemsClass([])
      str.items.stream = str
      str.on "change:items", (newStr, items) ->
        str = this
        Pump.debug "Resetting items of " + str.url() + " to new array of length " + items.length
        str.items.reset items
        return

      return

    url: ->
      str = this
      if str.has("pump_io") and _.has(str.get("pump_io"), "proxyURL")
        str.get("pump_io").proxyURL
      else
        str.get "url"

    nextLink: (count) ->
      str = this
      url = undefined
      item = undefined
      count = 20  if _.isUndefined(count)
      if str.has("links") and _.has(str.get("links"), "next")
        url = str.get("links").next.href
      else if str.items and str.items.length > 0
        item = str.items.at(str.items.length - 1)
        url = str.url() + "?before=" + item.id + "&type=" + item.get("objectType")
      else
        url = null
      url = url + "&count=" + count  if url and count isnt 20
      url

    prevLink: (count) ->
      str = this
      url = undefined
      item = undefined
      count = 20  if _.isUndefined(count)
      if str.has("links") and _.has(str.get("links"), "prev")
        url = str.get("links").prev.href
      else if str.items and str.items.length > 0
        item = str.items.at(0)
        url = str.url() + "?since=" + item.id + "&type=" + item.get("objectType")
      else
        url = null
      url = url + "&count=" + count  if url and count isnt 20
      url

    getPrev: (count, callback) -> # Get stuff later than the current group
      stream = this
      prevLink = undefined
      options = undefined
      unless callback
        
        # This can also be undefined, btw
        callback = count
        count = 20
      prevLink = stream.prevLink(count)
      unless prevLink
        callback new Error("Can't get prevLink for stream " + stream.url()), null  if _.isFunction(callback)
        return
      options =
        type: "GET"
        dataType: "json"
        url: prevLink
        success: (data) ->
          if data.items and data.items.length > 0
            if stream.items
              stream.items.add data.items,
                at: 0

            else
              stream.items = new stream.itemsClass(data.items)
          if data.links and data.links.prev and data.links.prev.href
            if stream.has("links")
              stream.get("links").prev = data.links.prev
            else
              stream.set "links",
                prev:
                  href: data.links.prev.href

          callback null, data  if _.isFunction(callback)
          return

        error: (jqxhr) ->
          callback Pump.jqxhrError(jqxhr), null  if _.isFunction(callback)
          return

      Pump.ajax options
      return

    getNext: (count, callback) -> # Get stuff earlier than the current group
      stream = this
      nextLink = undefined
      options = undefined
      unless callback
        
        # This can also be undefined, btw
        callback = count
        count = 20
      nextLink = stream.nextLink(count)
      unless nextLink
        callback new Error("Can't get nextLink for stream " + stream.url()), null  if _.isFunction(callback)
        return
      options =
        type: "GET"
        dataType: "json"
        url: nextLink
        success: (data) ->
          if data.items
            if stream.items
              
              # Add them at the end
              stream.items.add data.items,
                at: stream.items.length

            else
              stream.items = new stream.itemsClass(data.items)
          if data.links
            if data.links.next and data.links.next.href
              if stream.has("links")
                stream.get("links").next = data.links.next
              else
                stream.set "links",
                  next:
                    href: data.links.next.href

            else
              delete stream.get("links").next  if stream.has("links")
          callback null, data  if _.isFunction(callback)
          return

        error: (jqxhr) ->
          callback Pump.jqxhrError(jqxhr), null  if _.isFunction(callback)
          return

      Pump.ajax options
      return

    getAllNext: (callback) ->
      stream = this
      stream.getNext stream.maxCount(), (err, data) ->
        if err
          callback err
        else if data.items and data.items.length > 0 and stream.items.length < stream.get("totalItems")
          
          # recurse
          stream.getAllNext callback
        else
          callback null
        return

      return

    getAllPrev: (callback) ->
      stream = this
      stream.getPrev stream.maxCount(), (err, data) ->
        if err
          callback err
        else if data.items and data.items.length > 0 and stream.items.length < stream.get("totalItems")
          
          # recurse
          stream.getAllPrev callback
        else
          callback null
        return

      return

    getAll: (callback) -> # Get stuff later than the current group
      stream = this
      url = stream.url()
      count = undefined
      options = undefined
      nl = undefined
      pl = undefined
      unless url
        callback new Error("No url for stream"), null  if _.isFunction(callback)
        return
      pl = stream.prevLink()
      nl = stream.nextLink()
      if nl or pl
        ndone = false
        nerror = false
        pdone = false
        perror = false
        stream.getAllNext (err) ->
          ndone = true
          if err
            nerror = true
            callback err  unless perror
          else
            callback null  if pdone
          return

        stream.getAllPrev (err) ->
          pdone = true
          if err
            perror = true
            callback err  unless nerror
          else
            callback null  if ndone
          return

      else
        count = stream.maxCount()
        options =
          type: "GET"
          dataType: "json"
          url: url + "?count=" + count
          success: (data) ->
            if data.items
              if stream.items
                stream.items.add data.items
              else
                stream.items = new stream.itemsClass(data.items)
            if data.links and data.links.next and data.links.next.href
              if stream.has("links")
                stream.get("links").next = data.links.next
              else
                stream.set "links", data.links
            else

            
            # XXX: end-of-collection indicator?
            stream.trigger "getall"
            callback null, data  if _.isFunction(callback)
            return

          error: (jqxhr) ->
            callback Pump.jqxhrError(jqxhr), null  if _.isFunction(callback)
            return

        Pump.ajax options
      return

    maxCount: ->
      stream = this
      count = undefined
      total = stream.get("totalItems")
      if _.isNumber(total)
        count = Math.min(total, 200)
      else
        count = 200
      count

    toJSONRef: ->
      str = this
      totalItems: str.get("totalItems")
      url: str.get("url")

    toJSON: (seen) ->
      str = this
      url = str.get("url")
      json = undefined
      seenNow = undefined
      json = Pump.Model::toJSON.apply(str, [seen])
      if not seen or (url and not _.contains(seen, url))
        if seen
          seenNow = seen.slice(0)
        else
          seenNow = []
        seenNow.push url  if url
        json.items = str.items.toJSON(seenNow)
      json

    complicated: ->
      str = this
      names = Pump.Model::complicated.apply(str)
      names.push "items"
      names
  ,
    keyAttr: "url"
  )
  
  # A social activity.
  Pump.Activity = Pump.Model.extend(
    activityObjects: [
      "actor"
      "object"
      "target"
      "generator"
      "provider"
      "location"
    ]
    activityObjectBags: [
      "to"
      "cc"
      "bto"
      "bcc"
    ]
    url: ->
      links = @get("links")
      pump_io = @get("pump_io")
      uuid = @get("uuid")
      if pump_io and pump_io.proxyURL
        pump_io.proxyURL
      else if links and _.isObject(links) and links.self
        links.self
      else if uuid
        "/api/activity/" + uuid
      else
        null

    pubDate: ->
      Date.parse @published

    initialize: ->
      activity = this
      Pump.Model::initialize.apply activity
      
      # For "post" activities we strip the author
      # This adds it back in; important for uniquified stuff
      activity.object.author = activity.actor  if activity.verb is "post" and activity.object and not activity.object.author and activity.actor
      return
  )
  Pump.ActivityItems = Pump.Items.extend(
    model: Pump.Activity
    add: (models, options) ->
      
      # Usually add at the beginning of the list
      options = {}  unless options
      options.at = 0  unless _.has(options, "at")
      Backbone.Collection::add.apply this, [
        models
        options
      ]
      return

    
    # Don't apply changes yet.
    # this.applyChanges(models);
    comparator: (first, second) ->
      d1 = first.pubDate()
      d2 = second.pubDate()
      if d1 > d2
        -1
      else if d2 > d1
        1
      else
        0

    applyChanges: (models) ->
      items = this
      models = [models]  unless _.isArray(models)
      _.each models, (act) ->
        act = Pump.Activity.unique(act)  unless act instanceof Pump.Activity
        switch act.get("verb")
          when "post", "create"
            if act.object.inReplyTo
              act.object.author = act.actor  unless act.object.author
              act.object.inReplyTo.replies = new Pump.ActivityObjectStream()  unless act.object.inReplyTo.replies
              act.object.inReplyTo.replies.items = new Pump.ActivityObjectItems()  unless act.object.inReplyTo.replies.items
              act.object.inReplyTo.replies.items.add act.object
          when "like", "favorite"
            act.object.likes = new Pump.ActivityObjectStream()  unless act.object.likes
            act.object.likes.items = new Pump.ActivityObjectItems()  unless act.object.likes.items
            act.object.likes.items.add act.actor
          when "unlike", "unfavorite"
            act.object.likes.items.remove act.actor  if act.object.likes and act.object.likes.items
          when "share"
            act.object.shares = new Pump.ActivityObjectStream()  unless act.object.shares
            act.object.shares.items = new Pump.ActivityObjectItems()  unless act.object.shares.items
            act.object.shares.items.add act.actor
          when "unshare"
            act.object.shares.items.remove act.actor  if act.object.shares and act.object.shares.items

      return
  )
  Pump.ActivityStream = Pump.Stream.extend(itemsClass: Pump.ActivityItems)
  Pump.ActivityObject = Pump.Model.extend(
    activityObjects: [
      "author"
      "location"
      "inReplyTo"
    ]
    activityObjectBags: [
      "attachments"
      "tags"
    ]
    activityObjectStreams: [
      "likes"
      "replies"
      "shares"
    ]
    url: ->
      links = @get("links")
      pump_io = @get("pump_io")
      uuid = @get("uuid")
      objectType = @get("objectType")
      if pump_io and pump_io.proxyURL
        pump_io.proxyURL
      else if links and _.isObject(links) and _.has(links, "self") and _.isObject(links.self) and _.has(links.self, "href") and _.isString(links.self.href)
        links.self.href
      else if objectType
        "/api/" + objectType + "/" + uuid
      else
        null
  )
  
  # XXX: merge with Pump.Stream?
  Pump.List = Pump.ActivityObject.extend(
    objectType: "collection"
    peopleStreams: ["members"]
    initialize: ->
      Pump.Model::initialize.apply this, arguments_
      return
  )
  Pump.Person = Pump.ActivityObject.extend(
    objectType: "person"
    activityObjectStreams: ["favorites"]
    listStreams: ["lists"]
    peopleStreams: [
      "followers"
      "following"
    ]
    initialize: ->
      Pump.Model::initialize.apply this, arguments_
      return
  )
  Pump.ActivityObjectItems = Pump.Items.extend(model: Pump.ActivityObject)
  Pump.ActivityObjectStream = Pump.Stream.extend(itemsClass: Pump.ActivityObjectItems)
  Pump.ListItems = Pump.Items.extend(model: Pump.List)
  Pump.ListStream = Pump.Stream.extend(itemsClass: Pump.ListItems)
  
  # Unordered, doesn't have an URL
  Pump.ActivityObjectBag = Backbone.Collection.extend(
    model: Pump.ActivityObject
    merge: (models, options) ->
      bag = this
      Model = bag.model
      mapped = undefined
      mapped = models.map((item) ->
        Model.unique item
      )
      bag.add mapped
      return
  )
  Pump.PeopleItems = Pump.Items.extend(model: Pump.Person)
  Pump.PeopleStream = Pump.ActivityObjectStream.extend(
    itemsClass: Pump.PeopleItems
    nextLink: ->
      str = this
      url = undefined
      url = Pump.ActivityObjectStream::nextLink.apply(str, arguments_)
      url = url + "&type=person"  if url and url.indexOf("&type=person") is -1
      url

    prevLink: ->
      str = this
      url = undefined
      url = Pump.ActivityObjectStream::prevLink.apply(str, arguments_)
      url = url + "&type=person"  if url and url.indexOf("&type=person") is -1
      url
  )
  Pump.User = Pump.Model.extend(
    idAttribute: "nickname"
    people: ["profile"]
    initialize: ->
      user = this
      streamUrl = (rel) ->
        Pump.fullURL "/api/user/" + user.get("nickname") + rel

      userStream = (rel) ->
        Pump.ActivityStream.unique url: streamUrl(rel)

      Pump.Model::initialize.apply this, arguments_
      
      # XXX: maybe move some of these to Person...?
      user.inbox = userStream("/inbox")
      user.majorInbox = userStream("/inbox/major")
      user.minorInbox = userStream("/inbox/minor")
      user.directInbox = userStream("/inbox/direct")
      user.majorDirectInbox = userStream("/inbox/direct/major")
      user.minorDirectInbox = userStream("/inbox/direct/minor")
      user.stream = userStream("/feed")
      user.majorStream = userStream("/feed/major")
      user.minorStream = userStream("/feed/minor")
      user.on "change:nickname", ->
        user.inbox.url = streamUrl("/inbox")
        user.majorInbox.url = streamUrl("/inbox/major")
        user.minorInbox.url = streamUrl("/inbox/minor")
        user.directInbox.url = streamUrl("/inbox/direct")
        user.majorDirectInbox.url = streamUrl("/inbox/direct/major")
        user.minorDirectInbox.url = streamUrl("/inbox/direct/minor")
        user.stream.url = streamUrl("/feed")
        user.majorStream.url = streamUrl("/feed/major")
        user.minorStream.url = streamUrl("/feed/minor")
        return

      return

    isNew: ->
      
      # Always PUT
      false

    url: ->
      Pump.fullURL "/api/user/" + @get("nickname")
  ,
    cache: {} # separate cache
    keyAttr: "nickname" # cache by nickname
    clearCache: ->
      @cache = {}
      return
  )
  return
) window._, window.$, window.Backbone, window.Pump
