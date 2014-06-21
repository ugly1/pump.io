# lib/objectmiddleware.js
#
# Useful middleware for working with routes like :type/:uuid
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
_ = require("underscore")
Step = require("step")
HTTPError = require("../lib/httperror").HTTPError
ActivityObject = require("../lib/model/activityobject").ActivityObject
Activity = require("../lib/model/activity").Activity
requestObject = (req, res, next) ->
  type = req.params.type
  uuid = req.params.uuid
  Cls = undefined
  obj = null
  if _.contains(ActivityObject.objectTypes, type) or type is "other"
    req.type = type
  else
    next new HTTPError("Unknown type: " + type, 404)
    return
  Cls = ActivityObject.toClass(type)
  Cls.search
    _uuid: uuid
  , (err, results) ->
    if err
      next err
    else if results.length is 0
      next new HTTPError("Can't find a " + type + " with ID = " + uuid, 404)
    else if results.length > 1
      next new HTTPError("Too many " + type + " objects with ID = " + req.params.uuid, 500)
    else
      obj = results[0]
      if obj.hasOwnProperty("deleted")
        next new HTTPError("Deleted", 410)
      else
        obj.expand (err) ->
          if err
            next err
          else
            req[type] = obj
            next()
          return

    return

  return


# Uses the query parameter "id=" to find the object, rather than the UUID
requestObjectByID = (req, res, next) ->
  type = req.params.type
  id = req.query.id
  Cls = undefined
  obj = null
  if _.contains(ActivityObject.objectTypes, type) or type is "other"
    req.type = type
  else
    next new HTTPError("Unknown type: " + type, 404)
    return
  unless id
    next new HTTPError("'id' required", 400)
    return
  Cls = ActivityObject.toClass(type)
  Cls.get id, (err, obj) ->
    if err
      req.log.error
        err: err
      , "Error getting object by ID."
      if err.name is "NoSuchThingError"
        next new HTTPError("Can't find a " + type + " with ID = " + id, 404)
      else
        next new HTTPError("Error retrieving " + id, 400)
    else if obj.hasOwnProperty("deleted")
      next new HTTPError("Deleted", 410)
    else
      obj.expand (err) ->
        if err
          next err
        else
          req[type] = obj
          next()
        return

    return

  return

authorOnly = (req, res, next) ->
  type = req.type
  obj = req[type]
  if obj and obj.author and obj.author.id is req.principal.id
    next()
  else
    next new HTTPError("Only the author can modify this object.", 403)
  return

authorOrRecipient = (req, res, next) ->
  type = req.type
  obj = req[type]
  person = req.principal
  if obj and obj.author and person and obj.author.id is person.id
    next()
  else
    Step (->
      Activity.postOf obj, this
      return
    ), ((err, act) ->
      throw err  if err
      unless act
        next new HTTPError("No authorization for this object.", 403)
      else
        act.checkRecipient person, this
      return
    ), (err, isRecipient) ->
      if err
        next err
      else if isRecipient
        next()
      else
        next new HTTPError("Only the author and recipients can view this object.", 403)
      return

  return

principalActorOrRecipient = (req, res, next) ->
  person = req.principal
  activity = req.activity
  if activity and activity.actor and person and activity.actor.id is person.id
    next()
  else
    Step (->
      activity.checkRecipient person, this
      return
    ), (err, isRecipient) ->
      if err
        next err
      else if isRecipient
        next()
      else unless req.principal
        res.redirect "/main/login?continue=" + req.url
      else
        next new HTTPError("Only the author and recipients can view this activity.", 403)
      return

  return

principalAuthorOrRecipient = (req, res, next) ->
  type = req.type
  obj = req[type]
  person = req.principal
  if obj and obj.author and person and obj.author.id is person.id
    next()
  else
    Step (->
      Activity.postOf obj, this
      return
    ), ((err, act) ->
      throw err  if err
      unless act
        next new HTTPError("No authorization for this object.", 403)
      else
        act.checkRecipient person, this
      return
    ), (err, isRecipient) ->
      if err
        next err
      else if isRecipient
        next()
      else unless req.principal
        res.redirect "/main/login?continue=" + req.url
      else
        next new HTTPError("Only the author and recipients can view this object.", 403)
      return

  return

exports.requestObject = requestObject
exports.requestObjectByID = requestObjectByID
exports.authorOnly = authorOnly
exports.authorOrRecipient = authorOrRecipient
exports.principalActorOrRecipient = principalActorOrRecipient
exports.principalAuthorOrRecipient = principalAuthorOrRecipient
