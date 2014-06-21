# spamicity-test.js
#
# Test the spamicity settings
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
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
newClient = oauthutil.newClient
newCredentials = oauthutil.newCredentials
setupAppConfig = oauthutil.setupAppConfig
suite = vows.describe("spamicity module interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we set up an activity spam dummy server":
  topic: ->
    app = express.createServer(express.bodyParser())
    callback = @callback
    app.post "/is-this-spam", (req, res, next) ->
      app.callback null, req.body  if app.callback
      if app.isSpam
        res.json
          probability: 0.999
          isSpam: true
          bestKeys: [
            [
              "a"
              0.999
            ]
            [
              "b"
              0.999
            ]
            [
              "c"
              0.999
            ]
            [
              "d"
              0.999
            ]
            [
              "e"
              0.999
            ]
            [
              "f"
              0.999
            ]
            [
              "g"
              0.999
            ]
            [
              "h"
              0.999
            ]
            [
              "i"
              0.999
            ]
            [
              "j"
              0.999
            ]
            [
              "k"
              0.999
            ]
            [
              "l"
              0.999
            ]
            [
              "m"
              0.999
            ]
            [
              "n"
              0.999
            ]
            [
              "o"
              0.999
            ]
          ]

      else
        res.json
          probability: 0.001
          isSpam: false
          bestKeys: [
            [
              "a"
              0.001
            ]
            [
              "b"
              0.001
            ]
            [
              "c"
              0.001
            ]
            [
              "d"
              0.001
            ]
            [
              "e"
              0.001
            ]
            [
              "f"
              0.001
            ]
            [
              "g"
              0.001
            ]
            [
              "h"
              0.001
            ]
            [
              "i"
              0.001
            ]
            [
              "j"
              0.001
            ]
            [
              "k"
              0.001
            ]
            [
              "l"
              0.001
            ]
            [
              "m"
              0.001
            ]
            [
              "n"
              0.001
            ]
            [
              "o"
              0.001
            ]
          ]

      return

    app.post "/this-is-spam", (req, res, next) ->
      app.callback null, req.body  if app.callback
      res.json
        cat: "spam"
        object: {}
        date: Date.now()
        elapsed: 100
        hash: "1234567890123456789012"

      return

    app.post "/this-is-ham", (req, res, next) ->
      app.callback null, req.body  if app.callback
      res.json
        cat: "ham"
        object: {}
        date: Date.now()
        elapsed: 100
        hash: "1234567890123456789012"

      return

    app.listen 80, "activityspam.localhost", ->
      callback null, app
      return

    return

  "it works": (err, app) ->
    assert.ifError err
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "and we start a pump app with the spam server configured":
    topic: (spam) ->
      setupAppConfig
        port: 80
        hostname: "social.localhost"
        driver: tc.driver
        spamhost: "http://activityspam.localhost"
        spamclientid: "AAAAAAAAA"
        spamclientsecret: "BBBBBBBB"
        params: tc.params
      , @callback
      return

    "it works": (err, app) ->
      assert.ifError err
      return

    teardown: (app) ->
      app.close()  if app and app.close
      return

    "and we get new credentials":
      topic: (social, spam) ->
        newCredentials "ann", "1day@atime", "social.localhost", 80, @callback
        return

      "it works": (err, cred) ->
        assert.ifError err
        assert.isObject cred
        return

      "and we post a non-spam activity from a local user":
        topic: (cred, social, spam) ->
          callback = @callback
          Step (->
            spam.isSpam = false
            spam.callback = @parallel()
            httputil.postJSON "http://social.localhost/api/user/ann/feed", cred,
              verb: "post"
              object:
                objectType: "note"
                content: "This is it."
            , @parallel()
            return
          ), callback
          return

        "it works": (err, tested, result) ->
          assert.ifError err
          assert.isObject tested
          assert.isObject result
          return

        "and we post a spam activity from a local user":
          topic: (tested, result, cred, social, spam) ->
            callback = @callback
            Step (->
              spam.isSpam = true
              spam.callback = @parallel()
              httputil.postJSON "http://social.localhost/api/user/ann/feed", cred,
                verb: "post"
                object:
                  objectType: "note"
                  content: "Just keep doing what you do."
              , @parallel()
              return
            ), (err, body, resp) ->
              if err and err.statusCode is 400
                callback null
              else if err
                callback err
              else
                callback new Error("Unexpected success")
              return

            return

          "it fails correctly": (err) ->
            assert.ifError err
            return

  "and we start a pump app with no spam server configured":
    topic: (spam) ->
      setupAppConfig
        port: 80
        hostname: "photo.localhost"
        driver: tc.driver
        params: tc.params
      , @callback
      return

    "it works": (err, app) ->
      assert.ifError err
      return

    teardown: (app) ->
      app.close()  if app and app.close
      return

    "and we get new credentials":
      topic: (photo, spam) ->
        newCredentials "julie", "1day@atime", "photo.localhost", 80, @callback
        return

      "it works": (err, cred) ->
        assert.ifError err
        assert.isObject cred
        return

      "and we post a non-spam activity from a local user":
        topic: (cred, photo, spam) ->
          callback = @callback
          httputil.postJSON "http://photo.localhost/api/user/julie/feed", cred,
            verb: "post"
            object:
              objectType: "note"
              content: "This is it."
          , callback
          return

        "it works": (err, body, result) ->
          assert.ifError err
          assert.isObject body
          assert.isObject result
          return

suite["export"] module
