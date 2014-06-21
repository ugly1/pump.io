# streams.js
#
# Move the important streams to their own module
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
_ = require("underscore")
Step = require("step")
FilteredStream = require("../lib/filteredstream").FilteredStream
filters = require("../lib/filters")
recipientsOnly = filters.recipientsOnly
publicOnly = filters.publicOnly
objectRecipientsOnly = filters.objectRecipientsOnly
objectPublicOnly = filters.objectPublicOnly
idRecipientsOnly = filters.idRecipientsOnly
idPublicOnly = filters.idPublicOnly
HTTPError = require("../lib/httperror").HTTPError
Activity = require("../lib/model/activity").Activity
Collection = require("../lib/model/collection").Collection
ActivityObject = require("../lib/model/activityobject").ActivityObject
Person = require("../lib/model/person").Person
stream = require("../lib/model/stream")
NotInStreamError = stream.NotInStreamError
URLMaker = require("../lib/urlmaker").URLMaker
randomString = require("../lib/randomstring").randomString
finishers = require("../lib/finishers")
NoSuchThingError = databank.NoSuchThingError
addFollowedFinisher = finishers.addFollowedFinisher
addFollowed = finishers.addFollowed
addLikedFinisher = finishers.addLikedFinisher
addLiked = finishers.addLiked
addLikersFinisher = finishers.addLikersFinisher
addLikers = finishers.addLikers
addSharedFinisher = finishers.addSharedFinisher
addShared = finishers.addShared
addProxyFinisher = finishers.addProxyFinisher
addProxyObjects = finishers.addProxyObjects
firstFewRepliesFinisher = finishers.firstFewRepliesFinisher
firstFewReplies = finishers.firstFewReplies
firstFewSharesFinisher = finishers.firstFewSharesFinisher
firstFewShares = finishers.firstFewShares
doFinishers = finishers.doFinishers
activityFeed = (relmaker, titlemaker, streammaker, finisher) ->
  (context, principal, args, callback) ->
    base = relmaker(context)
    url = URLMaker.makeURL(base)
    collection =
      displayName: titlemaker(context)
      objectTypes: ["activity"]
      url: url
      links:
        first:
          href: url

        self:
          href: url

      items: []

    str = undefined
    ids = undefined
    
    # XXX: making assumptions about the context is probably bad
    collection.author = context.user.profile  if context.user
    
    # args are optional
    unless callback
      callback = args
      args =
        start: 0
        end: 20
    Step (->
      streammaker context, this
      return
    ), ((err, results) ->
      if err
        if err.name is "NoSuchThingError"
          collection.totalItems = 0
          collection.items = []
          this null, 0
        else
          throw err
      else
        
        # Skip filtering if remote user == author
        if principal and collection.author and principal.id is collection.author.id
          str = results
        else unless principal
          
          # XXX: keep a separate stream instead of filtering
          str = new FilteredStream(results, publicOnly)
        else
          str = new FilteredStream(results, recipientsOnly(principal))
        str.count this
      return
    ), ((err, totalItems) ->
      throw err  if err
      collection.totalItems = totalItems
      if totalItems is 0
        this null, []
        return
      if _(args).has("before")
        str.getIDsGreaterThan args.before, args.count, this
      else if _(args).has("since")
        str.getIDsLessThan args.since, args.count, this
      else
        str.getIDs args.start, args.end, this
      return
    ), ((err, ids) ->
      if err
        if err.name is "NotInStreamError"
          throw new HTTPError(err.message, 400)
        else
          throw err
      if ids.length is 0
        this null, []
      else
        Activity.readArray ids, this
      return
    ), ((err, activities) ->
      throw err  if err
      activities.forEach (act) ->
        act.sanitize principal
        return

      collection.items = activities
      if activities.length > 0
        collection.links.prev = href: collection.url + "?since=" + encodeURIComponent(activities[0].id)
        collection.links.next = href: collection.url + "?before=" + encodeURIComponent(activities[activities.length - 1].id)  if (_(args).has("start") and args.start + activities.length < collection.totalItems) or (_(args).has("before") and activities.length >= args.count) or (_(args).has("since"))
      if finisher
        finisher principal, collection, this
      else
        this null
      return
    ), (err) ->
      if err
        callback err, null
      else
        collection.author.sanitize()  if _.has(collection, "author")
        callback null, collection
      return

    return

personFeed = (relmaker, titlemaker, streammaker, finisher) ->
  (context, principal, args, callback) ->
    str = undefined
    base = relmaker(context)
    url = URLMaker.makeURL(base)
    collection =
      displayName: titlemaker(context)
      url: url
      objectTypes: ["person"]
      items: []

    unless callback
      callback = args
      args =
        start: 0
        end: 20
    Step (->
      streammaker context, this
      return
    ), ((err, results) ->
      throw err  if err
      if args.q
        str = new FilteredStream(results, Person.match(args.q))
      else
        str = results
      str.count this
      return
    ), ((err, count) ->
      if err
        if err.name is "NoSuchThingError"
          collection.totalItems = 0
          this null, []
        else
          throw err
      else
        collection.totalItems = count
        if _(args).has("before")
          str.getIDsGreaterThan args.before, args.count, this
        else if _(args).has("since")
          str.getIDsLessThan args.since, args.count, this
        else
          str.getIDs args.start, args.end, this
      return
    ), ((err, ids) ->
      throw err  if err
      if ids.length is 0
        this null, []
      else
        Person.readArray ids, this
      return
    ), ((err, people) ->
      throw err  if err
      collection.items = people
      finisher context, principal, collection, this
      return
    ), (err) ->
      if err
        callback err, null
      else
        _.each collection.items, (person) ->
          person.sanitize()
          return

        collection.links =
          self:
            href: URLMaker.makeURL(base,
              offset: args.start
              count: args.count
            )

          current:
            href: URLMaker.makeURL(base)

        if collection.items.length > 0
          collection.links.prev = href: URLMaker.makeURL(base,
            since: collection.items[0].id
          )
          if collection.totalItems > collection.items.length and (not _.has(args, "start") or collection.totalItems > (args.start + collection.items.length))
            collection.links.next = href: URLMaker.makeURL(base,
              before: collection.items[collection.items.length - 1].id
            )
        collection.author.sanitize()  if _.has(collection, "author")
        callback null, collection
      return

    return

objectFeed = (relmaker, titlemaker, streammaker, finisher) ->
  (context, principal, args, callback) ->
    str = undefined
    base = relmaker(context)
    url = URLMaker.makeURL(base)
    collection =
      displayName: titlemaker(context)
      url: url
      items: []
      links:
        first:
          href: url

        self:
          href: url

    unless callback
      callback = args
      args =
        start: 0
        end: 20
    Step (->
      streammaker context, this
      return
    ), ((err, results) ->
      throw err  if err
      unless principal
        
        # XXX: keep a separate stream instead of filtering
        str = new FilteredStream(results, objectPublicOnly)
      else if context.author and context.author.id is principal.id
        str = results
      else
        str = new FilteredStream(results, objectRecipientsOnly(principal))
      str.count @parallel()
      return
    ), ((err, count) ->
      type = undefined
      throw err  if err
      collection.totalItems = count
      if count is 0
        this null, []
      else
        type = context.type
        if type and _.has(args, "before")
          str.getObjectsGreaterThan
            id: args.before
            objectType: type
          , args.count, @parallel()
        else if type and _.has(args, "since")
          str.getObjectsLessThan
            id: args.since
            objectType: type
          , args.count, @parallel()
        else
          str.getObjects args.start, args.end, @parallel()
      return
    ), ((err, refs) ->
      group = @group()
      throw err  if err
      _.each refs, (ref) ->
        ActivityObject.getObject ref.objectType, ref.id, group()
        return

      return
    ), ((err, objs) ->
      group = @group()
      throw err  if err
      collection.items = objs
      _.each collection.items, (obj) ->
        obj.expandFeeds group()
        return

      return
    ), ((err) ->
      throw err  if err
      finisher context, principal, collection, this
      return
    ), (err) ->
      if err
        callback err, null
      else
        callback null, collection
      return

    return

collectionFeed = (relmaker, titlemaker, streammaker, finisher) ->
  (context, principal, args, callback) ->
    base = relmaker(context)
    url = URLMaker.makeURL(base)
    collection =
      displayName: titlemaker(context)
      objectTypes: ["collection"]
      url: url
      links:
        first:
          href: url

        self:
          href: url

      items: []

    unless callback
      callback = args
      args =
        start: 0
        end: 20
    lists = undefined
    stream = undefined
    Step (->
      streammaker context, this
      return
    ), ((err, result) ->
      throw err  if err
      stream = result
      stream.count this
      return
    ), ((err, totalItems) ->
      filtered = undefined
      throw err  if err
      collection.totalItems = totalItems
      if totalItems is 0
        collection.author.sanitize()  if _.has(collection, "author")
        callback null, collection
        return
      unless principal
        filtered = new FilteredStream(stream, idPublicOnly(Collection.type))
      else
        filtered = new FilteredStream(stream, idRecipientsOnly(principal, Collection.type))
      if _(args).has("before")
        filtered.getIDsGreaterThan args.before, args.count, this
      else if _(args).has("since")
        filtered.getIDsLessThan args.since, args.count, this
      else
        filtered.getIDs args.start, args.end, this
      return
    ), ((err, ids) ->
      if err
        if err.name is "NotInStreamError"
          throw new HTTPError(err.message, 400)
        else
          throw err
      Collection.readArray ids, this
      return
    ), ((err, results) ->
      group = @group()
      throw err  if err
      lists = results
      _.each lists, (list) ->
        list.expandFeeds group()
        return

      return
    ), ((err) ->
      throw err  if err
      finisher context, principal, collection, this
      return
    ), (err) ->
      if err
        callback err, null
      else
        _.each lists, (item) ->
          item.sanitize()
          return

        collection.items = lists
        if lists.length > 0
          collection.links.prev = href: collection.url + "?since=" + encodeURIComponent(lists[0].id)
          collection.links.next = href: collection.url + "?before=" + encodeURIComponent(lists[lists.length - 1].id)  if (_(args).has("start") and args.start + lists.length < collection.totalItems) or (_(args).has("before") and lists.length >= args.count) or (_(args).has("since"))
        collection.author.sanitize()  if _.has(collection, "author")
        callback null, collection
      return

    return

majorFinishers = doFinishers([
  addProxyFinisher
  addLikedFinisher
  firstFewRepliesFinisher
  addLikersFinisher
  addSharedFinisher
  firstFewSharesFinisher
])
userStream = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/feed"
, (context) ->
  user = context.user
  "Activities by " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getOutboxStream callback
  return
, addProxyFinisher)
userMajorStream = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/feed/major"
, (context) ->
  user = context.user
  "Major activities by " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getMajorOutboxStream callback
  return
, majorFinishers)
userMinorStream = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/feed/minor"
, (context) ->
  user = context.user
  "Minor activities by " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getMinorOutboxStream callback
  return
, addProxyFinisher)
userInbox = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/inbox"
, (context) ->
  user = context.user
  "Activities for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getInboxStream callback
  return
, addProxyFinisher)
userMajorInbox = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/inbox/major"
, (context) ->
  user = context.user
  "Major activities for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getMajorInboxStream callback
  return
, majorFinishers)
userMinorInbox = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/inbox/minor"
, (context) ->
  user = context.user
  "Minor activities for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getMinorInboxStream callback
  return
, addProxyFinisher)
userDirectInbox = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/inbox/direct"
, (context) ->
  user = context.user
  "Activities directly for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getDirectInboxStream callback
  return
, addProxyFinisher)
userMajorDirectInbox = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/inbox/direct/major"
, (context) ->
  user = context.user
  "Major activities directly for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getMajorDirectInboxStream callback
  return
, majorFinishers)
userMinorDirectInbox = activityFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/inbox/direct/minor"
, (context) ->
  user = context.user
  "Minor activities directly for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.getMinorDirectInboxStream callback
  return
, addProxyFinisher)
userFollowers = personFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/followers"
, (context) ->
  user = context.user
  "Followers for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.followersStream callback
  return
, (context, principal, collection, callback) ->
  user = context.user
  collection.author = user.profile
  collection.author.sanitize()  if collection.author
  addFollowed principal, collection.items, callback
  return
)
userFollowing = personFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/following"
, (context) ->
  user = context.user
  "Following for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.followingStream callback
  return
, (context, principal, collection, callback) ->
  user = context.user
  collection.author = user.profile
  collection.author.sanitize()  if collection.author
  addFollowed principal, collection.items, callback
  return
)
userFavorites = objectFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/favorites"
, (context) ->
  user = context.user
  "Things that " + (user.profile.displayName or user.nickname) + " has favorited"
, (context, callback) ->
  user = context.user
  user.favoritesStream callback
  return
, (context, principal, collection, callback) ->
  user = context.user
  collection.author = user.profile
  collection.author.sanitize()  if collection.author
  Step (->
    
    # Add the first few replies for each object
    firstFewReplies principal, collection.items, @parallel()
    
    # Add the first few replies for each object
    firstFewShares principal, collection.items, @parallel()
    
    # Add the first few "likers" for each object
    addLikers principal, collection.items, @parallel()
    
    # Add the shared flag for each object
    addShared principal, collection.items, @parallel()
    
    # Add the liked flag for each object
    addLiked principal, collection.items, @parallel()
    
    # Add the proxy URLs for each object
    addProxyObjects principal, collection.items, @parallel()
    return
  ), (err) ->
    callback err
    return

  return
)
userUploads = objectFeed((context) ->
  user = context.user
  "api/user/" + user.nickname + "/uploads"
, (context) ->
  user = context.user
  "Uploads by " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  user.uploadsStream callback
  return
, (context, principal, collection, callback) ->
  callback null
  return
)
objectLikes = personFeed((context) ->
  type = context.type
  obj = context.obj
  "api/" + type + "/" + obj._uuid + "/likes"
, (context) ->
  obj = context.obj
  "People who like " + obj.displayName
, (context, callback) ->
  obj = context.obj
  obj.getFavoritersStream callback
  return
, (context, principal, collection, callback) ->
  callback null
  return
)
objectReplies = objectFeed((context) ->
  objectType = context.objectType
  obj = context.obj
  "api/" + objectType + "/" + obj._uuid + "/replies"
, (context) ->
  obj = context.obj
  "Replies to " + ((if (obj.displayName) then obj.displayName else obj.id))
, (context, callback) ->
  obj = context.obj
  obj.getRepliesStream callback
  return
, (context, principal, collection, callback) ->
  _.each collection.items, (obj) ->
    delete obj.inReplyTo

    return

  Step (->
    addLiked principal, collection.items, @parallel()
    addLikers principal, collection.items, @parallel()
    return
  ), callback
  return
)
objectShares = objectFeed((context) ->
  type = context.type
  obj = context.obj
  "api/" + type + "/" + obj._uuid + "/shares"
, (context) ->
  obj = context.obj
  "Shares of " + ((if (obj.displayName) then obj.displayName else obj.id))
, (context, callback) ->
  obj = context.obj
  obj.getSharesStream callback
  return
, (context, principal, collection, callback) ->
  callback null
  return
)
collectionMembers = objectFeed((context) ->
  coll = context.collection
  "/api/collection/" + coll._uuid + "/members"
, (context) ->
  coll = context.collection
  "Members of " + (coll.displayName or "a collection") + " by " + coll.author.displayName
, (context, callback) ->
  coll = context.collection
  coll.getStream callback
  return
, (context, principal, collection, callback) ->
  coll = context.collection
  base = "/api/collection/" + coll._uuid + "/members"
  prevParams = undefined
  nextParams = undefined
  first = undefined
  last = undefined
  collection.author = coll.author
  collection.author.sanitize()  if collection.author
  if collection.items.length > 0
    collection.links = {}  unless collection.links
    first = collection.items[0]
    prevParams = since: first.id
    prevParams.type = first.objectType  if not collection.objectTypes or collection.objectTypes.length isnt 1 or first.objectType isnt collection.objectTypes[0]
    collection.links.prev = href: URLMaker.makeURL(base, prevParams)
    if collection.items.length < collection.totalItems
      last = collection.items[collection.items.length - 1]
      nextParams = before: last.id
      nextParams.type = last.objectType  if not collection.objectTypes or collection.objectTypes.length isnt 1 or last.objectType isnt collection.objectTypes[0]
      collection.links.next = href: URLMaker.makeURL(base, nextParams)
  Step (->
    group = @group()
    _.each collection.items, (item) ->
      item.expand group()
      return

    return
  ), ((err, expanded) ->
    followable = undefined
    throw err  if err
    
    # Add the first few replies for each object
    firstFewReplies principal, collection.items, @parallel()
    
    # Add the first few shares for each object
    firstFewShares principal, collection.items, @parallel()
    
    # Add the first few "likers" for each object
    addLikers principal, collection.items, @parallel()
    
    # Add whether the current user likes the items
    addLiked principal, collection.items, @parallel()
    
    # Add the followed flag to applicable objects
    followable = _.filter(collection.items, (obj) ->
      obj.isFollowable()
    )
    addFollowed principal, followable, @parallel()
    
    # Add proxy URLs to applicable objects
    addProxyObjects principal, collection.items, @parallel()
    return
  ), callback
  return
)
userLists = collectionFeed((context) ->
  user = context.user
  type = context.type
  "api/user/" + user.nickname + "/lists/" + type
, (context) ->
  user = context.user
  type = context.type
  "Collections of " + type + "s for " + (user.profile.displayName or user.nickname)
, (context, callback) ->
  user = context.user
  type = context.type
  user.getLists type, callback
  return
, (context, principal, collection, callback) ->
  user = context.user
  collection.author = user.profile
  callback null
  return
)
groupMembers = personFeed((context) ->
  group = context.group
  "api/group/" + group._uuid + "/members"
, (context) ->
  group = context.group
  "Members of " + group.displayName
, (context, callback) ->
  group = context.group
  group.getMembersStream callback
  return
, (context, principal, collection, callback) ->
  callback null
  return
)
groupDocuments = objectFeed((context) ->
  group = context.group
  "api/group/" + group._uuid + "/documents"
, (context) ->
  group = context.group
  "Documents of " + group.displayName
, (context, callback) ->
  group = context.group
  group.getDocumentsStream callback
  return
, (context, principal, collection, callback) ->
  Step (->
    
    # Add the first few replies for each object
    firstFewReplies principal, collection.items, @parallel()
    
    # Add the first few replies for each object
    firstFewShares principal, collection.items, @parallel()
    
    # Add the first few "likers" for each object
    addLikers principal, collection.items, @parallel()
    
    # Add the shared flag for each object
    addShared principal, collection.items, @parallel()
    
    # Add the liked flag for each object
    addLiked principal, collection.items, @parallel()
    
    # Add the proxy URLs for each object
    addProxyObjects principal, collection.items, @parallel()
    return
  ), (err) ->
    callback err
    return

  return
)
groupInbox = activityFeed((context) ->
  group = context.group
  "api/group/" + group._uuid + "/inbox"
, (context) ->
  group = context.group
  "Activities for " + (group.displayName or "a group")
, (context, callback) ->
  group = context.group
  group.getInboxStream callback
  return
, majorFinishers)
exports.userStream = userStream
exports.userMajorStream = userMajorStream
exports.userMinorStream = userMinorStream
exports.userInbox = userInbox
exports.userMajorInbox = userMajorInbox
exports.userMinorInbox = userMinorInbox
exports.userDirectInbox = userDirectInbox
exports.userMajorDirectInbox = userMajorDirectInbox
exports.userMinorDirectInbox = userMinorDirectInbox
exports.userFollowers = userFollowers
exports.userFollowing = userFollowing
exports.userFavorites = userFavorites
exports.userUploads = userUploads
exports.objectLikes = objectLikes
exports.objectReplies = objectReplies
exports.objectShares = objectShares
exports.collectionMembers = collectionMembers
exports.userLists = userLists
exports.groupMembers = groupMembers
exports.groupInbox = groupInbox
exports.groupDocuments = groupDocuments
