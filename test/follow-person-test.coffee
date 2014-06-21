# follow-person-test.js
#
# Test posting an activity to follow a person
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
Step = require("step")
_ = require("underscore")
querystring = require("querystring")
http = require("http")
OAuth = require("oauth-evanp").OAuth
Browser = require("zombie")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
setupApp = oauthutil.setupApp
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
newClient = oauthutil.newClient
register = oauthutil.register
ignore = (err) ->

makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

pairOf = (user) ->
  token: user.token
  token_secret: user.secret

suite = vows.describe("follow person activity test")

# A batch to test following/unfollowing users
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "it works": (err, app) ->
    assert.ifError err
    return

  "and we register a client":
    topic: ->
      newClient @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and one user follows another":
      topic: (cl) ->
        cb = @callback
        users =
          larry: {}
          moe: {}
          curly: {}

        Step (->
          register cl, "larry", "wiry1hair", @parallel()
          register cl, "moe", "bowlcutZ|are|cool", @parallel()
          register cl, "curly", "nyuk+nyuk+nyuk", @parallel()
          return
        ), ((err, user1, user2, user3) ->
          act = undefined
          url = undefined
          cred = undefined
          throw err  if err
          users.larry.profile = user1.profile
          users.moe.profile = user2.profile
          users.curly.profile = user3.profile
          users.larry.pair = pairOf(user1)
          users.moe.pair = pairOf(user2)
          users.curly.pair = pairOf(user3)
          act =
            verb: "follow"
            object:
              objectType: "person"
              id: users.moe.profile.id

          url = "http://localhost:4815/api/user/larry/feed"
          cred = makeCred(cl, users.larry.pair)
          httputil.postJSON url, cred, act, this
          return
        ), (err, posted, result) ->
          if err
            cb err, null, null
          else
            cb null, posted, users
          return

        return

      "it works": (err, act, users) ->
        assert.ifError err
        return

      "results are valid": (err, act, users) ->
        assert.ifError err
        actutil.validActivity act
        return

      "results are correct": (err, act, users) ->
        assert.ifError err
        assert.equal act.verb, "follow"
        return

      "and we get the second user's profile with the first user's credentials":
        topic: (act, users, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/moe/profile"
          cred = makeCred(cl, users.larry.pair)
          httputil.getJSON url, cred, (err, doc, response) ->
            callback err, doc
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          assert.isObject doc
          return

        "it includes the 'followed' flag": (err, doc) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "pump_io"
          assert.isObject doc.pump_io
          assert.include doc.pump_io, "followed"
          assert.isTrue doc.pump_io.followed
          return

      "and we get the second user's profile with some other user's credentials":
        topic: (act, users, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/moe/profile"
          cred = makeCred(cl, users.curly.pair)
          httputil.getJSON url, cred, (err, doc, response) ->
            callback err, doc
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          assert.isObject doc
          return

        "it includes the 'followed' flag": (err, doc) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "pump_io"
          assert.isObject doc.pump_io
          assert.include doc.pump_io, "followed"
          assert.isFalse doc.pump_io.followed
          return

    "and one user double-follows another":
      topic: (cl) ->
        cb = @callback
        users = {}
        hpair = undefined
        Step (->
          register cl, "heckle", "have a cigar", @parallel()
          register cl, "jeckle", "up to hijinks", @parallel()
          return
        ), ((err, heckle, jeckle) ->
          act = undefined
          url = undefined
          cred = undefined
          throw err  if err
          users.heckle = heckle
          users.jeckle = jeckle
          hpair = pairOf(heckle)
          act =
            verb: "follow"
            object:
              objectType: "person"
              id: users.jeckle.profile.id

          url = "http://localhost:4815/api/user/heckle/feed"
          cred = makeCred(cl, users.heckle.pair)
          httputil.postJSON url, cred, act, this
          return
        ), ((err, posted, result) ->
          throw err  if err
          act =
            verb: "follow"
            object:
              objectType: "person"
              id: users.jeckle.profile.id

          url = "http://localhost:4815/api/user/heckle/feed"
          cred = makeCred(cl, users.heckle.pair)
          httputil.postJSON url, cred, act, this
          return
        ), (err, posted, result) ->
          if err
            cb null
          else
            cb new Error("Unexpected success")
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and one user follows a remote person":
      topic: (cl) ->
        cb = @callback
        Step (->
          register cl, "tom", "silent*cat", this
          return
        ), ((err, tom) ->
          act = undefined
          url = undefined
          cred = undefined
          pair = undefined
          throw err  if err
          pair = pairOf(tom)
          act =
            verb: "follow"
            object:
              objectType: "person"
              id: "urn:uuid:6e621028-cdbc-4550-a593-4268e0f729f5"
              displayName: "Jerry"

          url = "http://localhost:4815/api/user/tom/feed"
          cred = makeCred(cl, pair)
          httputil.postJSON url, cred, act, this
          return
        ), (err, posted, result) ->
          if err
            cb err, null
          else
            cb null, posted
          return

        return

      "it works": (err, act) ->
        assert.ifError err
        return

      "results are valid": (err, act) ->
        assert.ifError err
        actutil.validActivity act
        return

      "results are correct": (err, act) ->
        assert.ifError err
        assert.equal act.verb, "follow"
        return

    "and one user follows a person who then posts":
      topic: (cl) ->
        cb = @callback
        users =
          jack: {}
          jill: {}

        postnote = undefined
        Step (->
          register cl, "jack", "up|the|hill", @parallel()
          register cl, "jill", "pail/of/water", @parallel()
          return
        ), ((err, user1, user2) ->
          act = undefined
          url = undefined
          cred = undefined
          throw err  if err
          users.jack.profile = user1.profile
          users.jill.profile = user2.profile
          users.jack.pair = pairOf(user1)
          users.jill.pair = pairOf(user2)
          act =
            verb: "follow"
            object:
              objectType: "person"
              id: users.jill.profile.id

          url = "http://localhost:4815/api/user/jack/feed"
          cred = makeCred(cl, users.jack.pair)
          httputil.postJSON url, cred, act, this
          return
        ), ((err, posted, result) ->
          throw err  if err
          act =
            verb: "post"
            to: [
              id: "http://localhost:4815/api/user/jill/followers"
              objectType: "collection"
            ]
            object:
              objectType: "note"
              content: "Hello, world."

          url = "http://localhost:4815/api/user/jill/feed"
          cred = makeCred(cl, users.jill.pair)
          httputil.postJSON url, cred, act, this
          return
        ), ((err, posted, result) ->
          throw err  if err
          postnote = posted
          url = "http://localhost:4815/api/user/jack/inbox"
          cred = makeCred(cl, users.jack.pair)
          callback = this
          
          # Need non-zero time for async distribution
          # to work. 2s seems reasonable for unit test.
          setTimeout (->
            httputil.getJSON url, cred, callback
            return
          ), 2000
          return
        ), (err, doc, result) ->
          if err
            cb err, null, null
          else
            cb null, doc, postnote
          return

        return

      "it works": (err, inbox, postnote) ->
        assert.ifError err
        return

      "posted item goes to inbox": (err, inbox, postnote) ->
        assert.ifError err
        assert.isObject inbox
        assert.include inbox, "totalItems"
        assert.isNumber inbox.totalItems
        assert.greater inbox.totalItems, 0
        assert.include inbox, "items"
        assert.isArray inbox.items
        assert.greater inbox.items.length, 0
        assert.isObject inbox.items[0]
        assert.include inbox.items[0], "id"
        assert.isObject postnote
        assert.include postnote, "id"
        assert.equal inbox.items[0].id, postnote.id
        return

    "and a user posts a person to their following stream":
      topic: (cl) ->
        cb = @callback
        users =
          abbott: {}
          costello: {}

        Step (->
          register cl, "abbott", "what's|the|name", @parallel()
          register cl, "costello", "who's+on+3rd", @parallel()
          return
        ), ((err, user1, user2) ->
          url = undefined
          cred = undefined
          throw err  if err
          users.abbott.profile = user1.profile
          users.costello.profile = user2.profile
          users.abbott.pair = pairOf(user1)
          users.costello.pair = pairOf(user2)
          url = "http://localhost:4815/api/user/abbott/following"
          cred = makeCred(cl, users.abbott.pair)
          httputil.postJSON url, cred, users.costello.profile, this
          return
        ), (err, posted, result) ->
          cb err, posted, users
          return

        return

      "it works": (err, posted, users) ->
        assert.ifError err
        return

      "posted item is person": (err, posted, users) ->
        assert.ifError err
        assert.isObject posted
        assert.include posted, "id"
        assert.equal users.costello.profile.id, posted.id
        return

      "and we check the user's following stream":
        topic: (posted, users, cl) ->
          cb = @callback
          url = "http://localhost:4815/api/user/abbott/following"
          cred = makeCred(cl, users.abbott.pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it includes the followed user": (err, feed) ->
          assert.ifError err
          assert.isObject feed
          assert.include feed, "items"
          assert.isArray feed.items
          assert.greater feed.items.length, 0
          assert.isObject feed.items[0]
          assert.equal "costello", feed.items[0].displayName
          return

      "and we check the user's activity feed":
        topic: (posted, users, cl) ->
          cb = @callback
          url = "http://localhost:4815/api/user/abbott/feed"
          cred = makeCred(cl, users.abbott.pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it includes the follow activity": (err, feed) ->
          assert.ifError err
          assert.isObject feed
          assert.include feed, "items"
          assert.isArray feed.items
          assert.greater feed.items.length, 0
          assert.isObject feed.items[0]
          assert.include feed.items[0], "verb"
          assert.equal "follow", feed.items[0].verb
          assert.include feed.items[0], "object"
          assert.isObject feed.items[0].object
          assert.include feed.items[0].object, "displayName"
          assert.equal "costello", feed.items[0].object.displayName
          assert.include feed.items[0].object, "objectType"
          assert.equal "person", feed.items[0].object.objectType
          return

    "and a user posts to someone else's following stream":
      topic: (cl) ->
        cb = @callback
        users =
          laurel: {}
          hardy: {}
          cop: {}

        Step (->
          register cl, "laurel", "b0wler*HAT", @parallel()
          register cl, "hardy", "n0w,st4nley...", @parallel()
          register cl, "cop", "what's|the|hubbub", @parallel()
          return
        ), ((err, user1, user2, user3) ->
          url = undefined
          cred = undefined
          throw err  if err
          users.laurel.profile = user1.profile
          users.hardy.profile = user2.profile
          users.cop.profile = user3.profile
          users.laurel.pair = pairOf(user1)
          users.hardy.pair = pairOf(user2)
          users.cop.pair = pairOf(user3)
          url = "http://localhost:4815/api/user/hardy/following"
          cred = makeCred(cl, users.laurel.pair)
          httputil.postJSON url, cred, users.cop.profile, this
          return
        ), (err, posted, result) ->
          if err and err.statusCode is 401
            cb null
          else if err
            cb err
          else
            cb new Error("Unexpected success!")
          return

        return

      "it fails with a 401 error": (err) ->
        assert.ifError err
        return

suite["export"] module
