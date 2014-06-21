# repair-user-profile-test.js
#
# Test automatic repair of user profile data
#
# Copyright 2013, E14N https://e14n.com/
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
fs = require("fs")
path = require("path")
urlparse = require("url").parse
assert = require("assert")
vows = require("vows")
databank = require("databank")
_ = require("underscore-contrib")
Step = require("step")
Activity = require("../lib/model/activity").Activity
User = require("../lib/model/user").User
Person = require("../lib/model/person").Person
schema = require("../lib/schema").schema
URLMaker = require("../lib/urlmaker").URLMaker
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("automatic repair of user profile")
tc = JSON.parse(fs.readFileSync(path.resolve(__dirname, "config.json")))
suite.addBatch "When we set up the app":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect tc.params, (err) ->
      mod = undefined
      if err
        cb err, null
      else
        DatabankObject.bank = db
        cb null, db
      return

    return

  "it works": (err, db) ->
    assert.ifError err
    assert.isObject db
    return

  teardown: (db) ->
    if _.isObject(db) and _.isFunction(db.disconnect)
      db.disconnect (err) ->

    return

  "and we get a profile with bad standard feeds":
    topic: (db) ->
      user = undefined
      Step (->
        props =
          nickname: "george"
          password: "flat-top1"

        User.create props, this
        return
      ), ((err, results) ->
        profile = undefined
        throw err  if err
        user = results
        profile = user.profile
        profile.replies = url: "http://example.com/api/person/AAAAAAAA/replies"
        profile.likes = url: "http://example.com/api/person/AAAAAAAA/likes"
        profile.shares = url: "http://example.com/api/person/AAAAAAAA/shares"
        
        # Note: we're routing around the Person 
        db.update "person", profile.id, profile, this
        return
      ), ((err, results) ->
        throw err  if err
        Person.get results.id, this
        return
      ), @callback
      return

    "the feeds are automatically corrected": (err, person) ->
      assert.ifError err
      assert.equal urlparse(person.replies.url).hostname, "example.net"
      assert.equal urlparse(person.likes.url).hostname, "example.net"
      assert.equal urlparse(person.shares.url).hostname, "example.net"
      return

  "and we get a profile with missing links":
    topic: (db) ->
      user = undefined
      Step (->
        props =
          nickname: "harold"
          password: "bad-haircut-4"

        User.create props, this
        return
      ), ((err, results) ->
        profile = undefined
        throw err  if err
        user = results
        profile = user.profile
        delete profile.links["activity-inbox"]

        delete profile.links["activity-outbox"]

        
        # Note: we're routing around the Person 
        db.update "person", profile.id, profile, this
        return
      ), ((err, results) ->
        throw err  if err
        Person.get results.id, this
        return
      ), @callback
      return

    "the feeds are automatically corrected": (err, person) ->
      assert.ifError err
      assert.isObject person
      assert.isObject person.links
      assert.isObject person.links["activity-inbox"]
      assert.equal urlparse(person.links["activity-inbox"].href).hostname, "example.net"
      assert.isObject person.links["activity-outbox"]
      assert.equal urlparse(person.links["activity-outbox"].href).hostname, "example.net"
      return

suite["export"] module
