# membership.js
#
# A membership by a person in a group
#
# Copyright 2013 E14N https://e14n.com/
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
Step = require("step")
DatabankObject = require("databank").DatabankObject
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
_ = require("underscore")
Membership = DatabankObject.subClass("membership")
exports.Membership = Membership
Membership.schema =
  pkey: "id"
  fields: [
    "member"
    "group"
    "published"
    "updated"
  ]
  indices: [
    "member.id"
    "group.id"
  ]


# Helper to create a compliant and unique membership ID
Membership.id = (memberId, groupId) ->
  memberId + "∈" + groupId


# Before creation, check that member and group are reasonable
# and compress them. Also, timestamp for published/updated.
Membership.beforeCreate = (props, callback) ->
  now = Stamper.stamp()
  oldMember = undefined
  oldGroup = undefined
  if not _(props).has("member") or not _(props.member).has("id") or not _(props.member).has("objectType") or not _(props).has("group") or not _(props.group).has("id") or not _(props.group).has("objectType")
    callback new Error("Invalid Membership"), null
    return
  props.published = props.updated = now
  props.id = Membership.id(props.member.id, props.group.id)
  oldMember = props.member
  props.member =
    id: oldMember.id
    objectType: oldMember.objectType

  oldGroup = props.group
  props.group =
    id: oldGroup.id
    objectType: oldGroup.objectType

  callback null, props
  return


# Before update, discard immutable properties,
# and add an update timestamp.
Membership::beforeUpdate = (props, callback) ->
  immutable = [
    "member"
    "group"
    "id"
    "published"
  ]
  i = undefined
  prop = undefined
  i = 0
  while i < immutable.length
    prop = immutable[i]
    delete props[prop]  if _(props).has(prop)
    i++
  now = Stamper.stamp()
  props.updated = now
  callback null, props
  return


# Save is a little bit create, a little bit update.
Membership::beforeSave = (callback) ->
  ship = this
  oldMember = undefined
  oldGroup = undefined
  if not _(ship).has("member") or not _(ship.member).has("id") or not _(ship.member).has("objectType") or not _(ship).has("group") or not _(ship.group).has("id") or not _(ship.group).has("objectType")
    callback new Error("Invalid Membership"), null
    return
  now = Stamper.stamp()
  ship.updated = now
  
  # This is how we can tell it's new.
  unless _(ship).has("id")
    ship.id = Membership.id(ship.member.id, ship.group.id)
    ship.published = now  unless _(ship).has("published")
  oldMember = ship.member
  ship.member =
    id: oldMember.id
    objectType: oldMember.objectType

  oldGroup = ship.group
  ship.group =
    id: oldGroup.id
    objectType: oldGroup.objectType

  callback null
  return


# Utility to determine if a person is a member of a group
Membership.isMember = (person, group, callback) ->
  Step (->
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
