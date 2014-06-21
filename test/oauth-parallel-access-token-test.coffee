# oauth-test.js
#
# Test the client registration API
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
requestToken = oauthutil.requestToken
newClient = oauthutil.newClient
register = oauthutil.register
accessToken = oauthutil.accessToken
ignore = (err) ->

suite = vows.describe("OAuth parallel access tokens")

# A batch to test lots of parallel access token requests
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

  "and we get a lot of access tokens in parallel for a single client":
    topic: ->
      cb = @callback
      cl = undefined
      Step (->
        newClient this
        return
      ), ((err, res) ->
        i = undefined
        group = @group()
        throw err  if err
        cl = res
        i = 0
        while i < 25
          register cl, "testuser" + i, "Aigae0aL" + i, group()
          i++
        return
      ), ((err, users) ->
        i = undefined
        group = @group()
        throw err  if err
        i = 0
        while i < 25
          accessToken cl,
            nickname: "testuser" + i
            password: "Aigae0aL" + i
          , group()
          i++
        return
      ), (err, pairs) ->
        if err
          cb err, null
        else
          cb null, pairs
        return

      return

    "it works": (err, pairs) ->
      i = undefined
      assert.ifError err
      assert.isArray pairs
      assert.lengthOf pairs, 25
      i = 0
      while i < pairs.length
        assert.include pairs[i], "token"
        assert.isString pairs[i].token
        assert.include pairs[i], "token_secret"
        assert.isString pairs[i].token_secret
        i++
      return

suite["export"] module
