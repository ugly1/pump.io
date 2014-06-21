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
schema = require("../lib/schema").schema
Databank = databank.Databank
DatabankObject = databank.DatabankObject
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite = vows.describe("stream index tests")
MAX = 10000
SOME = 3000
suite.addBatch "When we create a new stream":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      Stream = undefined
      mod = undefined
      if err
        cb err, null
        return
      DatabankObject.bank = db
      mod = require("../lib/model/stream")
      unless mod
        cb new Error("No module"), null
        return
      Stream = mod.Stream
      unless Stream
        cb new Error("No class"), null
        return
      Stream.create
        name: "index-test"
      , cb
      return

    return

  "it works": (err, stream) ->
    assert.ifError err
    assert.isObject stream
    return

  "and we add a bunch of integers":
    topic: (stream) ->
      cb = @callback
      Step (->
        i = undefined
        group = @group()
        i = MAX - 1
        while i >= 0
          stream.deliver i, group()
          i--
        return
      ), (err) ->
        cb err
        return

      return

    "it works": (err) ->
      assert.ifError err
      return

    "and we get them all out":
      topic: (stream) ->
        stream.getItems 0, MAX, @callback
        return

      "it works": (err, items) ->
        assert.ifError err
        assert.isArray items
        assert.equal items.length, MAX
        return

      "and we get each one's index":
        topic: (items, stream) ->
          cb = @callback
          Step (->
            i = undefined
            group = @group()
            i = 0
            while i < MAX
              stream.indexOf items[i], group()
              i++
            return
          ), cb
          return

        "it works": (err, indices) ->
          i = undefined
          assert.ifError err
          assert.isArray indices
          assert.lengthOf indices, MAX
          i = 0
          while i < indices.length
            assert.equal indices[i], i
            i++
          return

    "and we get SOME out":
      topic: (stream) ->
        stream.getItems 0, SOME, @callback
        return

      "it works": (err, items) ->
        assert.ifError err
        assert.isArray items
        assert.equal items.length, SOME
        return

      "and we get each one's index":
        topic: (items, stream) ->
          cb = @callback
          Step (->
            i = undefined
            group = @group()
            i = 0
            while i < SOME
              stream.indexOf items[i], group()
              i++
            return
          ), cb
          return

        "it works": (err, indices) ->
          i = undefined
          assert.ifError err
          assert.isArray indices
          assert.lengthOf indices, SOME
          i = 0
          while i < indices.length
            assert.equal indices[i], i
            i++
          return

suite["export"] module
