# firehose-test.js
#
# Test the firehose module
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
suite = vows.describe("firehose module interface")
suite.addBatch "When we require the firehose module":
  topic: ->
    require "../lib/firehose"

  "it returns an object": (Firehose) ->
    assert.isObject Firehose
    return

  "and we check its methods":
    topic: (Firehose) ->
      Firehose

    "it has a setup method": (Firehose) ->
      assert.isFunction Firehose.setup
      return

    "it has a ping method": (Firehose) ->
      assert.isFunction Firehose.ping
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

      "and we call Firehose.setup()":
        topic: (app, Firehose) ->
          cb = @callback
          try
            Firehose.setup "firehose.localhost"
            cb null
          catch err
            cb err
          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we call Firehose.ping()":
          topic: (app, Firehose) ->
            callback = @callback
            act =
              actor:
                id: "user1@fake.example"
                objectType: "person"

              verb: "post"
              object:
                id: "urn:uuid:efbb2462-538c-11e2-9053-5cff35050cf2"
                objectType: "note"
                content: "Hello, world!"

            Step (->
              app.callback = @parallel()
              Firehose.ping act, @parallel()
              return
            ), callback
            return

          "it works": (err, body) ->
            assert.ifError err
            assert.isObject body
            return

suite["export"] module
