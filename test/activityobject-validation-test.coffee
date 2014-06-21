# activityobject-test.js
#
# Test that activityobjects are validated
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
databank = require("databank")
Step = require("step")
_ = require("underscore")
fs = require("fs")
path = require("path")
Databank = databank.Databank
DatabankObject = databank.DatabankObject
schema = require("../lib/schema").schema
URLMaker = require("../lib/urlmaker").URLMaker
suite = vows.describe("activityobject class interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we require the activityobject module":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      cls = undefined
      DatabankObject.bank = db
      cls = require("../lib/model/activityobject").ActivityObject or null
      cb null, cls
      return

    return

  "we get the constructor": (cls) ->
    assert.isFunction cls
    return

  "and we try to ensureObject with a non-string ID":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: [
          1
          2
          3
        ]
        objectType: "note"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with no ID":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        objectType: "note"
        content: "gar gar gar"

      ActivityObject.ensureObject props, (err, obj) ->
        if err
          callback err
        else
          callback null
        return

      return

    "it works": (err) ->
      assert.ifError err
      return

  "and we try to ensureObject with a non-string objectType":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:015a8bd6-b706-11e2-b87b-c8f73398600c"
        objectType:
          left: 1
          right: 2

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-string objectType":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:c6df5d5c-b713-11e2-9369-2c8158efb9e9"
        objectType:
          left: 1
          right: 2

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-array attachments property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:da0cea20-b713-11e2-8998-2c8158efb9e9"
        objectType: "note"
        attachments: 4

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-object in attachments property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:e4168198-b713-11e2-add9-2c8158efb9e9"
        objectType: "note"
        attachments: [
          1
          2
          3
          4
        ]

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid object in attachments property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:9f0cf252-b714-11e2-8bdb-2c8158efb9e9"
        objectType: "note"
        attachments: [
          left: 1
          right: 2
        ]

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-object author":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:1aa3bad6-b715-11e2-a3d3-2c8158efb9e9"
        objectType: "note"
        author: "acct:fred@social.example"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid author":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:613ed220-b718-11e2-85f9-2c8158efb9e9"
        objectType: "note"
        author:
          left: 1
          right: 2

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-string content":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:613ed220-b718-11e2-85f9-2c8158efb9e9"
        objectType: "note"
        content:
          head: "something"
          body: "something else"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-string displayName":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:ea3d349a-b718-11e2-a275-2c8158efb9e9"
        objectType: "person"
        displayName:
          first: "Captain"
          last: "Marvel"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-array downstreamDuplicates":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:56843b94-b719-11e2-8de5-2c8158efb9e9"
        objectType: "note"
        downstreamDuplicates: "http://example.net/note/1"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-string member of downstreamDuplicates":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:56843b94-b719-11e2-8de5-2c8158efb9e9"
        objectType: "note"
        downstreamDuplicates: [id: "http://example.net/note/1"]

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-array upstreamDuplicates":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:dabbdfa2-b72d-11e2-b49d-2c8158efb9e9"
        objectType: "note"
        upstreamDuplicates: "http://example.net/note/1"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-string member of upstreamDuplicates":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:e65dc726-b72d-11e2-9997-2c8158efb9e9"
        objectType: "note"
        upstreamDuplicates: [id: "http://example.net/note/1"]

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-object image property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:8d87c60a-b71a-11e2-9bad-2c8158efb9e9"
        objectType: "note"
        image: "http://example.net/image/cat.jpg"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid image property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:05ee5280-b71b-11e2-8bb8-2c8158efb9e9"
        objectType: "note"
        image:
          left: 1
          right: 2

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid image url":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:40879158-b71c-11e2-a889-2c8158efb9e9"
        objectType: "note"
        image:
          url:
            href: "http://example.net/image/dog.jpg"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid image width":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:40879158-b71c-11e2-a889-2c8158efb9e9"
        objectType: "note"
        image:
          url: "http://example.net/image/dog.jpg"
          width: "100"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid image height":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:5ef552d2-b71d-11e2-be48-2c8158efb9e9"
        objectType: "note"
        image:
          url: "http://example.net/image/dog.jpg"
          height: "100"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with an invalid image duration":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:5ef552d2-b71d-11e2-be48-2c8158efb9e9"
        objectType: "note"
        image:
          url: "http://example.net/image/dog.gif"
          duration: "100"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-string published property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:33757e98-b727-11e2-b2af-2c8158efb9e9"
        objectType: "note"
        published:
          year: 2013
          month: 10
          day: 14

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-string updated property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:cf1bd0fe-b72c-11e2-8d5b-2c8158efb9e9"
        objectType: "note"
        updated:
          year: 2013
          month: 10
          day: 14

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with a non-string summary property":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:9da9e5aa-b728-11e2-8c7f-2c8158efb9e9"
        objectType: "note"
        summary:
          mood: "enthusiastic"
          value: "great note!"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

  "and we try to ensureObject with non-string url":
    topic: (ActivityObject) ->
      callback = @callback
      props =
        id: "urn:uuid:af509816-b72e-11e2-823f-2c8158efb9e9"
        objectType: "note"
        url:
          href: "http://example.net/note/3"

      ActivityObject.ensureObject props, (err, obj) ->
        if err and err instanceof TypeError
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

suite["export"] module
