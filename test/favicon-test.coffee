# favicon-test.js
#
# Test that a favicon is provided
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
oauthutil = require("./lib/oauth")
Browser = require("zombie")
Step = require("step")
http = require("http")
fs = require("fs")
path = require("path")
setupApp = oauthutil.setupApp
setupAppConfig = oauthutil.setupAppConfig
newCredentials = oauthutil.newCredentials
suite = vows.describe("favicon.ico test")
httpGet = (url, callback) ->
  http.get(url, (res) ->
    data = new Buffer(0)
    res.on "data", (chunk) ->
      data = Buffer.concat([
        data
        chunk
      ])
      return

    res.on "error", (err) ->
      callback err, null, null
      return

    res.on "end", ->
      callback null, data, res
      return

    return
  ).on "error", (err) ->
    callback err, null, null
    return

  return

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

  "and we retrieve the favicon":
    topic: ->
      httpGet "http://localhost:4815/favicon.ico", @callback
      return

    "it works": (err, body, resp) ->
      assert.ifError err
      assert.isObject body
      assert.instanceOf body, Buffer
      assert.isObject resp
      assert.instanceOf resp, http.IncomingMessage
      assert.equal resp.statusCode, 200
      return

    "buffer is not empty": (err, body, resp) ->
      assert.ifError err
      assert.isObject body
      assert.instanceOf body, Buffer
      assert.greater body.length, 0
      return

    "and we get our default favicon":
      topic: (body) ->
        callback = @callback
        fs.readFile path.resolve(__dirname, "../public/images/favicon.ico"), (err, data) ->
          if err
            callback err, null, null
          else
            callback null, data, body
          return

        return

      "it works": (err, data, body) ->
        assert.ifError err
        assert.isObject data
        assert.instanceOf data, Buffer
        assert.greater data.length, 0
        return

      "the buffers are the same": (err, data, body) ->
        i = undefined
        assert.ifError err
        assert.ok Buffer.isBuffer(data)
        assert.ok Buffer.isBuffer(body)
        assert.equal data.length, body.length
        i = 0
        while i < data.length
          assert.equal data[i], body[i]
          i++
        return

suite.addBatch "When we set up the app with a custom favicon":
  topic: ->
    fname = path.resolve(__dirname, "data/all-black-favicon.ico")
    setupAppConfig
      favicon: fname
      site: "h4X0r h4v3n"
    , @callback
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "it works": (err, app) ->
    assert.ifError err
    return

  "and we retrieve the favicon":
    topic: ->
      httpGet "http://localhost:4815/favicon.ico", @callback
      return

    "it works": (err, body, resp) ->
      assert.ifError err
      assert.isObject body
      assert.instanceOf body, Buffer
      assert.isObject resp
      assert.instanceOf resp, http.IncomingMessage
      assert.equal resp.statusCode, 200
      return

    "buffer is not empty": (err, body, resp) ->
      assert.ifError err
      assert.isObject body
      assert.instanceOf body, Buffer
      assert.greater body.length, 0
      return

    "and we get our configured favicon":
      topic: (body) ->
        callback = @callback
        fs.readFile path.resolve(__dirname, "data/all-black-favicon.ico"), (err, data) ->
          if err
            callback err, null, null
          else
            callback null, data, body
          return

        return

      "it works": (err, data, body) ->
        assert.ifError err
        assert.isObject data
        assert.instanceOf data, Buffer
        assert.greater data.length, 0
        return

      "the buffers are the same": (err, data, body) ->
        i = undefined
        assert.ifError err
        assert.ok Buffer.isBuffer(data)
        assert.ok Buffer.isBuffer(body)
        assert.equal data.length, body.length
        i = 0
        while i < data.length
          assert.equal data[i], body[i]
          i++
        return

suite["export"] module
