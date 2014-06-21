# app-test.js
#
# Test the app module
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
fs = require("fs")
path = require("path")
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
suite.addBatch "When we makeApp()":
  topic: ->
    config =
      port: 4815
      hostname: "localhost"
      driver: tc.driver
      params: tc.params
      nologger: true
      sockjs: false

    makeApp = require("../lib/app").makeApp
    process.env.NODE_ENV = "test"
    makeApp config, @callback
    return

  "it works": (err, app) ->
    assert.ifError err
    assert.isObject app
    return

  "app has the run() method": (err, app) ->
    assert.isFunction app.run
    return

  "app has the config property": (err, app) ->
    assert.isObject app.config
    assert.include app.config, "hostname"
    assert.equal app.config.hostname, "localhost"
    return

  "and we app.run()":
    topic: (app) ->
      cb = @callback
      app.run (err) ->
        if err
          cb err, null
        else
          cb null, app
        return

      return

    "it works": (err, app) ->
      assert.ifError err
      return

    "app is listening on correct port": (err, app) ->
      addr = app.address()
      assert.equal addr.port, 4815
      return

    teardown: (app) ->
      app.close()  if app and app.close
      return

suite["export"] module
