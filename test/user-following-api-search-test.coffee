# user-following-api-search-test.js
#
# Test searching the following endpoint
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
assert = require("assert")
vows = require("vows")
Step = require("step")
_ = require("underscore")
querystring = require("querystring")
http = require("http")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
pj = httputil.postJSON
gj = httputil.getJSON
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
newPair = oauthutil.newPair
register = oauthutil.register
validFeed = actutil.validFeed
validActivityObject = actutil.validActivityObject
ignore = (err) ->

makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

suite = vows.describe("User stream search test")

# A batch for testing the read access to the API
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

  "and we make a new client":
    topic: ->
      newClient @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and we register a new user":
      topic: (cl) ->
        newPair cl, "staggerlee", "wrong'emboyo", @callback
        return

      "it works": (err, pair) ->
        assert.ifError err
        assert.isObject pair
        return

      "and they follow a lot of people":
        topic: (pair, cl) ->
          callback = @callback
          cred = makeCred(cl, pair)
          registerAndFollow = (nickname, password, callback) ->
            Step (->
              register cl, nickname, password, this
              return
            ), ((err, user) ->
              act = undefined
              url = "http://localhost:4815/api/user/staggerlee/feed"
              throw err  if err
              act =
                verb: "follow"
                object: user.profile

              pj url, cred, act, this
              return
            ), (err, result) ->
              callback err
              return

            return

          Step (->
            group = @group()
            i = undefined
            i = 0
            while i < 100
              registerAndFollow (if (i % 10 is 0) then ("billy" + i) else ("trying" + i)), "i_rolled_8", group()
              i++
            return
          ), (err) ->
            callback err
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we request the following stream with a search parameter":
          topic: (pair, cl) ->
            callback = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/staggerlee/following?q=billy"
            gj url, cred, (err, body, resp) ->
              callback err, body
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            return

          "it includes only the matching objects": (err, feed) ->
            i = undefined
            assert.ifError err
            validFeed feed
            assert.equal feed.items.length, 10
            i = 0
            while i < 100
              assert.ok _.some(feed.items, (item) ->
                item.preferredUsername is ("billy" + i)
              )
              i += 10
            return

        "and we request the following stream with a non-matching search parameter":
          topic: (pair, cl) ->
            callback = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/staggerlee/following?q=thereisnomatchforthis"
            gj url, cred, (err, body, resp) ->
              callback err, body
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            return

          "it is empty": (err, feed) ->
            i = undefined
            assert.ifError err
            validFeed feed
            assert.equal feed.items.length, 0
            return

    "and we register a different user":
      topic: (cl) ->
        newPair cl, "rudie", "chicken-skin-suit", @callback
        return

      "it works": (err, pair) ->
        assert.ifError err
        assert.isObject pair
        return

      "and they follow a person":
        topic: (pair, cl) ->
          callback = @callback
          cred = makeCred(cl, pair)
          user = undefined
          Step (->
            register cl, "thedoctor", "for*a*purpose", this
            return
          ), ((err, results) ->
            ucred = undefined
            url = undefined
            act = undefined
            throw err  if err
            user = results
            ucred = makeCred(cl,
              token: user.token
              token_secret: user.secret
            )
            url = "http://localhost:4815/api/user/thedoctor/feed"
            act =
              verb: "update"
              object:
                id: user.profile.id
                objectType: "person"
                displayName: "Alimantado"

            pj url, ucred, act, this
            return
          ), ((err) ->
            throw err  if err
            act = undefined
            url = "http://localhost:4815/api/user/rudie/feed"
            throw err  if err
            act =
              verb: "follow"
              object: user.profile

            pj url, cred, act, this
            return
          ), (err) ->
            callback err
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we request the following stream with a search parameter":
          topic: (pair, cl) ->
            callback = @callback
            cred = makeCred(cl, pair)
            url = "http://localhost:4815/api/user/rudie/following?q=alim"
            gj url, cred, (err, body, resp) ->
              callback err, body
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            return

          "it includes only the matching objects": (err, feed) ->
            i = undefined
            assert.ifError err
            validFeed feed
            assert.equal feed.items.length, 1
            assert.equal feed.items[0].displayName, "Alimantado"
            return

suite["export"] module
