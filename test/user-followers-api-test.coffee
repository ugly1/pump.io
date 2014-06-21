# user-followers-api-test.js
#
# Test the user followers/following endpoints for the API
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
http = require("http")
vows = require("vows")
Step = require("step")
_ = require("underscore")
Queue = require("jankyqueue")
OAuth = require("oauth-evanp").OAuth
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
newPair = oauthutil.newPair
register = oauthutil.register
suite = vows.describe("user followers API")
invert = (callback) ->
  (err) ->
    if err
      callback null
    else
      callback new Error("Unexpected success")
    return

makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

pairOf = (user) ->
  token: user.token
  token_secret: user.secret

assertValidList = (doc, total, count) ->
  assert.include doc, "author"
  assert.include doc.author, "id"
  assert.include doc.author, "displayName"
  assert.include doc.author, "objectType"
  assert.include doc, "totalItems"
  assert.include doc, "items"
  assert.include doc, "displayName"
  assert.include doc, "url"
  assert.include doc, "links"
  assert.include doc.links, "current"
  assert.include doc.links.current, "href"
  assert.include doc.links, "self"
  assert.include doc.links.self, "href"
  assert.include doc, "objectTypes"
  assert.include doc.objectTypes, "person"
  assert.equal doc.totalItems, total  if _(total).isNumber()
  assert.lengthOf doc.items, count  if _(count).isNumber()
  return

suite.addBatch "When we set up the app":
  topic: ->
    cb = @callback
    setupApp cb
    return

  "it works": (err, app) ->
    assert.ifError err
    assert.isObject app
    return

  teardown: (app) ->
    app.close()  if app
    return

  "and we create a new client":
    topic: ->
      newClient @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and we try to get followers for a non-existent user":
      topic: (cl) ->
        cb = @callback
        httputil.getJSON "http://localhost:4815/api/user/nonexistent/followers",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        , (err, followers, result) ->
          if err and err.statusCode and err.statusCode is 404
            cb null
          else if err
            cb err
          else
            cb new Error("Unexpected success")
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we try to get following for a non-existent user":
      topic: (cl) ->
        cb = @callback
        httputil.getJSON "http://localhost:4815/api/user/nonexistent/following",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        , (err, followers, result) ->
          if err and err.statusCode and err.statusCode is 404
            cb null
          else if err
            cb err
          else
            cb new Error("Unexpected success")
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we register a user":
      topic: (cl) ->
        register cl, "tyrion", "payURd3bts", @callback
        return

      "it works": (err, user) ->
        assert.ifError err
        return

      "and we get the options on the user followers endpoint": httputil.endpoint("/api/user/tyrion/followers", ["GET"])
      "and we get the options on the user following endpoint": httputil.endpoint("/api/user/tyrion/followers", ["GET"])
      "and we GET the followers list without OAuth credentials":
        topic: ->
          cb = @callback
          options =
            host: "localhost"
            port: 4815
            path: "/api/user/tyrion/followers"

          http.get(options, (res) ->
            if res.statusCode >= 400 and res.statusCode < 500
              cb null
            else
              cb new Error("Unexpected status code")
            return
          ).on "error", (err) ->
            cb err
            return

          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we GET the followers list with invalid client credentials":
        topic: (user, cl) ->
          httputil.getJSON "http://localhost:4815/api/user/tyrion/followers",
            consumer_key: "NOTACLIENT"
            consumer_secret: "NOTASECRET"
          , invert(@callback)
          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we GET the followers list with client credentials and no access token":
        topic: (user, cl) ->
          httputil.getJSON "http://localhost:4815/api/user/tyrion/followers",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
          , @callback
          return

        "it works": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

      "and we GET the followers list with client credentials and an invalid access token":
        topic: (user, cl) ->
          httputil.getJSON "http://localhost:4815/api/user/tyrion/followers",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
            token: "NOTATOKEN"
            token_secret: "NOTASECRET"
          , invert(@callback)
          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we GET the following list with client credentials and the same user's access token":
        topic: (user, cl) ->
          cb = @callback
          pair = pairOf(user)
          Step (->
            httputil.getJSON "http://localhost:4815/api/user/tyrion/following",
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: pair.token
              token_secret: pair.token_secret
            , this
            return
          ), (err, results) ->
            if err
              cb err, null
            else
              cb null, results
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

      "and we GET the followers list with client credentials and the same user's access token":
        topic: (user, cl) ->
          cb = @callback
          pair = pairOf(user)
          Step (->
            httputil.getJSON "http://localhost:4815/api/user/tyrion/followers",
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: pair.token
              token_secret: pair.token_secret
            , this
            return
          ), (err, results) ->
            if err
              cb err, null
            else
              cb null, results
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

      "and we GET the followers list with client credentials and a different user's access token":
        topic: (user, cl) ->
          cb = @callback
          Step (->
            register cl, "cersei", "i{heart}p0wer", this
            return
          ), ((err, user2) ->
            pair = undefined
            throw err  if err
            pair =
              token: user2.token
              token_secret: user2.secret

            httputil.getJSON "http://localhost:4815/api/user/tyrion/followers",
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: pair.token
              token_secret: pair.token_secret
            , this
            return
          ), (err, results) ->
            if err
              cb err, null
            else
              cb null, results
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

      "and we GET the following list without OAuth credentials":
        topic: ->
          cb = @callback
          options =
            host: "localhost"
            port: 4815
            path: "/api/user/tyrion/following"

          http.get(options, (res) ->
            if res.statusCode >= 400 and res.statusCode < 500
              cb null
            else
              cb new Error("Unexpected status code")
            return
          ).on "error", (err) ->
            cb err
            return

          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we GET the following list with invalid client credentials":
        topic: (user, cl) ->
          httputil.getJSON "http://localhost:4815/api/user/tyrion/following",
            consumer_key: "NOTACLIENT"
            consumer_secret: "NOTASECRET"
          , invert(@callback)
          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we GET the following list with client credentials and no access token":
        topic: (user, cl) ->
          httputil.getJSON "http://localhost:4815/api/user/tyrion/following",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
          , @callback
          return

        "it works": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

      "and we GET the following list with client credentials and an invalid access token":
        topic: (user, cl) ->
          httputil.getJSON "http://localhost:4815/api/user/tyrion/following",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
            token: "NOTATOKEN"
            token_secret: "NOTASECRET"
          , invert(@callback)
          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we GET the following list with client credentials and a different user's access token":
        topic: (user, cl) ->
          cb = @callback
          Step (->
            register cl, "tywin", "c4st3rly*r0ck", this
            return
          ), ((err, user2) ->
            pair = undefined
            throw err  if err
            pair =
              token: user2.token
              token_secret: user2.secret

            httputil.getJSON "http://localhost:4815/api/user/tyrion/following",
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: pair.token
              token_secret: pair.token_secret
            , this
            return
          ), (err, results) ->
            if err
              cb err, null
            else
              cb null, results
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

    "and one user follows another":
      topic: (cl) ->
        cb = @callback
        users = undefined
        pairs = undefined
        Step (->
          register cl, "robb", "gr3yw1nd", @parallel()
          register cl, "greatjon", "bl00dyt0ugh", @parallel()
          return
        ), (err, robb, greatjon) ->
          act = undefined
          url = undefined
          cred = undefined
          throw err  if err
          users =
            robb: robb
            greatjon: greatjon

          pairs =
            robb: pairOf(robb)
            greatjon: pairOf(greatjon)

          act =
            verb: "follow"
            object:
              objectType: "person"
              id: users.robb.profile.id

            mood:
              displayName: "Raucous"

          url = "http://localhost:4815/api/user/greatjon/feed"
          cred = makeCred(cl, pairs.greatjon)
          httputil.postJSON url, cred, act, (err, posted, result) ->
            if err
              cb err, null, null
            else
              cb null, users, pairs
            return

          return

        return

      "it works": (err, users, pairs) ->
        assert.ifError err
        return

      "and we check the first user's following list":
        topic: (users, pairs, cl) ->
          cb = @callback
          cred = makeCred(cl, pairs.greatjon)
          url = "http://localhost:4815/api/user/greatjon/following"
          httputil.getJSON url, cred, (err, doc, results) ->
            cb err, doc, users.robb.profile
            return

          return

        "it works": (err, doc, person) ->
          assert.ifError err
          return

        "it is valid": (err, doc, person) ->
          assert.ifError err
          assertValidList doc, 1
          return

        "it contains the second person": (err, doc, person) ->
          assert.ifError err
          assert.equal doc.items[0].id, person.id
          assert.equal doc.items[0].objectType, person.objectType
          return

        "the followed flag is set": (err, doc, person) ->
          assert.ifError err
          assert.includes doc.items[0], "pump_io"
          assert.isObject doc.items[0].pump_io
          assert.includes doc.items[0].pump_io, "followed"
          assert.isTrue doc.items[0].pump_io.followed
          return

      "and we check the first user's followers list":
        topic: (users, pairs, cl) ->
          cb = @callback
          cred = makeCred(cl, pairs.greatjon)
          url = "http://localhost:4815/api/user/greatjon/followers"
          httputil.getJSON url, cred, (err, doc, results) ->
            cb err, doc
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          return

        "it is valid": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

      "and we check the second user's followers list":
        topic: (users, pairs, cl) ->
          cb = @callback
          cred = makeCred(cl, pairs.robb)
          url = "http://localhost:4815/api/user/robb/followers"
          httputil.getJSON url, cred, (err, doc, results) ->
            cb err, doc, users.greatjon.profile
            return

          return

        "it works": (err, doc, person) ->
          assert.ifError err
          return

        "it is valid": (err, doc, person) ->
          assert.ifError err
          assertValidList doc, 1
          return

        "it contains the first person": (err, doc, person) ->
          assert.ifError err
          assert.equal doc.items[0].id, person.id
          assert.equal doc.items[0].objectType, person.objectType
          return

        "the followed flag is not set": (err, doc, person) ->
          assert.ifError err
          assert.includes doc.items[0], "pump_io"
          assert.isObject doc.items[0].pump_io
          assert.includes doc.items[0].pump_io, "followed"
          assert.isFalse doc.items[0].pump_io.followed
          return

      "and we check the second user's following list":
        topic: (users, pairs, cl) ->
          cb = @callback
          cred = makeCred(cl, pairs.robb)
          url = "http://localhost:4815/api/user/robb/following"
          httputil.getJSON url, cred, (err, doc, results) ->
            cb err, doc
            return

          return

        "it works": (err, doc) ->
          assert.ifError err
          return

        "it is valid": (err, doc) ->
          assert.ifError err
          assertValidList doc, 0
          return

    "and a lot of users follow one user":
      topic: (cl) ->
        cb = @callback
        user = undefined
        pair = undefined
        Step (->
          register cl, "nymeria", "gr0000wl", this
          return
        ), ((err, nymeria) ->
          i = undefined
          group = @group()
          q = new Queue(10)
          throw err  if err
          user = nymeria
          pair = pairOf(user)
          i = 0
          while i < 100
            q.enqueue newPair, [
              cl
              "wolf" + i
              "grrr!grrr!" + i
            ], group()
            i++
          return
        ), ((err, pairs) ->
          act = undefined
          url = undefined
          cred = undefined
          i = undefined
          group = @group()
          q = new Queue(10)
          throw err  if err
          act =
            verb: "follow"
            object:
              objectType: "person"
              id: user.profile.id

          i = 0
          while i < 100
            q.enqueue httputil.postJSON, [
              "http://localhost:4815/api/user/wolf" + i + "/feed"
              makeCred(cl, pairs[i])
              act
            ], group()
            i++
          return
        ), (err, docs, responses) ->
          cb err, pair
          return

        return

      "it works": (err, pair) ->
        assert.ifError err
        return

      "and we get the tip of the followers feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/nymeria/followers"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 100, 20
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

        "and we get the prev link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.prev.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 100, 0
            return

        "and we get the next link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.next.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 100, 20
            return

      "and we get a non-default count from the feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/nymeria/followers?count=40"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 100, 40
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

      "and we get a very large count from the feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/nymeria/followers?count=200"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 100, 100
          return

        "it has no next link": (err, feed) ->
          assert.ifError err
          assert.isFalse _.has(feed.links, "next")
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

      "and we get an offset subset from the feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/nymeria/followers?offset=20"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 100, 20
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

        "and we get the prev link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.prev.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 100, 20
            return

        "and we get the next link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.next.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 100, 20
            return

    "and a user follows a lot of other users":
      topic: (cl) ->
        cb = @callback
        user = undefined
        pair = undefined
        Step (->
          register cl, "varys", "i*hate*magic", this
          return
        ), ((err, varys) ->
          i = undefined
          group = @group()
          throw err  if err
          user = varys
          pair = pairOf(user)
          i = 0
          while i < 50
            register cl, "littlebird" + i, "sekrit!" + i, group()
            i++
          return
        ), ((err, users) ->
          cred = undefined
          i = undefined
          group = @group()
          throw err  if err
          cred = makeCred(cl, pair)
          i = 0
          while i < 50
            httputil.postJSON "http://localhost:4815/api/user/varys/feed", cred,
              verb: "follow"
              object:
                objectType: "person"
                id: users[i].profile.id
            , group()
            i++
          return
        ), (err, docs, responses) ->
          cb err, pair
          return

        return

      "it works": (err, pair) ->
        assert.ifError err
        return

      "and we get the tip of the following feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/varys/following"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 50, 20
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

        "and we get the prev link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.prev.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 50, 0
            return

        "and we get the next link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.next.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 50, 20
            return

      "and we get a non-default count from the feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/varys/following?count=40"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 50, 40
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

      "and we get a very large count from the feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/varys/following?count=50"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 50, 50
          return

        "it has no next link": (err, feed) ->
          assert.ifError err
          assert.isFalse _.has(feed.links, "next")
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

      "and we get an offset subset from the feed":
        topic: (pair, cl) ->
          callback = @callback
          url = "http://localhost:4815/api/user/varys/following?offset=20"
          cred = makeCred(cl, pair)
          httputil.getJSON url, cred, (err, doc, resp) ->
            callback err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          return

        "it is valid": (err, feed) ->
          assert.ifError err
          assertValidList feed, 50, 20
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

        "and we get the prev link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.prev.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 50, 20
            return

        "and we get the next link":
          topic: (feed, pair, cl) ->
            callback = @callback
            url = feed.links.next.href
            cred = makeCred(cl, pair)
            httputil.getJSON url, cred, (err, doc, resp) ->
              callback err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 50, 10
            return

suite["export"] module
