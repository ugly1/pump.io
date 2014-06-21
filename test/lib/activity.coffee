# activity.js
#
# Test utilities for activities
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
assert = require("assert")
vows = require("vows")
validDate = (dt) ->
  assert.isString dt
  return

validActivity = (act) ->
  assert.isObject act
  assert.isFalse _.has(act, "_uuid")
  assert.include act, "id"
  assert.isString act.id
  assert.include act, "actor"
  assert.isObject act.actor
  assert.include act.actor, "id"
  assert.isString act.actor.id
  assert.include act.actor, "objectType"
  assert.isString act.actor.objectType
  assert.isString act.actor.displayName  if _.has(act.actor, "displayName")
  assert.isFalse _.has(act.actor, "_uuid")
  assert.include act, "verb"
  assert.isString act.verb
  assert.include act, "object"
  assert.isObject act.object
  assert.include act.object, "id"
  assert.isString act.object.id
  assert.include act.object, "objectType"
  assert.isString act.object.objectType
  assert.isFalse _.has(act.object, "_uuid")
  assert.include act, "published"
  assert.isString act.published
  assert.include act, "updated"
  assert.isString act.updated
  return

validActivityObject = (obj) ->
  assert.isObject obj
  assert.isFalse _.has(obj, "_uuid")
  assert.include obj, "id"
  assert.isString obj.id
  assert.include obj, "objectType"
  assert.isString obj.objectType
  assert.isString obj.displayName  if _.has(obj, "displayName")
  validDate obj.published  if _.has(obj, "published")
  if _.has(obj, "attachments")
    assert.isArray obj.attachments
    _.each obj.attachments, (attachment) ->
      validActivityObject attachment
      return

  validActivityObject obj.author  if _.has(obj, "author")
  assert.isString obj.content  if _.has(obj, "content")
  if _.has(obj, "downstreamDuplicates")
    assert.isArray obj.downstreamDuplicates
    _.each obj.downstreamDuplicates, (url) ->
      assert.isString url
      return

  validMediaLink obj.image  if _.has(obj, "image")
  assert.isString obj.summary  if _.has(obj, "summary")
  if _.has(obj, "upstreamDuplicates")
    assert.isArray obj.upstreamDuplicates
    _.each obj.upstreamDuplicates, (url) ->
      assert.isString url
      return

  validDate obj.updated  if _.has(obj, "updated")
  assert.isString obj.url  if _.has(obj, "url")
  return

validMediaLink = (ml) ->
  assert.isObject ml
  assert.include ml, "url"
  assert.isString ml.url
  assert.isNumber ml.width  if _.has(ml, "width")
  assert.isNumber ml.height  if _.has(ml, "height")
  assert.isNumber ml.duration  if _.has(ml, "duration")
  return

validFeed = (feed) ->
  assert.include feed, "url"
  assert.isString feed.url
  assert.include feed, "totalItems"
  assert.isNumber feed.totalItems
  assert.isArray feed.items  if _.has(feed, "items")
  return

validUser = (user) ->
  assert.isString user.nickname
  assert.isObject user.profile
  validActivityObject user.profile
  return

exports.validActivity = validActivity
exports.validActivityObject = validActivityObject
exports.validMediaLink = validMediaLink
exports.validFeed = validFeed
exports.validUser = validUser
