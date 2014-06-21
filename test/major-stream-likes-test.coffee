# major-stream-likes-test.js
#
# Test that liked objects have "liked" flag in */major streams
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
http = require("http")
OAuth = require("oauth-evanp").OAuth
Browser = require("zombie")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
register = oauthutil.register
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

suite = vows.describe("Test liked flag in major streams and favorites")
sameUser = (url, objects) ->
  ctx =
    topic: (pair, cl) ->
      callback = @callback
      cred = makeCred(cl, pair)
      Step (->
        httputil.getJSON url, cred, this
        return
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed
        return

      return

    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed
      return

  if objects
    ctx["all objects have 'liked' property with value 'true'"] = (err, feed) ->
      assert.ifError err
      assert.isObject feed
      assert.include feed, "items"
      assert.isArray feed.items
      assert.lengthOf feed.items, 10
      _.each feed.items, (object) ->
        assert.isObject object
        assert.include object, "liked"
        assert.isTrue object.liked
        return

      return
  else
    ctx["all objects have 'liked' property with correct value"] = (err, feed) ->
      assert.ifError err
      assert.isObject feed
      assert.include feed, "items"
      assert.isArray feed.items
      assert.lengthOf feed.items, 20
      _.each feed.items, (activity, i) ->
        assert.isObject activity
        assert.include activity, "object"
        assert.isObject activity.object
        assert.include activity.object, "liked"
        if activity.object.secretNumber % 2 is 0
          assert.isTrue activity.object.liked
        else
          assert.isFalse activity.object.liked
        return

      return
  ctx

justClient = (url, objects) ->
  ctx =
    topic: (pair, cl) ->
      callback = @callback
      cred =
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret

      Step (->
        httputil.getJSON url, cred, this
        return
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed
        return

      return

    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed
      return

  if objects
    ctx["no objects have 'liked' property"] = (err, feed) ->
      assert.ifError err
      assert.isObject feed
      assert.include feed, "items"
      assert.isArray feed.items
      assert.lengthOf feed.items, 10
      _.each feed.items, (object) ->
        assert.isObject object
        assert.isFalse _.has(object, "liked")
        return

      return
  else
    ctx["no objects have 'liked' property"] = (err, feed) ->
      assert.ifError err
      assert.isObject feed
      assert.include feed, "items"
      assert.isArray feed.items
      assert.lengthOf feed.items, 20
      _.each feed.items, (activity) ->
        assert.isObject activity
        assert.include activity, "object"
        assert.isObject activity.object
        assert.isFalse _.has(activity.object, "liked")
        return

      return
  ctx

otherUser = (url, objects) ->
  ctx =
    topic: (pair, ignore, cl) ->
      callback = @callback
      cred = makeCred(cl, pair)
      Step (->
        httputil.getJSON url, cred, this
        return
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed
        return

      return

    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed
      return

  if objects
    ctx["all objects have 'liked' property with value 'false'"] = (err, feed) ->
      assert.ifError err
      assert.isObject feed
      assert.include feed, "items"
      assert.isArray feed.items
      assert.lengthOf feed.items, 10
      _.each feed.items, (object) ->
        assert.isObject object
        assert.include object, "liked"
        assert.isFalse object.liked
        return

      return
  else
    ctx["all objects have 'liked' property with value 'false'"] = (err, feed) ->
      assert.ifError err
      assert.isObject feed
      assert.include feed, "items"
      assert.isArray feed.items
      assert.lengthOf feed.items, 20
      _.each feed.items, (activity) ->
        assert.isObject activity
        assert.include activity, "object"
        assert.isObject activity.object
        assert.include activity.object, "liked"
        assert.isFalse activity.object.liked
        return

      return
  ctx


# A batch to test favoriting/unfavoriting objects
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

    "and we register a user":
      topic: (cl) ->
        newPair cl, "allan", "big*game", @callback
        return

      "it works": (err, pair) ->
        assert.ifError err
        assert.isObject pair
        return

      "and they posts a bunch of notes and like them all":
        topic: (pair, cl) ->
          callback = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/allan/feed"
          Step (->
            group = @group()
            _.times 20, (i) ->
              act =
                to: [pair.user.profile]
                cc: [
                  objectType: "collection"
                  id: "http://activityschema.org/collection/public"
                ]
                verb: "post"
                object:
                  objectType: "note"
                  secretNumber: i
                  content: "Hello, world! " + i

              httputil.postJSON url, cred, act, group()
              return

            return
          ), ((err, posts) ->
            group = @group()
            throw err  if err
            _.each posts, (post, i) ->
              if post.object.secretNumber % 2 is 0
                act =
                  verb: "favorite"
                  object: post.object

                httputil.postJSON url, cred, act, group()
              return

            return
          ), (err, likes) ->
            if err
              callback err
            else
              callback null
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we check their major inbox with same user credentials": sameUser("http://localhost:4815/api/user/allan/inbox/major")
        "and we check their major feed with same user credentials": sameUser("http://localhost:4815/api/user/allan/feed/major")
        "and we check their major direct inbox with same user credentials": sameUser("http://localhost:4815/api/user/allan/inbox/direct/major")
        "and we check their favorites with same user credentials": sameUser("http://localhost:4815/api/user/allan/favorites", true)
        "and we check their major feed with client credentials": justClient("http://localhost:4815/api/user/allan/feed/major")
        "and we check their favorites with client credentials": justClient("http://localhost:4815/api/user/allan/favorites", true)
        "and we register another user":
          topic: (pair, cl) ->
            newPair cl, "umslopogaas", "big*knife", @callback
            return

          "it works": (err, pair) ->
            assert.ifError err
            assert.isObject pair
            return

          "and we check the first user's major feed with different user credentials": otherUser("http://localhost:4815/api/user/allan/feed/major")
          "and we check the first user's favorites with different user credentials": otherUser("http://localhost:4815/api/user/allan/favorites", true)

suite["export"] module
