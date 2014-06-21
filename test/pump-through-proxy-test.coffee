# pump-through-proxy-test.js
#
# Test running the app via a proxy
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
fs = require("fs")
path = require("path")
express = require("express")
databank = require("databank")
_ = require("underscore")
Step = require("step")
http = require("http")
https = require("https")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
activity = require("./lib/activity")
validUser = activity.validUser
validFeed = activity.validFeed
suite = vows.describe("proxy pump through another server")
makeUserCred = (cl, user) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: user.token
  token_secret: user.secret

tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we makeApp()":
  topic: ->
    config =
      port: 4815
      hostname: "localhost"
      urlPath: "pumpio"
      urlPort: 2342
      driver: tc.driver
      params: tc.params
      nologger: true
      sockjs: false

    process.env.NODE_ENV = "test"
    Step (->
      oauthutil.setupAppConfig config, @parallel()
      httputil.proxy
        front:
          hostname: "localhost"
          port: 2342
          path: "/pumpio"

        back:
          hostname: "localhost"
          port: 4815
      , @parallel()
      return
    ), @callback
    return

  "it works": (err, app, proxy) ->
    assert.ifError err
    assert.isObject app
    assert.isObject proxy
    return

  teardown: (app, proxy) ->
    app.close()  if app and _.isFunction(app.close)
    proxy.close()  if proxy and _.isFunction(proxy.close)
    return

  "and we GET the root through the proxy":
    topic: ->
      callback = @callback
      req = undefined
      req = http.get("http://localhost:2342/pumpio/", (res) ->
        body = ""
        res.on "data", (chunk) ->
          body = body + chunk
          return

        res.on "end", ->
          callback null, res, body
          return

        res.on "error", (err) ->
          callback err, null, null
          return

        return
      )
      req.on "error", (err) ->
        callback err, null
        return

      return

    "it works": (err, res, body) ->
      assert.ifError err
      return

    "it has the correct results": (err, res, body) ->
      assert.ifError err
      assert.equal res.statusCode, 200
      assert.isObject res.headers
      assert.include res.headers, "content-type"
      assert.equal "text/html", res.headers["content-type"].substr(0, "text/html".length)
      return

  "and we register a client":
    topic: ->
      oauthutil.newClient "localhost", 2342, "/pumpio", @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and we register a user":
      topic: (cl) ->
        oauthutil.register cl, "paulrevere", "1ifbyland2ifbysea", "localhost", 2342, "/pumpio", @callback
        return

      "it works": (err, user) ->
        assert.ifError err
        validUser user
        return

      "and we get the user's inbox":
        topic: (user, cl) ->
          callback = @callback
          cred = makeUserCred(cl, user)
          url = "http://localhost:2342/pumpio/api/user/paulrevere/inbox"
          httputil.getJSON url, cred, (err, body, resp) ->
            callback err, body
            return

          return

        "it works": (err, body) ->
          assert.ifError err
          validFeed body
          return

  "and we GET the root directly":
    topic: ->
      callback = @callback
      req = undefined
      req = http.get("http://localhost:4815/", (res) ->
        body = ""
        res.on "data", (chunk) ->
          body = body + chunk
          return

        res.on "end", ->
          callback null, res, body
          return

        res.on "error", (err) ->
          callback err, null, null
          return

        return
      )
      req.on "error", (err) ->
        callback err, null
        return

      return

    "it works": (err, res, body) ->
      assert.ifError err
      return

    "it has the correct results": (err, res, body) ->
      assert.ifError err
      assert.equal res.statusCode, 200
      assert.isObject res.headers
      assert.include res.headers, "content-type"
      assert.equal "text/html", res.headers["content-type"].substr(0, "text/html".length)
      return

  "and we register a client directly":
    topic: ->
      oauthutil.newClient "localhost", 4815, @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and we register a user directly":
      topic: (cl) ->
        oauthutil.register cl, "samueladams", "liberty*guys", "localhost", 4815, @callback
        return

      "it works": (err, user) ->
        assert.ifError err
        validUser user
        return

      "and we get the user's inbox":
        topic: (user, cl) ->
          callback = @callback
          cred = makeUserCred(cl, user)
          url = "http://localhost:4815/api/user/samueladams/inbox"
          httputil.getJSON url, cred, (err, body, resp) ->
            callback err, body
            return

          return

        "it works": (err, body) ->
          assert.ifError err
          validFeed body
          return

suite["export"] module
