# login-web-ui-test.js
#
# Test that the home page shows an invitation to join
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
oauthutil = require("./lib/oauth")
Browser = require("zombie")
Step = require("step")
setupApp = oauthutil.setupApp
setupAppConfig = oauthutil.setupAppConfig
newCredentials = oauthutil.newCredentials
suite = vows.describe("login web UI test")

# A batch to test some of the layout basics
suite.addBatch "When we set up the app":
  topic: ->
    setupAppConfig
      site: "Test"
    , @callback
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "it works": (err, app) ->
    assert.ifError err
    return

  "and we register a user with the API":
    topic: ->
      newCredentials "croach", "ihave1onus", "localhost", 4815, @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.ok cred
      return

    "and we visit the login URL":
      topic: ->
        browser = undefined
        browser = new Browser(runScripts: true)
        browser.visit "http://localhost:4815/main/login", @callback
        return

      "it works": (err, br) ->
        assert.ifError err
        assert.isTrue br.success
        return

      "and we check the content":
        topic: (br) ->
          br

        "it includes a login div": (br) ->
          assert.ok br.query("div#loginpage")
          return

        "it includes a login form": (br) ->
          assert.ok br.query("div#loginpage form")
          return

        "the login form has a nickname field": (br) ->
          assert.ok br.query("div#loginpage form input[name=\"nickname\"]")
          return

        "the login form has a password field": (br) ->
          assert.ok br.query("div#loginpage form input[name=\"password\"]")
          return

        "the login form has a submit button": (br) ->
          assert.ok br.query("div#loginpage form button[type=\"submit\"]")
          return

suite["export"] module
