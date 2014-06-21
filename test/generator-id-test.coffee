# generator-test.js
#
# Test that generator has the same ID twice
#
# Copyright 2012,2013, E14N https://e14n.com/
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
newPair = oauthutil.newPair
newClient = oauthutil.newClient
ignore = (err) ->

suite = vows.describe("Activity generator attribute")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret


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

  "and we register a new client":
    topic: ->
      cb = @callback
      params =
        application_name: "Generator Test"
        type: "client_associate"
        application_type: "native"

      Step (->
        httputil.post "localhost", 4815, "/api/client/register", params, this
        return
      ), ((err, res, body) ->
        cl = undefined
        throw err  if err
        cl = JSON.parse(body)
        this null, cl
        return
      ), cb
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      assert.include cl, "client_id"
      assert.include cl, "client_secret"
      return

    "and we register a user":
      topic: (cl) ->
        newPair cl, "george", "sleeping1", @callback
        return

      "it works": (err, pair) ->
        assert.ifError err
        assert.isObject pair
        return

      "and we post two notes with the same credentials":
        topic: (pair, cl) ->
          cb = @callback
          cred = makeCred(cl, pair)
          url = "http://localhost:4815/api/user/george/feed"
          act =
            verb: "post"
            object:
              objectType: "note"
              content: "Hello, world!"

          first = undefined
          second = undefined
          Step (->
            httputil.postJSON url, cred, act, this
            return
          ), ((err, doc, resp) ->
            throw err  if err
            first = doc
            httputil.postJSON url, cred, act, this
            return
          ), (err, doc, resp) ->
            if err
              cb err, null, null
            else
              second = doc
              cb null, first, second
            return

          return

        "the generator IDs are the same": (err, first, second) ->
          assert.ifError err
          assert.isObject first
          assert.isObject first.generator
          assert.isObject second
          assert.isObject second.generator
          assert.equal first.generator.id, second.generator.id
          return

suite["export"] module
