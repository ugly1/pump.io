# person.js
#
# data object representing an person
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
path = require("path")
os = require("os")
DatabankObject = require("databank").DatabankObject
Step = require("step")
_ = require("underscore-contrib")
wf = require("webfinger")
mover = require("../mover")
thumbnail = require("../thumbnail")
ActivityObject = require("./activityobject").ActivityObject
Image = require("./image").Image
URLMaker = require("../urlmaker").URLMaker
Person = DatabankObject.subClass("person", ActivityObject)
Person.schema = ActivityObject.subSchema([
  "attachments"
  "author"
  "inReplyTo"
], [
  "followers"
  "following"
  "favorites"
  "lists"
], ["image.url"])
Person.pkey = ->
  "id"

Person.beforeCreate = (props, callback) ->
  Step (->
    ActivityObject.beforeCreate.apply Person, [
      props
      this
    ]
    return
  ), (err, props) ->
    if err
      callback err, null
    else
      
      # Are we creating a local user?
      # XXX: watch out for tricks!
      if _.has(props, "_user") and props._user
        props.links = {}  unless _.has(props, "links")
        props.links["activity-inbox"] = href: URLMaker.makeURL("api/user/" + props.preferredUsername + "/inbox")
        props.links["activity-outbox"] = href: URLMaker.makeURL("api/user/" + props.preferredUsername + "/feed")
        
        # NB: overwrites self-link in ActivityObject.beforeCreate
        props.links["self"] = href: URLMaker.makeURL("api/user/" + props.preferredUsername + "/profile")
        
        # Add the feeds sub-elements
        Person.ensureFeeds props, props.preferredUsername
        
        # Trim them if they existed before
        ActivityObject.trimCollection props, "followers"
        ActivityObject.trimCollection props, "following"
        ActivityObject.trimCollection props, "favorites"
        ActivityObject.trimCollection props, "lists"
      callback null, props
    return

  return

Person::afterGet = (callback) ->
  person = this
  Upgrader = require("../upgrader")
  ActivityObject.trimCollection person, "followers"
  ActivityObject.trimCollection person, "following"
  ActivityObject.trimCollection person, "favorites"
  ActivityObject.trimCollection person, "lists"
  
  # Perform automated upgrades at read-time
  Upgrader.upgradePerson person, callback
  return

Person::beforeUpdate = (props, callback) ->
  person = this
  Step (->
    ActivityObject::beforeUpdate.apply person, [
      props
      this
    ]
    return
  ), (err, props) ->
    if err
      callback err, null
    else
      
      # Trim them if they existed before
      ActivityObject.trimCollection props, "followers"
      ActivityObject.trimCollection props, "following"
      ActivityObject.trimCollection props, "favorites"
      ActivityObject.trimCollection props, "lists"
      callback null, props
    return

  return

Person::beforeSave = (callback) ->
  person = this
  Step (->
    ActivityObject::beforeSave.apply person, [this]
    return
  ), (err) ->
    if err
      callback err
    else
      
      # Trim them if they existed before
      ActivityObject.trimCollection person, "followers"
      ActivityObject.trimCollection person, "following"
      ActivityObject.trimCollection person, "favorites"
      ActivityObject.trimCollection person, "lists"
      callback null
    return

  return

Person.ensureFeeds = (obj, nickname) ->
  feeds = [
    "followers"
    "following"
    "favorites"
  ]
  _.each feeds, (feed) ->
    obj[feed] = url: URLMaker.makeURL("/api/user/" + nickname + "/" + feed)  unless _.has(obj, feed)
    return

  obj.lists = url: URLMaker.makeURL("/api/user/" + nickname + "/lists/person")  unless _.has(obj, "lists")
  return

Person::followersURL = (callback) ->
  person = this
  User = require("./user").User
  url = _.getPath(person, [
    "followers"
    "url"
  ])
  if url
    callback null, url
    return
  Step (->
    User.fromPerson person.id, this
    return
  ), (err, user) ->
    if err
      callback err, null
    else unless user
      callback null, null
    else
      callback null, URLMaker.makeURL("api/user/" + user.nickname + "/followers")
    return

  return

Person::getInbox = (callback) ->
  person = this
  User = require("./user").User
  
  # XXX: use person.links to find one with "activity-inbox" rel
  Step (->
    User.fromPerson person.id, this
    return
  ), ((err, user) ->
    throw err  if err
    if user
      callback null, URLMaker.makeURL("api/user/" + user.nickname + "/inbox")
    else if person.id.substr(0, 5) is "acct:"
      wf.webfinger person.id.substr(5), this
    else
      
      # XXX: try LRDD for http: and https: URIs
      # XXX: try LRDD for http: and https: URIs
      # XXX: try getting Link or <link> values from person.url
      callback new Error("Can't get inbox for " + person.id), null
    return
  ), (err, jrd) ->
    inboxes = undefined
    if err
      callback err, null
      return
    else if not _(jrd).has("links") or not _(jrd.links).isArray()
      callback new Error("Can't get inbox for " + person.id), null
      return
    else
      
      # Get the inboxes
      inboxes = jrd.links.filter((link) ->
        link.hasOwnProperty("rel") and link.rel is "activity-inbox" and link.hasOwnProperty("href")
      )
      if inboxes.length is 0
        callback new Error("Can't get inbox for " + person.id), null
        return
      callback null, inboxes[0].href
    return

  return

Person::expandFeeds = (callback) ->
  person = this
  user = undefined
  
  # These are inapplicable feeds; hide them
  delete person.likes

  delete person.replies

  Step (->
    User = require("./user").User
    User.fromPerson person.id, this
    return
  ), ((err, result) ->
    cb = undefined
    throw err  if err
    unless result
      callback null
      return
    user = result
    user.followerCount @parallel()
    user.followingCount @parallel()
    user.favoritesCount @parallel()
    
    # Blech.
    cb = @parallel()
    user.getLists Person.type, (err, str) ->
      if err
        cb err, null
      else
        str.count cb
      return

    return
  ), (err, followers, following, favorites, lists) ->
    if err
      callback err
    else
      
      # Make sure all feed objects exist
      Person.ensureFeeds person, user.nickname
      person.followers.totalItems = followers
      person.following.totalItems = following
      person.favorites.totalItems = favorites
      person.lists.totalItems = lists
      
      # Make sure there are no actual items in there
      delete person.followers.items

      delete person.following.items

      delete person.favorites.items

      delete person.lists.items

      callback null
    return

  return

Person::sanitize = ->
  delete @_user  if @_user
  ActivityObject::sanitize.apply this
  return

Person.match = (q) ->
  (id, callback) ->
    Step (->
      Person.get id, this
      return
    ), ((err, person) ->
      throw err  if err
      
      # Case-insensitive search
      if person.displayName and person.displayName.toLowerCase().indexOf(q.toLowerCase()) isnt -1
        this null, true
      else
        this null, false
      return
    ), callback
    return

exports.Person = Person
