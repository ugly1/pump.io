# user-stream-major-minor-post-api-test.js
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
newCredentials = oauthutil.newCredentials
suite = vows.describe("Posting to major and minor streams API test")
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

  "and we register a user":
    topic: (app) ->
      Step (->
        newCredentials "snail", "cymbal|ic", @parallel()
        return
      ), @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "and we post a major activity to the major feed":
      topic: (cred) ->
        cb = @callback
        act =
          verb: "post"
          object:
            id: "urn:uuid:830abd10-4846-11e2-96a1-70f1a154e1aa"
            objectType: "audio"
            displayName: "Klangggg!"
            url: "http://example.net/klangggg"

        url = "http://localhost:4815/api/user/snail/feed/major"
        httputil.postJSON url, cred, act, (err, doc, response) ->
          cb err, doc
          return

        return

      "it works": (err, doc) ->
        assert.ifError err
        assert.isObject doc
        return

      "and we check the major feed":
        topic: (act, cred) ->
          cb = @callback
          url = "http://localhost:4815/api/user/snail/feed/major"
          httputil.getJSON url, cred, (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it's in there": (err, doc, act) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "items"
          assert.isArray doc.items
          assert.greater doc.items.length, 0
          assert.isTrue _.any(doc.items, (item) ->
            item.id is act.id
          )
          return

      "and we check the feed":
        topic: (act, cred) ->
          cb = @callback
          url = "http://localhost:4815/api/user/snail/feed"
          httputil.getJSON url, cred, (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it's in there": (err, doc, act) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "items"
          assert.isArray doc.items
          assert.greater doc.items.length, 0
          assert.isTrue _.any(doc.items, (item) ->
            item.id is act.id
          )
          return

      "and we check the minor feed":
        topic: (act, cred) ->
          cb = @callback
          url = "http://localhost:4815/api/user/snail/feed/minor"
          httputil.getJSON url, cred, (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it's not in there": (err, doc, act) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "items"
          assert.isArray doc.items
          assert.isTrue _.every(doc.items, (item) ->
            item.id isnt act.id
          )
          return

    "and we post a minor activity to the major feed":
      topic: (cred) ->
        cb = @callback
        act =
          verb: "like"
          object:
            id: "urn:uuid:830b38b2-4846-11e2-8914-70f1a154e1aa"
            objectType: "audio"
            displayName: "Bonngggg!"
            url: "http://example.net/bongggg"

        url = "http://localhost:4815/api/user/snail/feed/major"
        httputil.postJSON url, cred, act, (err, doc, response) ->
          if err and err.statusCode >= 400 and err.statusCode < 500
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

    "and we post a minor activity to the minor feed":
      topic: (cred) ->
        cb = @callback
        act =
          verb: "like"
          object:
            id: "urn:uuid:830bb012-4846-11e2-bfc7-70f1a154e1aa"
            objectType: "audio"
            displayName: "Bash!"
            url: "http://example.net/bash"

        url = "http://localhost:4815/api/user/snail/feed/minor"
        httputil.postJSON url, cred, act, (err, doc, response) ->
          cb err, doc
          return

        return

      "it works": (err, doc) ->
        assert.ifError err
        assert.isObject doc
        return

      "and we check the minor feed":
        topic: (act, cred) ->
          cb = @callback
          url = "http://localhost:4815/api/user/snail/feed/minor"
          httputil.getJSON url, cred, (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it's in there": (err, doc, act) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "items"
          assert.isArray doc.items
          assert.greater doc.items.length, 0
          assert.isTrue _.any(doc.items, (item) ->
            item.id is act.id
          )
          return

      "and we check the feed":
        topic: (act, cred) ->
          cb = @callback
          url = "http://localhost:4815/api/user/snail/feed"
          httputil.getJSON url, cred, (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it's in there": (err, doc, act) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "items"
          assert.isArray doc.items
          assert.greater doc.items.length, 0
          assert.isTrue _.any(doc.items, (item) ->
            item.id is act.id
          )
          return

      "and we check the major feed":
        topic: (act, cred) ->
          cb = @callback
          url = "http://localhost:4815/api/user/snail/feed/major"
          httputil.getJSON url, cred, (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it's not in there": (err, doc, act) ->
          assert.ifError err
          assert.isObject doc
          assert.include doc, "items"
          assert.isArray doc.items
          assert.isTrue _.every(doc.items, (item) ->
            item.id isnt act.id
          )
          return

    "and we post a major activity to the minor feed":
      topic: (cred) ->
        cb = @callback
        act =
          verb: "post"
          object:
            id: "urn:uuid:830c20d8-4846-11e2-ba95-70f1a154e1aa"
            objectType: "audio"
            displayName: "Crassshhh!"
            url: "http://example.net/crassshhh"

        url = "http://localhost:4815/api/user/snail/feed/minor"
        httputil.postJSON url, cred, act, (err, doc, response) ->
          if err and err.statusCode >= 400 and err.statusCode < 500
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

suite["export"] module
