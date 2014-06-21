# activity-test.js
#
# Test the activity module
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
assert = require("assert")
vows = require("vows")
databank = require("databank")
Step = require("step")
_ = require("underscore")
fs = require("fs")
path = require("path")
URLMaker = require("../lib/urlmaker").URLMaker
schema = require("../lib/schema").schema
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("activity module interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
testSchema =
  pkey: "id"
  fields: [
    "actor"
    "content"
    "generator"
    "icon"
    "id"
    "object"
    "published"
    "provider"
    "target"
    "title"
    "url"
    "_uuid"
    "to"
    "cc"
    "bto"
    "bcc"
    "_received"
    "updated"
    "verb"
  ]
  indices: [
    "actor.id"
    "object.id"
    "_uuid"
  ]

testData =
  create:
    actor:
      id: "urn:uuid:8f64087d-fffc-4fe0-9848-c18ae611cafd"
      displayName: "Delbert Fnorgledap"
      objectType: "person"

    verb: "post"
    object:
      id: "urn:uuid:9c9bbb2e-ddb7-11e2-abe4-2c8158efb9e9"
      objectType: "note"
      content: "Feeling groovy."

  update:
    mood:
      displayName: "groovy"

testVerbs = [
  "accept"
  "access"
  "acknowledge"
  "add"
  "agree"
  "append"
  "approve"
  "archive"
  "assign"
  "at"
  "attach"
  "attend"
  "author"
  "authorize"
  "borrow"
  "build"
  "cancel"
  "close"
  "complete"
  "confirm"
  "consume"
  "checkin"
  "close"
  "create"
  "delete"
  "deliver"
  "deny"
  "disagree"
  "dislike"
  "experience"
  "favorite"
  "find"
  "follow"
  "give"
  "host"
  "ignore"
  "insert"
  "install"
  "interact"
  "invite"
  "join"
  "leave"
  "like"
  "listen"
  "lose"
  "make-friend"
  "open"
  "play"
  "post"
  "present"
  "purchase"
  "qualify"
  "read"
  "receive"
  "reject"
  "remove"
  "remove-friend"
  "replace"
  "request"
  "request-friend"
  "resolve"
  "return"
  "retract"
  "rsvp-maybe"
  "rsvp-no"
  "rsvp-yes"
  "satisfy"
  "save"
  "schedule"
  "search"
  "sell"
  "send"
  "share"
  "sponsor"
  "start"
  "stop-following"
  "submit"
  "tag"
  "terminate"
  "tie"
  "unfavorite"
  "unlike"
  "unsatisfy"
  "unsave"
  "unshare"
  "update"
  "use"
  "watch"
  "win"
]
mb = modelBatch("activity", "Activity", testSchema, testData)
mb["When we require the activity module"]["and we get its Activity class export"]["and we create an activity instance"]["auto-generated fields are there"] = (err, created) ->
  assert.isString created.id
  assert.isString created._uuid
  assert.isString created.published
  assert.isString created.updated
  assert.isObject created.links
  assert.isObject created.links.self
  assert.isString created.links.self.href
  return


# Since actor, object will have some auto-created stuff, we only
# check that their attributes match
mb["When we require the activity module"]["and we get its Activity class export"]["and we create an activity instance"]["passed-in fields are there"] = (err, created) ->
  prop = undefined
  orig = testData.create
  child = undefined
  cprop = undefined
  for prop of _(orig).keys()
    if _.isObject(orig[prop])
      assert.include created, prop
      child = orig[prop]
      for cprop of _(child).keys()
        assert.include created[prop], cprop
        assert.equal created[prop][cprop], child[cprop]
    else
      assert.equal created[prop], orig[prop]
  return

suite.addBatch mb
suite.addBatch "When we get the Activity class":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      mod = undefined
      if err
        cb err, null
        return
      DatabankObject.bank = db
      mod = require("../lib/model/activity")
      unless mod
        cb new Error("No module"), null
        return
      cb null, mod.Activity
      return

    return

  "it works": (err, Activity) ->
    assert.ifError err
    assert.isFunction Activity
    return

  "it has the right verbs": (err, Activity) ->
    i = undefined
    assert.isArray Activity.verbs
    i = 0
    while i < testVerbs.length
      assert.includes Activity.verbs, testVerbs[i]
      i++
    i = 0
    while i < Activity.verbs.length
      assert.includes testVerbs, Activity.verbs[i]
      i++
    return

  "it has a const-like member for each verb": (err, Activity) ->
    i = undefined
    verb = undefined
    name = undefined
    i = 0
    while i < testVerbs.length
      verb = testVerbs[i]
      name = verb.toUpperCase().replace("-", "_")
      assert.equal Activity[name], verb
      i++
    return

  "it has a postOf() class method": (err, Activity) ->
    assert.isFunction Activity.postOf
    return

  "and we create an instance":
    topic: (Activity) ->
      new Activity({})

    "it has the expand() method": (activity) ->
      assert.isFunction activity.expand
      return

    "it has the sanitize() method": (activity) ->
      assert.isFunction activity.sanitize
      return

    "it has the checkRecipient() method": (activity) ->
      assert.isFunction activity.checkRecipient
      return

    "it has the recipients() method": (activity) ->
      assert.isFunction activity.recipients
      return

    "it has the isMajor() method": (activity) ->
      assert.isFunction activity.isMajor
      return

    "it has the addReceived() method": (activity) ->
      assert.isFunction activity.addReceived
      return

  "and we apply() a new post activity":
    topic: (Activity) ->
      cb = @callback
      act = new Activity(
        actor:
          id: "urn:uuid:8f64087d-fffc-4fe0-9848-c18ae611cafd"
          displayName: "Delbert Fnorgledap"
          objectType: "person"

        verb: "post"
        object:
          objectType: "note"
          content: "Feeling groovy."
      )
      act.apply null, (err) ->
        if err
          cb err, null
        else
          cb null, act
        return

      return

    "it works": (err, activity) ->
      assert.ifError err
      assert.isObject activity
      return

    "and we fetch its object":
      topic: (activity) ->
        Note = require("../lib/model/note").Note
        Note.get activity.object.id, @callback
        return

      "it exists": (err, note) ->
        assert.ifError err
        assert.isObject note
        return

      "it has the right author": (err, note) ->
        assert.equal note.author.id, "urn:uuid:8f64087d-fffc-4fe0-9848-c18ae611cafd"
        return

    "and we save() the activity":
      topic: (activity) ->
        cb = @callback
        activity.save (err) ->
          if err
            cb err, null
          else
            cb null, activity
          return

        return

      "it works": (err, activity) ->
        assert.ifError err
        assert.isObject activity
        assert.instanceOf activity, require("../lib/model/activity").Activity
        return

      "its object properties have ids": (err, activity) ->
        assert.isString activity.actor.id
        assert.isString activity.object.id
        return

      "its object properties are objects": (err, activity) ->
        assert.isObject activity.actor
        assert.instanceOf activity.actor, require("../lib/model/person").Person
        assert.isObject activity.object
        assert.instanceOf activity.object, require("../lib/model/note").Note
        return

      "its object properties are expanded": (err, activity) ->
        assert.isString activity.actor.displayName
        assert.isString activity.object.content
        return

      "its object property has a likes property": (err, activity) ->
        assert.ifError err
        assert.includes activity.object, "likes"
        assert.isObject activity.object.likes
        assert.includes activity.object.likes, "totalItems"
        assert.isNumber activity.object.likes.totalItems
        assert.includes activity.object.likes, "url"
        assert.isString activity.object.likes.url
        return

      "and we get the stored activity":
        topic: (saved, activity, Activity) ->
          Activity.get activity.id, @callback
          return

        "it works": (err, copy) ->
          assert.ifError err
          assert.isObject copy
          return

        "its object properties are expanded": (err, activity) ->
          assert.isString activity.actor.displayName
          assert.isString activity.object.content
          return

        "its object properties are objects": (err, activity) ->
          assert.isObject activity.actor
          assert.instanceOf activity.actor, require("../lib/model/person").Person
          assert.isObject activity.object
          assert.instanceOf activity.object, require("../lib/model/note").Note
          return

        "its object property has a likes property": (err, activity) ->
          assert.ifError err
          assert.includes activity.object, "likes"
          assert.isObject activity.object.likes
          assert.includes activity.object.likes, "totalItems"
          assert.isNumber activity.object.likes.totalItems
          assert.includes activity.object.likes, "url"
          assert.isString activity.object.likes.url
          return

  "and we apply() a new follow activity":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      users = {}
      cb = @callback
      Step (->
        User.create
          nickname: "alice"
          password: "funky_monkey"
        , this
        return
      ), ((err, alice) ->
        throw err  if err
        users.alice = alice
        User.create
          nickname: "bob"
          password: "bob*1234"
        , this
        return
      ), ((err, bob) ->
        throw err  if err
        users.bob = bob
        act = new Activity(
          actor: users.alice.profile
          verb: "follow"
          object: users.bob.profile
        )
        act.apply users.alice.profile, this
        return
      ), (err) ->
        if err
          cb err, null
        else
          cb null, users
        return

      return

    teardown: (users) ->
      Step (->
        users.alice.del @parallel()
        users.bob.del @parallel()
        return
      ), (err) ->

      return

    
    # ignore
    "it works": (err, users) ->
      assert.ifError err
      assert.isObject users
      assert.isObject users.alice
      assert.isObject users.bob
      return

    "and we check the follow lists":
      topic: (users) ->
        cb = @callback
        following = undefined
        followers = undefined
        Step (->
          users.alice.getFollowing 0, 20, this
          return
        ), ((err, results) ->
          throw err  if err
          following = results
          users.bob.getFollowers 0, 20, this
          return
        ), (err, results) ->
          if err
            cb err, null
          else
            followers = results
            cb err,
              users: users
              following: following
              followers: followers

          return

        return

      "it works": (err, res) ->
        assert.ifError err
        return

      "following list is correct": (err, res) ->
        assert.isArray res.following
        assert.lengthOf res.following, 1
        assert.equal res.following[0].id, res.users.bob.profile.id
        return

      "followers list is correct": (err, res) ->
        assert.isArray res.followers
        assert.lengthOf res.followers, 1
        assert.equal res.followers[0].id, res.users.alice.profile.id
        return

      "and we apply() a stop-following activity":
        topic: (res, users, Activity) ->
          act = new Activity(
            actor: users.alice.profile
            verb: "stop-following"
            object: users.bob.profile
          )
          act.apply users.alice.profile, @callback
          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we check for the follow lists again":
          topic: (res, users) ->
            cb = @callback
            following = undefined
            followers = undefined
            Step (->
              users.alice.getFollowing 0, 20, this
              return
            ), ((err, results) ->
              throw err  if err
              following = results
              users.bob.getFollowers 0, 20, this
              return
            ), (err, results) ->
              if err
                cb err, null
              else
                followers = results
                cb err,
                  users: users
                  following: following
                  followers: followers

              return

            return

          "it works": (err, res) ->
            assert.ifError err
            return

          "following list is correct": (err, res) ->
            assert.isArray res.following
            assert.lengthOf res.following, 0
            return

          "followers list is correct": (err, res) ->
            assert.isArray res.followers
            assert.lengthOf res.followers, 0
            return

  "and we sanitize() an activity for the actor":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      user = undefined
      cb = @callback
      Step (->
        User.create
          nickname: "charlie"
          password: "one two three four five six"
        , this
        return
      ), ((err, result) ->
        act = undefined
        throw err  if err
        user = result
        act =
          actor: user.profile
          verb: "post"
          bto: [
            objectType: "person"
            id: "urn:uuid:b59554e4-e576-11e1-b0ff-5cff35050cf2"
          ]
          bcc: [
            objectType: "person"
            id: "urn:uuid:c456d228-e576-11e1-89dd-5cff35050cf2"
          ]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), (err, act) ->
        if err
          cb err, null
        else
          act.sanitize user.profile
          cb err, act
        return

      return

    "it works": (err, act) ->
      assert.ifError err
      assert.isObject act
      return

    "uuid is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("_uuid")
      return

    "bcc is visible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isTrue act.hasOwnProperty("bcc")
      return

    "bto is visible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isTrue act.hasOwnProperty("bto")
      return

  "and we sanitize() an activity for another user":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      user1 = undefined
      user2 = undefined
      cb = @callback
      Step (->
        User.create
          nickname: "david"
          password: "fig*leaf"
        , @parallel()
        User.create
          nickname: "ethel"
          password: "Mer-man!"
        , @parallel()
        return
      ), ((err, result1, result2) ->
        act = undefined
        throw err  if err
        user1 = result1
        user2 = result2
        act =
          actor: user1.profile
          verb: "post"
          bto: [
            objectType: "person"
            id: "urn:uuid:b59554e4-e576-11e1-b0ff-5cff35050cf2"
          ]
          bcc: [
            objectType: "person"
            id: "urn:uuid:c456d228-e576-11e1-89dd-5cff35050cf2"
          ]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), (err, act) ->
        if err
          cb err, null
        else
          act.sanitize user2.profile
          cb err, act
        return

      return

    "it works": (err, act) ->
      assert.ifError err
      assert.isObject act
      return

    "uuid is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("_uuid")
      return

    "bcc is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("bcc")
      return

    "bto is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("bto")
      return

  "and we sanitize() an activity for anonymous user":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      cb = @callback
      Step (->
        User.create
          nickname: "frank"
          password: "N. Stein"
        , this
        return
      ), ((err, user) ->
        act = undefined
        throw err  if err
        act =
          actor: user.profile
          verb: "post"
          bto: [
            objectType: "person"
            id: "urn:uuid:b59554e4-e576-11e1-b0ff-5cff35050cf2"
          ]
          bcc: [
            objectType: "person"
            id: "urn:uuid:c456d228-e576-11e1-89dd-5cff35050cf2"
          ]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), (err, act) ->
        if err
          cb err, null
        else
          act.sanitize()
          cb err, act
        return

      return

    "it works": (err, act) ->
      assert.ifError err
      assert.isObject act
      return

    "uuid is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("_uuid")
      return

    "bcc is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("bcc")
      return

    "bto is invisible": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isFalse act.hasOwnProperty("bto")
      return

  "and we check if a direct addressee is a recipient":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      cb = @callback
      p1 =
        objectType: "person"
        id: "urn:uuid:f58c37a4-e5c9-11e1-9613-70f1a154e1aa"

      p2 =
        objectType: "person"
        id: "urn:uuid:b59554e4-e576-11e1-b0ff-5cff35050cf2"

      Step (->
        act =
          actor: p1
          verb: "post"
          to: [p2]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient p2, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns true": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isTrue isRecipient
      return

  "and we check if empty user is a recipient of a public activity":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      Collection = require("../lib/model/collection").Collection
      cb = @callback
      p1 =
        objectType: "person"
        id: "urn:uuid:7bb4c51a-e88d-11e1-b9d8-0024beb67924"

      p2 =
        objectType: "collection"
        id: Collection.PUBLIC

      Step (->
        act =
          actor: p1
          verb: "post"
          to: [p2]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient null, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns true": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isTrue isRecipient
      return

  "and we check if a random user is a recipient of a public activity":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      Collection = require("../lib/model/collection").Collection
      cb = @callback
      p1 =
        objectType: "person"
        id: "urn:uuid:c123c0d0-e89a-11e1-89fa-0024beb67924"

      p2 =
        objectType: "collection"
        id: Collection.PUBLIC

      p3 =
        objectType: "person"
        id: "urn:uuid:c48045a0-e89a-11e1-a855-0024beb67924"

      Step (->
        act =
          actor: p1
          verb: "post"
          to: [p2]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient p3, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns true": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isTrue isRecipient
      return

  "and we check if a random person is a recipient of a directed activity":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      cb = @callback
      p1 =
        objectType: "person"
        id: "urn:uuid:f931e182-e5ca-11e1-af82-70f1a154e1aa"

      p2 =
        objectType: "person"
        id: "urn:uuid:f9325900-e5ca-11e1-bbc3-70f1a154e1aa"

      p3 =
        objectType: "person"
        id: "urn:uuid:f932cd0e-e5ca-11e1-8e1e-70f1a154e1aa"

      Step (->
        act =
          actor: p1
          verb: "post"
          to: [p2]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient p3, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns false": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isFalse isRecipient
      return

  "and we check if a list member is a recipient of an activity sent to a list":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      Collection = require("../lib/model/collection").Collection
      cb = @callback
      user1 = undefined
      user2 = undefined
      list = undefined
      Step (->
        props1 =
          nickname: "pat"
          password: "the*bunny"

        props2 =
          nickname: "tap"
          password: "i|would|tap|that"

        User.create props1, @parallel()
        User.create props2, @parallel()
        return
      ), ((err, result1, result2) ->
        throw err  if err
        user1 = result1
        user2 = result2
        Collection.create
          author: user1.profile
          displayName: "Test 1"
          objectTypes: ["person"]
        , this
        return
      ), ((err, result) ->
        throw err  if err
        list = result
        list.getStream this
        return
      ), ((err, stream) ->
        val =
          id: user2.profile.id
          objectType: user2.profile.objectType

        throw err  if err
        stream.deliverObject val, this
        return
      ), ((err) ->
        throw err  if err
        act =
          actor: user1.profile
          verb: "post"
          to: [list]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient user2.profile, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns true": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isTrue isRecipient
      return

  "and we check if a list non-member is a recipient of an activity sent to a list":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      Collection = require("../lib/model/collection").Collection
      cb = @callback
      user1 = undefined
      user2 = undefined
      list = undefined
      Step (->
        props1 =
          nickname: "jim"
          password: "dandy,fella"

        props2 =
          nickname: "zed"
          password: "is*dead,baby"

        User.create props1, @parallel()
        User.create props2, @parallel()
        return
      ), ((err, result1, result2) ->
        throw err  if err
        user1 = result1
        user2 = result2
        Collection.create
          author: user1.profile
          displayName: "Test 1"
          objectTypes: ["person"]
        , this
        return
      ), ((err, result) ->
        throw err  if err
        list = result
        act =
          actor: user1.profile
          verb: "post"
          to: [list]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient user2.profile, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns false": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isFalse isRecipient
      return

  "and we check if a follower is a recipient of an activity sent to followers":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      cb = @callback
      user1 = undefined
      user2 = undefined
      Step (->
        props1 =
          nickname: "robert"
          password: "'srules!"

        props2 =
          nickname: "kevin"
          password: "*m1tn1ck*"

        User.create props1, @parallel()
        User.create props2, @parallel()
        return
      ), ((err, result1, result2) ->
        throw err  if err
        user1 = result1
        user2 = result2
        user2.follow user1, this
        return
      ), ((err) ->
        throw err  if err
        user1.profile.followersURL this
        return
      ), ((err, url) ->
        throw err  if err
        throw new Error("Bad URL")  unless url
        act =
          actor: user1.profile
          verb: "post"
          to: [
            objectType: "collection"
            id: url
          ]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient user2.profile, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns true": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isTrue isRecipient
      return

  "and we check if a non-follower is a recipient of an activity sent to followers":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      cb = @callback
      user1 = undefined
      user2 = undefined
      Step (->
        props1 =
          nickname: "steve"
          password: "mcqu33n."

        props2 =
          nickname: "keith"
          password: "r1ch4rds"

        User.create props1, @parallel()
        User.create props2, @parallel()
        return
      ), ((err, result1, result2) ->
        throw err  if err
        user1 = result1
        user2 = result2
        user1.profile.followersURL this
        return
      ), ((err, url) ->
        throw err  if err
        throw new Error("Bad URL")  unless url
        act =
          actor: user1.profile
          verb: "post"
          to: [
            objectType: "collection"
            id: url
          ]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient user2.profile, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns false": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isFalse isRecipient
      return

  "and we check if a list non-member is a recipient of an activity sent to a list":
    topic: (Activity) ->
      User = require("../lib/model/user").User
      Collection = require("../lib/model/collection").Collection
      cb = @callback
      user1 = undefined
      user2 = undefined
      list = undefined
      Step (->
        props1 =
          nickname: "jim"
          password: "dee*dee*dee"

        props2 =
          nickname: "zed"
          password: "over*my*head"

        User.create props1, @parallel()
        User.create props2, @parallel()
        return
      ), ((err, result1, result2) ->
        throw err  if err
        user1 = result1
        user2 = result2
        Collection.create
          author: user1.profile
          displayName: "Test 1"
          objectTypes: ["person"]
        , this
        return
      ), ((err, result) ->
        throw err  if err
        list = result
        act =
          actor: user1.profile
          verb: "post"
          to: [list]
          object:
            objectType: "note"
            content: "Hello, world!"

        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        act.checkRecipient user2.profile, this
        return
      ), cb
      return

    "it works": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      return

    "it returns false": (err, isRecipient) ->
      assert.ifError err
      assert.isBoolean isRecipient
      assert.isFalse isRecipient
      return

  "and we look for the post activity of a known object":
    topic: (Activity) ->
      Note = require("../lib/model/note").Note
      cb = @callback
      p1 =
        objectType: "person"
        id: "urn:uuid:bda39c62-e5d1-11e1-baf4-70f1a154e1aa"

      act = undefined
      Step (->
        act = new Activity(
          actor: p1
          verb: Activity.POST
          object:
            objectType: "note"
            content: "Hello, world!"
        )
        act.apply p1, this
        return
      ), ((err) ->
        throw err  if err
        act.save this
        return
      ), ((err, act) ->
        throw err  if err
        Note.get act.object.id, this
        return
      ), ((err, note) ->
        throw err  if err
        Activity.postOf note, this
        return
      ), (err, found) ->
        cb err, act, found
        return

      return

    "it works": (err, posted, found) ->
      assert.ifError err
      return

    "it finds the right activity": (err, posted, found) ->
      assert.ifError err
      assert.isObject posted
      assert.isObject found
      assert.equal posted.id, found.id
      return

  "and we look for the post activity of an unposted object":
    topic: (Activity) ->
      Note = require("../lib/model/note").Note
      cb = @callback
      Step (->
        Note.create
          content: "Hello, world."
        , this
        return
      ), ((err, note) ->
        throw err  if err
        Activity.postOf note, this
        return
      ), (err, found) ->
        if err
          cb err
        else if found
          cb new Error("Unexpected success")
        else
          cb null
        return

      return

    "it works": (err) ->
      assert.ifError err
      return

  "and we check if posting a note is major":
    topic: (Activity) ->
      act = new Activity(
        id: "85931c96-fa24-11e1-8bf3-70f1a154e1aa"
        actor:
          objectType: "person"
          displayName: "A. Person"
          id: "76c50ecc-fa24-11e1-bc3b-70f1a154e1aa"

        verb: "post"
        object:
          id: "aaf962f6-fa24-11e1-b0e6-70f1a154e1aa"
          objectType: "note"
          content: "Hello, world!"
      )
      act.isMajor()

    "it is major": (isMajor) ->
      assert.isTrue isMajor
      return

  "and we check if favoriting a note is major":
    topic: (Activity) ->
      act = new Activity(
        id: "076f1a4e-fa25-11e1-b51d-70f1a154e1aa"
        actor:
          objectType: "person"
          displayName: "A. Nother Person"
          id: "100c05ea-fa25-11e1-a634-70f1a154e1aa"

        verb: "favorite"
        object:
          id: "237a9998-fa25-11e1-9444-70f1a154e1aa"
          objectType: "note"
      )
      act.isMajor()

    "it is not major": (isMajor) ->
      assert.isFalse isMajor
      return

  "and we check if posting a comment is major":
    topic: (Activity) ->
      act = new Activity(
        id: "urn:uuid:076f1a4e-fa25-11e1-b51d-70f1a154e1aa"
        actor:
          objectType: "person"
          displayName: "Some Other Person"
          id: "urn:uuid:4d895fe2-01f2-11e2-a185-70f1a154e1aa"

        verb: "post"
        object:
          id: "urn:uuid:5d09e0f4-01f2-11e2-aa15-70f1a154e1aa"
          objectType: "comment"
      )
      act.isMajor()

    "it is not major": (isMajor) ->
      assert.isFalse isMajor
      return

  "and we check if creating a list is major":
    topic: (Activity) ->
      act = new Activity(
        id: "urn:uuid:385507e8-43dd-11e2-8e9b-2c8158efb9e9"
        actor:
          objectType: "person"
          displayName: "A. Nother Person"
          id: "urn:uuid:79768f4e-43dd-11e2-8cbf-2c8158efb9e9"

        verb: "create"
        object:
          id: "urn:uuid:87cf740c-43dd-11e2-ae8a-2c8158efb9e9"
          objectType: "collection"
          objectTypes: ["person"]
      )
      act.isMajor()

    "it is not major": (isMajor) ->
      assert.isFalse isMajor
      return

  "and we check if posting a list is major":
    topic: (Activity) ->
      act = new Activity(
        id: "urn:uuid:8f45a5a8-43dd-11e2-a389-2c8158efb9e9"
        actor:
          objectType: "person"
          displayName: "A. Nother Person"
          id: "urn:uuid:9444f0c2-43dd-11e2-ac26-2c8158efb9e9"

        verb: "post"
        object:
          id: "urn:uuid:9a6c6886-43dd-11e2-bd09-2c8158efb9e9"
          objectType: "collection"
          objectTypes: ["person"]
      )
      act.isMajor()

    "it is not major": (isMajor) ->
      assert.isFalse isMajor
      return

  "and we check if creating an image is major":
    topic: (Activity) ->
      act = new Activity(
        id: "urn:uuid:a5a0b220-43dd-11e2-9480-2c8158efb9e9"
        actor:
          objectType: "person"
          displayName: "A. Nother Person"
          id: "urn:uuid:aa9a9e76-43dd-11e2-8974-2c8158efb9e9"

        verb: "create"
        object:
          id: "urn:uuid:b779f4a2-43dd-11e2-8714-2c8158efb9e9"
          objectType: "image"
          displayName: "My dog"
      )
      act.isMajor()

    "it is major": (isMajor) ->
      assert.isTrue isMajor
      return


# Test that adding a receiver works
suite.addBatch "When we get the Activity class":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      mod = undefined
      if err
        cb err, null
        return
      DatabankObject.bank = db
      mod = require("../lib/model/activity")
      unless mod
        cb new Error("No module"), null
        return
      cb null, mod.Activity
      return

    return

  "it works": (err, Activity) ->
    assert.ifError err
    assert.isFunction Activity
    return

  "and we create an activity directed to a list":
    topic: (Activity) ->
      act =
        actor:
          id: "acct:juan@social.example"
          objectType: "person"

        to: [
          objectType: "collection"
          id: "http://social.example/api/collection/juan/friends"
        ]
        verb: "post"
        object:
          objectType: "note"
          content: "Hello, world!"

      Activity.create act, @callback
      return

    "it works": (err, activity) ->
      assert.ifError err
      return

    "and we add another recipient":
      topic: (activity) ->
        other =
          id: "acct:gerald@photo.example"
          objectType: "person"

        activity.addReceived other, @callback
        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we examine the activity":
        topic: (activity) ->
          activity

        "it has a _received property": (activity) ->
          assert.isArray activity._received
          return

        "the _received property contains the value we added": (activity) ->
          assert.isArray activity._received
          assert.isObject _.find(activity._received, (item) ->
            item.id is "acct:gerald@photo.example" and item.objectType is "person"
          )
          return

      "and we check to see if the added person is a recipient":
        topic: (activity) ->
          other =
            id: "acct:gerald@photo.example"
            objectType: "person"

          activity.checkRecipient other, @callback
          return

        "it works": (err, isRecipient) ->
          assert.ifError err
          return

        "it is a recipient": (err, isRecipient) ->
          assert.ifError err
          assert.isTrue isRecipient
          return

      "and we get the list of recipients":
        topic: (activity) ->
          activity.recipients()

        "our added object is a recipient": (recipients) ->
          assert.isObject _.find(recipients, (item) ->
            item.id is "acct:gerald@photo.example" and item.objectType is "person"
          )
          return

suite["export"] module
