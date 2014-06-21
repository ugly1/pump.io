# stream-each-test.js
#
# Test the iterator interface to a stream
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
suite = vows.describe("stream iterator interface")
suite.addBatch "When we setup the env":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    stream = null
    db.connect {}, (err) ->
      if err
        cb err, null
        return
      DatabankObject.bank = db
      Stream = require("../lib/model/stream").Stream
      cb null, Stream
      return

    return

  "it works": (err, Stream) ->
    assert.ifError err
    return

  "and we create a stream":
    topic: (Stream) ->
      Stream.create
        name: "test-each-1"
      , @callback
      return

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream
      return

    "it has an each method": (err, stream) ->
      assert.ifError err
      assert.isFunction stream.each
      return

    "and we add 5000 ids":
      topic: (stream, Stream) ->
        cb = @callback
        Step (->
          i = undefined
          group = @group()
          i = 0
          while i < 5000
            stream.deliver "http://example.net/api/object/" + i, group()
            i++
          return
        ), (err) ->
          if err
            cb err
          else
            cb null
          return

        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we iterate over them":
        topic: (stream, Stream) ->
          count = 0
          callback = @callback
          stream.each ((item, callback) ->
            count++
            callback null
            return
          ), (err) ->
            callback err, count
            return

          return

        "it works": (err, count) ->
          assert.ifError err
          assert.isNumber count
          assert.equal count, 5000
          return

  "and we create another stream":
    topic: (Stream) ->
      Stream.create
        name: "test-each-2"
      , @callback
      return

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream
      return

    "and we iterate over the empty stream":
      topic: (stream, Stream) ->
        count = 0
        callback = @callback
        stream.each ((item, callback) ->
          count++
          callback null
          return
        ), (err) ->
          callback err, count
          return

        return

      "it works": (err, count) ->
        assert.ifError err
        assert.isNumber count
        assert.equal count, 0
        return

  "and we create yet another stream":
    topic: (Stream) ->
      Stream.create
        name: "test-each-3"
      , @callback
      return

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream
      return

    "and we add 5000 ids":
      topic: (stream, Stream) ->
        cb = @callback
        Step (->
          i = undefined
          group = @group()
          i = 0
          while i < 5000
            stream.deliver "http://example.net/api/object/" + i, group()
            i++
          return
        ), (err) ->
          if err
            cb err
          else
            cb null
          return

        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we iterate with a function that throws an exception":
        topic: (stream, Stream) ->
          theError = new Error("My test error")
          callback = @callback
          stream.each ((item, callback) ->
            throw theErrorreturn
          ), (err) ->
            if err is theError
              callback null
            else if err
              callback err
            else
              callback new Error("Unexpected success")
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

suite["export"] module
