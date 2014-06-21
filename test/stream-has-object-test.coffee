# stream-test.js
#
# Test the stream module
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
_ = require("underscore")
assert = require("assert")
vows = require("vows")
databank = require("databank")
Step = require("step")
fs = require("fs")
path = require("path")
URLMaker = require("../lib/urlmaker").URLMaker
modelBatch = require("./lib/model").modelBatch
schema = require("../lib/schema").schema
Databank = databank.Databank
DatabankObject = databank.DatabankObject
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite = vows.describe("stream has object")
suite.addBatch "When we create a stream and add some objects":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    stream = null
    Step (->
      db.connect {}, this
      return
    ), ((err) ->
      throw err  if err
      DatabankObject.bank = db
      Stream = require("../lib/model/stream").Stream
      Stream.create
        name: "has-object-test"
      , this
      return
    ), ((err, results) ->
      group = @group()
      throw err  if err
      stream = results
      _.times 100, (i) ->
        stream.deliverObject
          id: "http://social.example/image/" + i
          objectType: "image"
        , group()
        return

      return
    ), (err) ->
      if err
        cb err, null
      else
        cb null, stream
      return

    return

  "it works": (err, stream) ->
    assert.ifError err
    assert.isObject stream
    return

  "it has a hasObject() method": (err, stream) ->
    assert.ifError err
    assert.isFunction stream.hasObject
    return

  "and we check if it has an object we added":
    topic: (stream) ->
      stream.hasObject
        id: "http://social.example/image/69"
        objectType: "image"
      , @callback
      return

    "it does": (err, hasObject) ->
      assert.ifError err
      assert.isTrue hasObject
      return

  "and we check if it has an object we didn't add":
    topic: (stream) ->
      stream.hasObject
        id: "http://nonexistent.example/audio/23"
        objectType: "image"
      , @callback
      return

    "it does not": (err, hasObject) ->
      assert.ifError err
      assert.isFalse hasObject
      return

suite["export"] module
