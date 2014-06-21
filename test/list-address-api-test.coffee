# list-address-api-test.js
#
# Test addressing a list
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
Queue = require("jankyqueue")
OAuth = require("oauth-evanp").OAuth
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
register = oauthutil.register
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
newClient = oauthutil.newClient
ignore = (err) ->

suite = vows.describe("List address API test")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

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

    "and we create a new user":
      topic: (cl) ->
        callback = @callback
        Step (->
          group = @group()
          newPair cl, "fry", "1-jan-2000", group()
          newPair cl, "leela", "6undergr0und", group()
          newPair cl, "bender", "shiny|metal", group()
          newPair cl, "amy", "k|k|wong", group()
          return
        ), callback
        return

      "it works": (err, pairs) ->
        assert.ifError err
        assert.isArray pairs
        return

      "and they create a list":
        topic: (pairs, cl) ->
          callback = @callback
          cred = makeCred(cl, pairs[0])
          Step (->
            httputil.postJSON "http://localhost:4815/api/user/fry/feed", cred,
              verb: "create"
              object:
                objectType: "collection"
                objectTypes: ["person"]
                displayName: "Planet Express"
            , this
            return
          ), ((err, body, resp) ->
            throw err  if err
            this null, body.object
            return
          ), callback
          return

        "it works": (err, list) ->
          assert.ifError err
          assert.isObject list
          return

        "and they add some other users":
          topic: (list, pairs, cl) ->
            callback = @callback
            cred = makeCred(cl, pairs[0])
            Step (->
              group = @group()
              _.each _.pluck(pairs.slice(1), "user"), (user) ->
                httputil.postJSON "http://localhost:4815/api/user/fry/feed", cred,
                  verb: "add"
                  object: user.profile
                  target: list
                , group()
                return

              return
            ), (err, acts) ->
              if err
                callback err
              else
                callback null
              return

            return

          "it works": (err) ->
            assert.ifError err
            return

          "and they post a note to the list":
            topic: (list, pairs, cl) ->
              callback = @callback
              cred = makeCred(cl, pairs[0])
              httputil.postJSON "http://localhost:4815/api/user/fry/feed", cred,
                verb: "post"
                to: [list]
                object:
                  objectType: "note"
                  content: "Hi everybody."
              , (err, body, resp) ->
                callback err, body
                return

              return

            "it works": (err, body) ->
              assert.ifError err
              assert.isObject body
              return

            "and we check the inboxes of the other users":
              topic: (act, list, pairs, cl) ->
                callback = @callback
                Step (->
                  group = @group()
                  _.each pairs.slice(1), (pair) ->
                    user = pair.user
                    cred = makeCred(cl, pair)
                    httputil.getJSON "http://localhost:4815/api/user/" + user.nickname + "/inbox", cred, group()
                    return

                  return
                ), (err, feeds) ->
                  callback err, feeds, act
                  return

                return

              "it works": (err, feeds, act) ->
                assert.ifError err
                assert.isArray feeds
                assert.isObject act
                return

              "the activity is in there": (err, feeds, act) ->
                _.each feeds, (feed) ->
                  assert.isObject feed
                  assert.include feed, "items"
                  assert.isArray feed.items
                  assert.greater feed.items.length, 0
                  assert.isTrue _.some(feed.items, (item) ->
                    item.id is act.id
                  )
                  return

                return

    "and a user posts to a very big list":
      topic: (cl) ->
        callback = @callback
        pairs = undefined
        list = undefined
        act = undefined
        q = new Queue(25)
        Step (->
          i = undefined
          group = @group()
          i = 0
          while i < 150
            q.enqueue newPair, [
              cl
              "robot" + i
              "bad*password*" + i
            ], group()
            i++
          return
        ), ((err, results) ->
          cred = undefined
          throw err  if err
          pairs = results
          cred = makeCred(cl, pairs[0])
          httputil.postJSON "http://localhost:4815/api/user/robot0/feed", cred,
            verb: "create"
            object:
              objectType: "collection"
              objectTypes: ["person"] # robots are people, too
              displayName: "Robots"
          , this
          return
        ), ((err, act) ->
          group = @group()
          cred = undefined
          throw err  if err
          list = act.object
          cred = makeCred(cl, pairs[0])
          _.each _.pluck(pairs.slice(1), "user"), (user) ->
            q.enqueue httputil.postJSON, [
              "http://localhost:4815/api/user/robot0/feed"
              cred
              {
                verb: "add"
                object: user.profile
                target: list
              }
            ], group()
            return

          return
        ), ((err, responses) ->
          cred = makeCred(cl, pairs[0])
          throw err  if err
          httputil.postJSON "http://localhost:4815/api/user/robot0/feed", cred,
            verb: "post"
            to: [list]
            object:
              objectType: "note"
              content: "Cigars are evil; you won't miss 'em."
          , this
          return
        ), ((err, body, resp) ->
          cb = this
          throw err  if err
          act = body
          setTimeout (->
            cb null
            return
          ), 5000
          return
        ), ((err) ->
          group = @group()
          _.each pairs.slice(1), (pair) ->
            user = pair.user
            cred = makeCred(cl, pair)
            q.enqueue httputil.getJSON, [
              "http://localhost:4815/api/user/" + user.nickname + "/inbox"
              cred
            ], group()
            return

          return
        ), (err, feeds) ->
          callback err, feeds, act
          return

        return

      "it works": (err, feeds, act) ->
        assert.ifError err
        assert.isArray feeds
        assert.isObject act
        return

      "the activity is in there": (err, feeds, act) ->
        _.each feeds, (feed) ->
          assert.isObject feed
          assert.include feed, "items"
          assert.isArray feed.items
          assert.greater feed.items.length, 0
          assert.isTrue _.some(feed.items, (item) ->
            item.id is act.id
          )
          return

        return

suite["export"] module
