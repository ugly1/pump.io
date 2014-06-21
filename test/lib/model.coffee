# model.js
#
# Test utility for databankobject model modules
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
_ = require("underscore")
vows = require("vows")
databank = require("databank")
Step = require("step")
fs = require("fs")
path = require("path")
URLMaker = require("../../lib/urlmaker").URLMaker
schema = require("../../lib/schema").schema
Databank = databank.Databank
DatabankObject = databank.DatabankObject
tc = JSON.parse(fs.readFileSync(path.resolve(__dirname, "..", "config.json")))
modelBatch = (typeName, className, testSchema, testData) ->
  batch = {}
  typeKey = "When we require the " + typeName + " module"
  classKey = "and we get its " + className + " class export"
  instKey = undefined
  if "aeiouAEIOU".indexOf(typeName.charAt(0)) isnt -1
    instKey = "and we create an " + typeName + " instance"
  else
    instKey = "and we create a " + typeName + " instance"
  batch[typeKey] =
    topic: ->
      cb = @callback
      
      # Need this to make IDs
      URLMaker.hostname = "example.net"
      
      # Dummy databank
      tc.params.schema = schema
      db = Databank.get(tc.driver, tc.params)
      db.connect {}, (err) ->
        mod = undefined
        DatabankObject.bank = db
        mod = require("../../lib/model/" + typeName) or null
        cb null, mod
        return

      return

    "there is one": (err, mod) ->
      assert.isObject mod
      return

    "it has a class export": (err, mod) ->
      assert.includes mod, className
      return

  batch[typeKey][classKey] =
    topic: (mod) ->
      mod[className] or null

    "it is a function": (Cls) ->
      assert.isFunction Cls
      return

    "it has an init method": (Cls) ->
      assert.isFunction Cls.init
      return

    "it has a bank method": (Cls) ->
      assert.isFunction Cls.bank
      return

    "it has a get method": (Cls) ->
      assert.isFunction Cls.get
      return

    "it has a search method": (Cls) ->
      assert.isFunction Cls.search
      return

    "it has a pkey method": (Cls) ->
      assert.isFunction Cls.pkey
      return

    "it has a create method": (Cls) ->
      assert.isFunction Cls.create
      return

    "it has a readAll method": (Cls) ->
      assert.isFunction Cls.readAll
      return

    "its type is correct": (Cls) ->
      assert.isString Cls.type
      assert.equal Cls.type, typeName
      return

    "and we get its schema":
      topic: (Cls) ->
        Cls.schema or null

      "it exists": (schema) ->
        assert.isObject schema
        return

      "it has the right pkey": (schema) ->
        assert.includes schema, "pkey"
        assert.equal schema.pkey, testSchema.pkey
        return

      "it has the right fields": (schema) ->
        fields = testSchema.fields
        i = undefined
        field = undefined
        if fields
          assert.includes schema, "fields"
          i = 0
          while i < fields.length
            assert.includes schema.fields, fields[i]
            i++
          i = 0
          while i < schema.fields.length
            assert.includes fields, schema.fields[i]
            i++
        return

      "it has the right indices": (schema) ->
        indices = testSchema.indices
        i = undefined
        field = undefined
        if indices
          assert.includes schema, "indices"
          i = 0
          while i < indices.length
            assert.includes schema.indices, indices[i]
            i++
          i = 0
          while i < schema.indices.length
            assert.includes indices, schema.indices[i]
            i++
        return

  batch[typeKey][classKey][instKey] =
    topic: (Cls) ->
      Cls.create testData.create, @callback
      return

    "it works correctly": (err, created) ->
      assert.ifError err
      assert.isObject created
      return

    "auto-generated fields are there": (err, created) ->
      assert.ifError err
      assert.isString created.objectType
      assert.equal created.objectType, typeName
      assert.isString created.id
      assert.isString created.published
      assert.isString created.updated # required for new object?
      return

    "passed-in fields are there": (err, created) ->
      prop = undefined
      aprop = undefined
      assert.ifError err
      for prop of testData.create
        
        # Author may have auto-created properties
        if _.contains([
          "author"
          "inReplyTo"
        ], prop)
          _.each testData.create[prop], (value, key) ->
            assert.deepEqual created[prop][key], value
            return

        else
          assert.deepEqual created[prop], testData.create[prop]
      return

    "and we modify it":
      topic: (created) ->
        callback = @callback
        created.update testData.update, callback
        return

      "it is modified": (err, updated) ->
        assert.ifError err
        assert.isString updated.updated
        return

      "modified fields are modified": (err, updated) ->
        prop = undefined
        for prop of testData.update
          assert.deepEqual updated[prop], testData.update[prop]
        return

      "and we delete it":
        topic: (updated) ->
          updated.del @callback
          return

        "it works": (err, updated) ->
          assert.ifError err
          return

  batch

exports.modelBatch = modelBatch
