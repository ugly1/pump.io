# user-stream-api-test.js
#
# Test user streams API
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
setupApp = oauthutil.setupApp
register = oauthutil.register
newPair = oauthutil.newPair
newCredentials = oauthutil.newCredentials
ignore = (err) ->

suite = vows.describe("User stream API test")
sizeFeed = (endpoint, size) ->
  topic: (cred) ->
    full = "http://localhost:4815" + endpoint
    callback = @callback
    httputil.getJSON full, cred, callback
    return

  "it works": (err, feed, resp) ->
    assert.ifError err
    return

  "it looks like a feed": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.include feed, "items"
    return

  "it is empty": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.equal feed.totalItems, size
    assert.include feed, "items"
    assert.isArray feed.items
    assert.equal feed.items.length, size
    return

emptyFeed = (endpoint) ->
  topic: (cred) ->
    full = "http://localhost:4815" + endpoint
    callback = @callback
    httputil.getJSON full, cred, callback
    return

  "it works": (err, feed, resp) ->
    assert.ifError err
    return

  "it looks like a feed": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.include feed, "items"
    return

  "it is empty": (err, feed, resp) ->
    assert.ifError err
    assert.isObject feed
    assert.include feed, "totalItems"
    assert.equal feed.totalItems, 0
    assert.include feed, "items"
    assert.isEmpty feed.items
    return


# Test some "bad" kinds of activity
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

  "and we get new credentials":
    topic: (app) ->
      newCredentials "diego", "to*the*rescue", @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.isString cred.consumer_key
      assert.isString cred.consumer_secret
      assert.isString cred.token
      assert.isString cred.token_secret
      return

    "and we try to post an activity with a different actor":
      topic: (cred, app) ->
        cb = @callback
        act =
          actor:
            id: "urn:uuid:66822a4d-9f72-4168-8d5a-0b1319afeeb1"
            objectType: "person"
            displayName: "Not Diego"

          verb: "post"
          object:
            objectType: "note"
            content: "To the rescue!"

        httputil.postJSON "http://localhost:4815/api/user/diego/feed", cred, act, (err, feed, result) ->
          if err
            cb null
          else if result.statusCode < 400 or result.statusCode >= 500
            cb new Error("Unexpected result")
          else
            cb null
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we try to post an activity with no object":
      topic: (cred, app) ->
        cb = @callback
        act = verb: "noop"
        httputil.postJSON "http://localhost:4815/api/user/diego/feed", cred, act, (err, feed, result) ->
          if err
            cb null
          else if result.statusCode < 400 or result.statusCode >= 500
            cb new Error("Unexpected result")
          else
            cb null
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we try to post an activity as a different user":
      topic: (cred, app) ->
        cb = @callback
        cl =
          client_id: cred.consumer_key
          client_secret: cred.consumer_secret

        act =
          verb: "post"
          object:
            objectType: "note"
            content: "To the rescue!"

        Step (->
          newPair cl, "boots", "b4nanazz", this
          return
        ), (err, pair) ->
          nuke = undefined
          if err
            cb err
          else
            nuke = _(cred).clone()
            _(nuke).extend pair
            httputil.postJSON "http://localhost:4815/api/user/diego/feed", nuke, act, (err, feed, result) ->
              if err
                cb null
              else if result.statusCode < 400 or result.statusCode >= 500
                cb new Error("Unexpected result")
              else
                cb null
              return

          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we try to post an activity with a default verb":
      topic: (cred, app) ->
        cb = @callback
        act = object:
          objectType: "note"
          content: "Hello, llama!"

        httputil.postJSON "http://localhost:4815/api/user/diego/feed", cred, act, (err, posted, result) ->
          if err
            cb err, null
          else
            cb null, posted
          return

        return

      "it works": (err, act) ->
        assert.ifError err
        return

      "it has the right verb": (err, act) ->
        assert.equal act.verb, "post"
        return

suite["export"] module
