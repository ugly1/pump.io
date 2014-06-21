# lib/finishers.js
#
# Functions for adding extra flags and stream data to API output
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
_ = require("underscore")
Step = require("step")
ActivityObject = require("../lib/model/activityobject").ActivityObject
Edge = require("../lib/model/edge").Edge
Proxy = require("../lib/model/proxy").Proxy
Favorite = require("../lib/model/favorite").Favorite
Share = require("../lib/model/share").Share
FilteredStream = require("../lib/filteredstream").FilteredStream
filters = require("../lib/filters")
URLMaker = require("../lib/urlmaker").URLMaker
urlparse = require("url").parse
recipientsOnly = filters.recipientsOnly
objectRecipientsOnly = filters.objectRecipientsOnly
objectPublicOnly = filters.objectPublicOnly
publicOnly = filters.publicOnly

# finisher that adds followed flag to stuff
addFollowedFinisher = (principal, collection, callback) ->
  
  # Ignore for non-users
  unless principal
    callback null
    return
  addFollowed principal, _.pluck(collection.items, "object"), callback
  return

addFollowed = (profile, objects, callback) ->
  edgeIDs = undefined
  
  # Ignore for non-users
  unless profile
    callback null
    return
  edgeIDs = objects.map((object) ->
    Edge.id profile.id, object.id
  )
  Step (->
    Edge.readAll edgeIDs, this
    return
  ), (err, edges) ->
    if err
      callback err
    else
      _.each objects, (object, i) ->
        edgeID = edgeIDs[i]
        object.pump_io = {}  unless _.has(object, "pump_io")
        if _.has(edges, edgeID) and _.isObject(edges[edgeID])
          object.pump_io.followed = true
        else
          object.pump_io.followed = false
        return

      callback null
    return

  return


# finisher that adds shared flag to stuff
addSharedFinisher = (principal, collection, callback) ->
  
  # Ignore for non-users
  unless principal
    callback null
    return
  addShared principal, _.pluck(collection.items, "object"), callback
  return

addShared = (profile, objects, callback) ->
  shareIDs = undefined
  
  # Ignore for non-users
  unless profile
    callback null
    return
  shareIDs = objects.map((object) ->
    Share.id profile, object
  )
  Step (->
    Share.readAll shareIDs, this
    return
  ), (err, shares) ->
    if err
      callback err
    else
      _.each objects, (object, i) ->
        shareID = shareIDs[i]
        object.pump_io = {}  unless _.has(object, "pump_io")
        if _.has(shares, shareID) and _.isObject(shares[shareID])
          object.pump_io.shared = true
        else
          object.pump_io.shared = false
        return

      callback null
    return

  return


# finisher that adds liked flag to stuff
addLikedFinisher = (principal, collection, callback) ->
  
  # Ignore for non-users
  unless principal
    callback null
    return
  addLiked principal, _.pluck(collection.items, "object"), callback
  return

addLiked = (profile, objects, callback) ->
  faveIDs = undefined
  
  # Ignore for non-users
  unless profile
    callback null
    return
  faveIDs = objects.map((object) ->
    Favorite.id profile.id, object.id
  )
  Step (->
    Favorite.readAll faveIDs, this
    return
  ), (err, faves) ->
    if err
      callback err
    else
      _.each objects, (object, i) ->
        faveID = faveIDs[i]
        if _.has(faves, faveID) and _.isObject(faves[faveID])
          object.liked = true
        else
          object.liked = false
        return

      callback null
    return

  return

firstFewRepliesFinisher = (principal, collection, callback) ->
  profile = principal
  objects = _.pluck(collection.items, "object")
  firstFewReplies profile, objects, callback
  return

firstFewReplies = (profile, objs, callback) ->
  getReplies = (obj, callback) ->
    objs = undefined
    if not _.has(obj, "replies") or not _.isObject(obj.replies) or (_.has(obj.replies, "totalItems") and obj.replies.totalItems is 0)
      callback null
      return
    Step (->
      obj.getRepliesStream this
      return
    ), ((err, str) ->
      filtered = undefined
      throw err  if err
      unless profile
        filtered = new FilteredStream(str, objectPublicOnly)
      else
        filtered = new FilteredStream(str, objectRecipientsOnly(profile))
      filtered.getObjects 0, 4, this
      return
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()
        return

      return
    ), ((err, results) ->
      group = @group()
      throw err  if err
      objs = results
      _.each objs, (obj) ->
        obj.expandFeeds group()
        return

      return
    ), ((err) ->
      throw err  if err
      addLiked profile, objs, @parallel()
      addLikers profile, objs, @parallel()
      return
    ), (err) ->
      if err
        callback err
      else
        obj.replies.items = objs
        _.each obj.replies.items, (item) ->
          item.sanitize()
          return

        callback null
      return

    return

  Step (->
    group = @group()
    _.each objs, (obj) ->
      getReplies obj, group()
      return

    return
  ), callback
  return

firstFewSharesFinisher = (principal, collection, callback) ->
  profile = principal
  objects = _.pluck(collection.items, "object")
  firstFewShares profile, objects, callback
  return

firstFewShares = (profile, objs, callback) ->
  getShares = (obj, callback) ->
    if not _.has(obj, "shares") or not _.isObject(obj.shares) or (_.has(obj.shares, "totalItems") and obj.shares.totalItems is 0)
      callback null
      return
    Step (->
      obj.getSharesStream this
      return
    ), ((err, str) ->
      throw err  if err
      str.getObjects 0, 4, this
      return
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()
        return

      return
    ), (err, objs) ->
      if err
        callback err
      else
        obj.shares.items = objs
        _.each obj.shares.items, (item) ->
          item.sanitize()
          return

        callback null
      return

    return

  Step (->
    group = @group()
    _.each objs, (obj) ->
      getShares obj, group()
      return

    return
  ), callback
  return


# finisher that adds followed flag to stuff
addLikersFinisher = (principal, collection, callback) ->
  
  # Ignore for non-users
  addLikers principal, _.pluck(collection.items, "object"), callback
  return

addLikers = (profile, objects, callback) ->
  liked = _.filter(objects, (object) ->
    _.has(object, "likes") and _.isObject(object.likes) and _.has(object.likes, "totalItems") and _.isNumber(object.likes.totalItems) and object.likes.totalItems > 0
  )
  Step (->
    group = @group()
    _.each liked, (object) ->
      object.getFavoriters 0, 4, group()
      return

    return
  ), (err, likers) ->
    if err
      callback err
    else
      _.each liked, (object, i) ->
        object.likes.items = likers[i]
        return

      callback null
    return

  return


# finisher that adds proxy URLs for remote URLs
addProxyFinisher = (principal, collection, callback) ->
  op = [
    "actor"
    "object"
    "target"
    "generator"
    "provider"
    "context"
    "source"
  ]
  ap = [
    "to"
    "cc"
    "bto"
    "bcc"
  ]
  objects = []
  activities = collection.items
  unless principal
    callback null
    return
  
  # Get all the objects that are parts of these activities
  _.each op, (prop) ->
    objects = objects.concat(_.pluck(activities, prop))
    return

  _.each ap, (prop) ->
    values = _.pluck(activities, prop)
    _.each values, (value) ->
      objects = objects.concat(value)
      return

    return

  objects = _.compact(objects)
  addProxyObjects principal, objects, callback
  return

addProxyObjects = (principal, objects, callback) ->
  mp = [
    "image"
    "stream"
    "fullImage"
  ]
  cp = [
    "members"
    "followers"
    "following"
    "lists"
    "likes"
    "replies"
    "shares"
  ]
  props = []
  selves = []
  urls = undefined
  unless principal
    callback null
    return
  
  # Get all the media stream properties that we know have urls and are parts of these objects
  _.each mp, (prop) ->
    props = props.concat(_.pluck(objects, prop))
    return

  
  # Get all the collection properties that we know have urls and are parts of these objects
  _.each cp, (prop) ->
    props = props.concat(_.pluck(objects, prop))
    return

  
  # Squish them down so we only have the ones we need
  props = _.compact(props)
  urls = _.compact(_.pluck(props, "url"))
  
  # Get all the self-links
  _.each objects, (obj) ->
    urls.push obj.links.self.href  if obj.links and obj.links.self and obj.links.self.href
    return

  
  # Uniquify the whole set of URLs
  urls = _.uniq(urls)
  
  # Throw out anything that's not a string
  urls = _.filter(urls, (url) ->
    _.isString url
  )
  
  # Only need proxies for remote URLs
  urls = _.filter(urls, (url) ->
    parts = urlparse(url)
    parts.hostname isnt URLMaker.hostname and (not Proxy.whitelist or Proxy.whitelist.indexOf(parts.hostname) is -1)
  )
  Step (->
    User = require("./model/user").User
    User.fromPerson principal.id, this
    return
  ), ((err, user) ->
    if err
      throw err
    else unless user
      
      # Don't add proxy urls for non-users
      callback null
      return
    else
      Proxy.ensureAll urls, this
    return
  ), (err, utp) ->
    if err
      callback err
      return
    _.each props, (prop) ->
      if _.has(utp, prop.url)
        prop.pump_io = {}  unless prop.pump_io
        prop.pump_io.proxyURL = URLMaker.makeURL("/api/proxy/" + utp[prop.url].id)
      return

    _.each objects, (obj) ->
      if obj.links and obj.links.self and obj.links.self.href
        if _.has(utp, obj.links.self.href)
          obj.pump_io = {}  unless obj.pump_io
          obj.pump_io.proxyURL = URLMaker.makeURL("/api/proxy/" + utp[obj.links.self.href].id)
      return

    callback null
    return

  return

doFinishers = (finishers) ->
  (principal, collection, callback) ->
    Step (->
      group = @group()
      _.each finishers, (finisher) ->
        finisher principal, collection, group()
        return

      return
    ), callback
    return

exports.addFollowedFinisher = addFollowedFinisher
exports.addFollowed = addFollowed
exports.addLikedFinisher = addLikedFinisher
exports.addLiked = addLiked
exports.firstFewRepliesFinisher = firstFewRepliesFinisher
exports.firstFewReplies = firstFewReplies
exports.firstFewSharesFinisher = firstFewSharesFinisher
exports.firstFewShares = firstFewShares
exports.doFinishers = doFinishers
exports.addLikersFinisher = addLikersFinisher
exports.addLikers = addLikers
exports.addSharedFinisher = addSharedFinisher
exports.addShared = addShared
exports.addProxyFinisher = addProxyFinisher
exports.addProxyObjects = addProxyObjects
