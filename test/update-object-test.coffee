# update-object-test.js
#
# Test that updated data is reflected in earlier activities
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
http = require("http")
version = require("../lib/version").version
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
setupApp = oauthutil.setupApp
register = oauthutil.register
newClient = oauthutil.newClient
newPair = oauthutil.newPair
newCredentials = oauthutil.newCredentials
validActivityObject = actutil.validActivityObject
suite = vows.describe("Update object test")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret


# A batch for testing that updated information is updated
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

  "and we get more information about an object":
    topic: ->
      callback = @callback
      cl = undefined
      pair1 = undefined
      pair2 = undefined
      liked1 = undefined
      liked2 = undefined
      Step (->
        newClient this
        return
      ), ((err, results) ->
        throw err  if err
        cl = results
        newPair cl, "pault", "dont*get*drunk", @parallel()
        newPair cl, "ebans", "jazzy*rascal", @parallel()
        return
      ), ((err, results1, results2) ->
        act = undefined
        throw err  if err
        pair1 = results1
        pair2 = results2
        act =
          verb: "like"
          object:
            id: "urn:uuid:484e5278-8675-11e2-bd8f-70f1a154e1aa"
            links:
              self:
                href: "http://somewhereelse.example/note/1"

            objectType: "note"

        httputil.postJSON "http://localhost:4815/api/user/pault/feed", makeCred(cl, pair1), act, this
        return
      ), ((err, results1) ->
        act = undefined
        throw err  if err
        liked1 = results1
        act =
          verb: "like"
          object:
            id: "urn:uuid:484e5278-8675-11e2-bd8f-70f1a154e1aa"
            links:
              self:
                href: "http://somewhereelse.example/note/1"

            objectType: "note"
            content: "Hello, world!"

        httputil.postJSON "http://localhost:4815/api/user/ebans/feed", makeCred(cl, pair2), act, this
        return
      ), ((err, results2) ->
        throw err  if err
        liked2 = results2
        httputil.getJSON liked1.links.self.href, makeCred(cl, pair1), this
        return
      ), (err, results1, response) ->
        callback err, results1
        return

      return

    "it works": (err, act) ->
      assert.ifError err
      assert.isObject act
      return

    "object has been updated": (err, act) ->
      assert.ifError err
      assert.isObject act
      assert.isObject act.object
      assert.equal act.object.content, "Hello, world!"
      return

  "and we get more information about a locally-created object":
    topic: ->
      callback = @callback
      cl = undefined
      pair1 = undefined
      pair2 = undefined
      posted = undefined
      liked = undefined
      Step (->
        newClient this
        return
      ), ((err, results) ->
        throw err  if err
        cl = results
        newPair cl, "johnc", "i-heart-dragets", @parallel()
        newPair cl, "johnl", "jwbooth4life", @parallel()
        return
      ), ((err, results1, results2) ->
        act = undefined
        throw err  if err
        pair1 = results1
        pair2 = results2
        act =
          verb: "post"
          object:
            objectType: "note"
            content: "Hello, world."

        httputil.postJSON "http://localhost:4815/api/user/johnc/feed", makeCred(cl, pair1), act, this
        return
      ), ((err, results1) ->
        act = undefined
        throw err  if err
        posted = results1
        act =
          verb: "like"
          object:
            id: posted.object.id
            objectType: posted.object.objectType
            content: "Hello, buttheads."

        httputil.postJSON "http://localhost:4815/api/user/johnl/feed", makeCred(cl, pair2), act, this
        return
      ), ((err, results2) ->
        throw err  if err
        liked = results2
        httputil.getJSON posted.object.links.self.href, makeCred(cl, pair1), this
        return
      ), (err, results1, response) ->
        callback err, results1
        return

      return

    "it works": (err, note) ->
      assert.ifError err
      assert.isObject note
      return

    "object has not been updated": (err, note) ->
      assert.ifError err
      validActivityObject note
      assert.equal note.content, "Hello, world."
      return

suite["export"] module
