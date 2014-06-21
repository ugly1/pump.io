# register-web-ui-test.js
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
suite = vows.describe("layout test")

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

  "and we visit the root URL":
    topic: ->
      browser = undefined
      callback = @callback
      browser = new Browser()
      browser.visit "http://localhost:4815/main/register", (err, br) ->
        callback err, br
        return

      return

    "it works": (err, br) ->
      assert.ifError err
      assert.isTrue br.success
      return

    "and we check the content":
      topic: (br) ->
        callback = @callback
        callback null, br
        return

      "it includes a registration div": (err, br) ->
        assert.ok br.query("div#registerpage")
        return

      "it includes a registration form": (err, br) ->
        assert.ok br.query("div#registerpage form")
        return

      "the registration form has a nickname field": (err, br) ->
        assert.ok br.query("div#registerpage form input[name=\"nickname\"]")
        return

      "the registration form has a password field": (err, br) ->
        assert.ok br.query("div#registerpage form input[name=\"password\"]")
        return

      "the registration form has a password repeat field": (err, br) ->
        assert.ok br.query("div#registerpage form input[name=\"repeat\"]")
        return

      "the registration form has a submit button": (err, br) ->
        assert.ok br.query("div#registerpage form button[type=\"submit\"]")
        return

      "and we submit the form":
        topic: ->
          callback = @callback
          br = arguments_[0]
          Step (->
            br.fill "nickname", "sparks", this
            return
          ), ((err) ->
            throw err  if err
            br.fill "password", "redplainsrider1", this
            return
          ), ((err) ->
            throw err  if err
            br.fill "repeat", "redplainsrider1", this
            return
          ), ((err) ->
            throw err  if err
            br.pressButton "button[type=\"submit\"]", this
            return
          ), (err) ->
            if err
              callback err, null
            else
              callback null, br
            return

          return

        "it works": (err, br) ->
          assert.ifError err
          assert.isTrue br.success
          return

suite["export"] module
