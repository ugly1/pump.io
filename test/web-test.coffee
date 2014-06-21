# web-test.js
#
# Test the web module
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
fs = require("fs")
path = require("path")
assert = require("assert")
express = require("express")
vows = require("vows")
Step = require("step")
suite = vows.describe("web module interface")
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"
suite.addBatch "When we require the web module":
  topic: ->
    require "../lib/web"

  "it returns an object": (web) ->
    assert.isObject web
    return

  "and we check its methods":
    topic: (web) ->
      web

    "it has a mod method": (web) ->
      assert.isFunction web.mod
      return

    "it has an http method": (web) ->
      assert.isFunction web.http
      return

    "it has an https method": (web) ->
      assert.isFunction web.https
      return

    "and we set up an http server":
      topic: (web) ->
        app = express.createServer()
        callback = @callback
        app.get "/foo", (req, res, next) ->
          res.send "Hello, world."
          return

        app.on "error", (err) ->
          callback err, null
          return

        app.listen 1623, "localhost", ->
          callback null, app
          return

        return

      "it works": (err, app) ->
        assert.ifError err
        assert.isObject app
        return

      teardown: (app) ->
        if app and app.close
          app.close (err) ->

        return

      "and we make an http request":
        topic: (app, web) ->
          callback = @callback
          options =
            host: "localhost"
            port: 1623
            path: "/foo"

          web.http options, (err, res) ->
            if err
              callback err, null
            else
              callback null, res
            return

          return

        "it works": (err, res) ->
          assert.ifError err
          assert.isObject res
          return

        "and we check the results":
          topic: (res) ->
            res

          "it has a statusCode": (res) ->
            assert.isNumber res.statusCode
            assert.equal res.statusCode, 200
            return

          "it has the right body": (res) ->
            assert.isString res.body
            assert.equal res.body, "Hello, world."
            return

    "and we set up an https server":
      topic: (web) ->
        key = path.join(__dirname, "data", "secure.localhost.key")
        cert = path.join(__dirname, "data", "secure.localhost.crt")
        app = undefined
        callback = @callback
        app = express.createServer(
          key: fs.readFileSync(key)
          cert: fs.readFileSync(cert)
        )
        app.get "/foo", (req, res, next) ->
          res.send "Hello, world."
          return

        app.on "error", (err) ->
          callback err, null
          return

        app.listen 2315, "secure.localhost", ->
          callback null, app
          return

        return

      "it works": (err, app) ->
        assert.ifError err
        assert.isObject app
        return

      teardown: (app) ->
        if app and app.close
          app.close (err) ->

        return

      "and we make an https request":
        topic: (app, web) ->
          callback = @callback
          options =
            host: "secure.localhost"
            port: 2315
            path: "/foo"

          web.https options, (err, res) ->
            if err
              callback err, null
            else
              callback null, res
            return

          return

        "it works": (err, res) ->
          assert.ifError err
          assert.isObject res
          return

        "and we check the results":
          topic: (res) ->
            res

          "it has a statusCode": (res) ->
            assert.isNumber res.statusCode
            assert.equal res.statusCode, 200
            return

          "it has the right body": (res) ->
            assert.isString res.body
            assert.equal res.body, "Hello, world."
            return

suite["export"] module
