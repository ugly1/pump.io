# membership-test.js
#
# Test the membership module
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
Step = require("step")
assert = require("assert")
vows = require("vows")
databank = require("databank")
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("membership module interface")
testSchema =
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

testData =
  create:
    member:
      id: "http://example.org/people/evan"
      displayName: "Evan Prodromou"
      objectType: "person"

    group:
      id: "urn:uuid:28fd8a40-adb4-11e2-9cbe-2c8158efb9e9"
      displayName: "pump.io hackers"
      objectType: "group"

  update:
    type: "early" # XXX: is there a real reason to update...?


# XXX: hack hack hack
# modelBatch hard-codes ActivityObject-style
mb = modelBatch("membership", "Membership", testSchema, testData)
mb["When we require the membership module"]["and we get its Membership class export"]["and we create a membership instance"]["auto-generated fields are there"] = (err, created) ->
  assert.isString created.id
  assert.isString created.published
  assert.isString created.updated
  return

suite.addBatch mb
suite.addBatch "When we get the Membership class":
  topic: ->
    require("../lib/model/membership").Membership

  "it exists": (Membership) ->
    assert.isFunction Membership
    return

  "it has an id() method": (Membership) ->
    assert.isFunction Membership.id
    return

  "it has an isMember() method": (Membership) ->
    assert.isFunction Membership.isMember
    return

  "and we get a new id":
    topic: (Membership) ->
      from = "http://example.com/user/1"
      to = "http://example.net/group/35"
      Membership.id from, to

    "it is a string": (id) ->
      assert.isString id
      return

  "and we check for a membership that doesn't exist":
    topic: (Membership) ->
      Person = require("../lib/model/person").Person
      Group = require("../lib/model/group").Group
      person = new Person(id: "http://example.com/user/2")
      group = new Group(id: "http://example.net/group/42")
      Membership.isMember person, group, @callback
      return

    "it is false": (err, isMember) ->
      assert.ifError err
      assert.isFalse isMember
      return

  "and we check for a membership that exists":
    topic: (Membership) ->
      Person = require("../lib/model/person").Person
      Group = require("../lib/model/group").Group
      person = new Person(
        id: "http://example.com/user/3"
        objectType: "person"
      )
      group = new Group(
        id: "http://example.net/group/23"
        objectType: "group"
      )
      callback = @callback
      Step (->
        Membership.create
          member: person
          group: group
        , this
        return
      ), ((err, ship) ->
        throw err  if err
        Membership.isMember person, group, this
        return
      ), callback
      return

    "it is true": (err, isMember) ->
      assert.ifError err
      assert.isTrue isMember
      return

suite["export"] module
