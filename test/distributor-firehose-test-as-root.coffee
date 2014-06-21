# distributor-firehose-test-as-root.js
#
# Test that distributor pings the firehose server
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
http = require("http")
querystring = require("querystring")
_ = require("underscore")
express = require("express")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
pj = httputil.postJSON
gj = httputil.getJSON
dialbackApp = require("./lib/dialback").dialbackApp
setupAppConfig = oauthutil.setupAppConfig
suite = vows.describe("firehose module interface")
suite.addBatch "When we set up the app":
  topic: ->
    setupAppConfig
      port: 80
      hostname: "social.localhost"
      firehose: "firehose.localhost"
    , @callback
    return

  "it works": (err, app) ->
    assert.ifError err
    assert.isObject app
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "and we set up a firehose dummy server":
    topic: (Firehose) ->
      app = express.createServer(express.bodyParser())
      callback = @callback
      app.post "/ping", (req, res, next) ->
        app.callback null, req.body  if app.callback
        res.writeHead 201
        res.end()
        return

      app.on "error", (err) ->
        callback err, null
        return

      app.listen 80, "firehose.localhost", ->
        callback null, app
        return

      return

    "it works": (err, app) ->
      assert.ifError err
      assert.isObject app
      return

    teardown: (app) ->
      app.close()  if app and app.close
      return

    "and we post a public note":
      topic: (app) ->
        callback = @callback
        Step (->
          newCredentials "ajax", "hero1c|me", "social.localhost", 80, this
          return
        ), ((err, cred) ->
          throw err  if err
          app.callback = @parallel()
          pj "http://social.localhost/api/user/ajax/feed", cred,
            verb: "post"
            to: [
              objectType: "collection"
              id: "http://activityschema.org/collection/public"
            ]
            object:
              objectType: "note"
              content: "Grrrrr!!!"
          , @parallel()
          return
        ), callback
        return

      "it works": (err, received, sent) ->
        assert.ifError err
        assert.isObject received
        assert.isObject sent
        return

suite["export"] module
