# group.js
#
# data object representing an group
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
DatabankObject = require("databank").DatabankObject
wf = require("webfinger")
ActivityObject = require("./activityobject").ActivityObject
Stream = require("./stream").Stream
Step = require("step")
_ = require("underscore")
URLMaker = require("../urlmaker").URLMaker
Group = DatabankObject.subClass("group", ActivityObject)
Group.schema = ActivityObject.subSchema([
  "attachments"
  "inReplyTo"
], ["members"])

# Before creation, add a link to the activity inbox
Group.beforeCreate = (props, callback) ->
  cls = this
  Step (->
    ActivityObject.beforeCreate.apply cls, [
      props
      this
    ]
    return
  ), ((err, props) ->
    throw err  if err
    Group.isLocal props, this
    return
  ), (err, isLocal) ->
    if err
      callback err, null
    else
      if isLocal
        if props._foreign_id
          props.members = url: URLMaker.makeURL("api/group/members",
            id: props.id
          )
          props.documents = url: URLMaker.makeURL("api/group/documents",
            id: props.id
          )
          props.links["activity-inbox"] = href: URLMaker.makeURL("api/group/inbox",
            id: props.id
          )
        else
          props.members = url: URLMaker.makeURL("api/group/" + props._uuid + "/members")
          props.documents = url: URLMaker.makeURL("api/group/" + props._uuid + "/documents")
          props.links["activity-inbox"] = href: URLMaker.makeURL("api/group/" + props._uuid + "/inbox")
      callback null, props
    return

  return


# After creation, for local groups, create a members stream
Group::afterCreate = (callback) ->
  group = this
  Step (->
    ActivityObject::afterCreate.apply group, [this]
    return
  ), ((err) ->
    throw err  if err
    group.isLocal this
    return
  ), ((err, loc) ->
    throw err  if err
    unless loc
      callback null
    else
      Stream.create
        name: group.membersStreamName()
      , @parallel()
      Stream.create
        name: group.inboxStreamName()
      , @parallel()
      Stream.create
        name: group.documentsStreamName()
      , @parallel()
    return
  ), (err, members, inbox) ->
    if err
      callback err
    else
      callback null
    return

  return


# Test for lack of members
Group::afterGet = (callback) ->
  group = this
  Upgrader = require("../upgrader")
  
  # Perform automated upgrades at read-time
  Upgrader.upgradeGroup group, callback
  return


# Test to see if a group is local
Group::isLocal = (callback) ->
  group = this
  Group.isLocal group, callback
  return


# Class method so we can pass either an instance or a regular Object
Group.isLocal = (props, callback) ->
  User = require("./user").User
  if not props.author or not props.author.id
    callback null, false
    return
  Step (->
    User.fromPerson props.author.id, this
    return
  ), (err, user) ->
    if err
      callback err, null
    else
      callback null, !!user
    return

  return


# Add the extra feeds properties to an activity object. For groups, we have a
# members feed.
Group::expandFeeds = (callback) ->
  group = this
  Step (->
    group.isLocal this
    return
  ), ((err, isLocal) ->
    throw err  if err
    unless isLocal
      callback null
    else
      group.getMembersStream @parallel()
      group.getDocumentsStream @parallel()
    return
  ), ((err, members, documents) ->
    throw err  if err
    members.count @parallel()
    documents.count @parallel()
    return
  ), (err, membersCount, documentsCount) ->
    if err
      callback err
    else
      group.members.totalItems = membersCount
      group.documents.totalItems = documentsCount
      callback null
    return

  return


# Get the name of the stream used for this object's members.
# Just some boilerplate to avoid typos.
Group::membersStreamName = ->
  group = this
  "group:" + group._uuid + ":members"


# Get the stream of this object's members.
Group::getMembersStream = (callback) ->
  group = this
  Stream.get group.membersStreamName(), callback
  return


# Get the name of the stream used for this groups's documents
Group::documentsStreamName = ->
  group = this
  "group:" + group._uuid + ":documents"


# Get the stream of this group's documents
Group::getDocumentsStream = (callback) ->
  group = this
  Step (->
    Stream.get group.documentsStreamName(), this
    return
  ), ((err, str) ->
    unless err
      callback null, str
    else if err and err.name is "NoSuchThingError"
      Stream.create
        name: group.documentsStreamName()
      , this
    else callback err, null  if err
    return
  ), (err, str) ->
    unless err
      callback null, str
    else if err and err.name is "AlreadyExistsError"
      
      # Try again from the top
      group.getDocumentStream callback
    else callback err, null  if err
    return

  return


# Get the name of the stream used for this object's inbox.
# Just some boilerplate to avoid typos.
Group::inboxStreamName = ->
  group = this
  "group:" + group._uuid + ":inbox"


# Get the stream of this object's inbox.
Group::getInboxStream = (callback) ->
  group = this
  Stream.get group.inboxStreamName(), callback
  return

Group::getInbox = (callback) ->
  group = this
  Step (->
    wf.webfinger group.id, this
    return
  ), (err, jrd) ->
    inboxes = undefined
    if err
      callback err, null
      return
    else if not _(jrd).has("links") or not _(jrd.links).isArray()
      callback new Error("Can't get inbox for " + group.id), null
      return
    else
      
      # Get the inboxes
      inboxes = jrd.links.filter((link) ->
        link.hasOwnProperty("rel") and link.rel is "activity-inbox" and link.hasOwnProperty("href")
      )
      if inboxes.length is 0
        callback new Error("Can't get inbox for " + group.id), null
        return
      callback null, inboxes[0].href
    return

  return

Group::beforeUpdate = (props, callback) ->
  group = this
  Step (->
    ActivityObject::beforeUpdate.apply group, [
      props
      this
    ]
    return
  ), (err, props) ->
    if err
      callback err, null
    else
      
      # Trim them if they existed before
      ActivityObject.trimCollection props, "members"
      callback null, props
    return

  return

Group::beforeSave = (callback) ->
  group = this
  Step (->
    ActivityObject::beforeSave.apply group, [this]
    return
  ), (err) ->
    if err
      callback err
    else
      
      # Trim them if they existed before
      ActivityObject.trimCollection group, "members"
      callback null
    return

  return

exports.Group = Group
