# app-test.js
#
# Test that plugin endpoints are called
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
Step = require("step")
_ = require("underscore")
assert = require("assert")
vows = require("vows")
fs = require("fs")
path = require("path")
oauthutil = require("./lib/oauth")
httputil = require("./lib/http")
ignore = (err) ->

suite = vows.describe("app module interface")
suite.addBatch "When we get the app module":
  topic: ->
    require "../lib/app"

  "there is one": (mod) ->
    assert.isObject mod
    return

  "it has the makeApp() export": (mod) ->
    assert.isFunction mod.makeApp
    return

tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we makeApp() with a named plugin":
  topic: ->
    config =
      port: 4815
      hostname: "localhost"
      driver: tc.driver
      params: tc.params
      nologger: true
      sockjs: false
      plugins: ["../test/lib/plugin"]

    makeApp = require("../lib/app").makeApp
    process.env.NODE_ENV = "test"
    makeApp config, @callback
    return

  "it works": (err, app) ->
    assert.ifError err
    assert.isObject app
    return

  "the plugin log endpoint was called": (err, app) ->
    plugin = require("./lib/plugin")
    assert.ifError err
    assert.isTrue plugin.called.log
    return

  "the plugin schema endpoint was called": (err, app) ->
    plugin = require("./lib/plugin")
    assert.ifError err
    assert.isTrue plugin.called.schema
    return

  "the plugin app endpoint was called": (err, app) ->
    plugin = require("./lib/plugin")
    assert.ifError err
    assert.isTrue plugin.called.app
    return

  "and we run the app":
    topic: (app) ->
      app.run @callback
      return

    "it works": (err) ->
      assert.ifError err
      return

    teardown: (app) ->
      if app and app.close
        app.close (err) ->

      return

    "and we create an activity":
      topic: ->
        callback = @callback
        Step (->
          oauthutil.newCredentials "aang", "air*bender", @parallel()
          oauthutil.newCredentials "katara", "water*bender", @parallel()
          return
        ), ((err, cred, cred2) ->
          url = undefined
          activity = undefined
          throw err  if err
          url = "http://localhost:4815/api/user/aang/feed"
          activity =
            verb: "post"
            to: [cred2.user.profile]
            cc: [
              objectType: "collection"
              id: cred.user.profile.followers.url
            ]
            object:
              objectType: "note"
              content: "Hello, world."

          httputil.postJSON url, cred, activity, this
          return
        ), (err) ->
          callback err
          return

        return

      "the plugin distributor endpoint was called": (err, app) ->
        plugin = require("./lib/plugin")
        assert.ifError err
        assert.isTrue plugin.called.distribute
        return

      "the plugin distributeActivityToUser endpoint was called": (err, app) ->
        plugin = require("./lib/plugin")
        assert.ifError err
        assert.isTrue plugin.called.touser
        return

suite["export"] module
