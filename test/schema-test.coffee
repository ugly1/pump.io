# schema-test.js
#
# Test the schema module
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
types = [
  "accesstoken"
  "activity"
  "alert"
  "application"
  "article"
  "audio"
  "badge"
  "binary"
  "bookmark"
  "client"
  "collection"
  "comment"
  "confirmation"
  "credentials"
  "device"
  "dialbackrequest"
  "edge"
  "event"
  "favorite"
  "file"
  "game"
  "group"
  "host"
  "image"
  "issue"
  "job"
  "membership"
  "nonce"
  "note"
  "offer"
  "organization"
  "other"
  "page"
  "person"
  "place"
  "process"
  "product"
  "proxy"
  "question"
  "recovery"
  "recentdialbackrequests"
  "remoteaccesstoken"
  "remoterequesttoken"
  "requesttoken"
  "review"
  "service"
  "session"
  "share"
  "stream"
  "streamcount"
  "streamsegment"
  "streamsegmentcount"
  "streamsegments"
  "task"
  "user"
  "usercount"
  "userlist"
  "video"
]
vows.describe("schema module interface").addBatch("When we require the schema module":
  topic: ->
    require "../lib/schema"

  "we get a module": (schemamodule) ->
    assert.isObject schemamodule
    return

  "and we get its schema":
    topic: (schemamodule) ->
      schemamodule.schema

    "it exists": (schema) ->
      assert.isObject schema
      return

    "it has all the types we expect": (schema) ->
      i = undefined
      type = undefined
      i = 0
      while i < types.length
        type = types[i]
        assert.include schema, type
        i++
      return

    "it has no types we do not expect": (schema) ->
      prop = undefined
      for prop of schema
        assert.include types, prop  if schema.hasOwnProperty(prop)
      return

    "all its types are objects": (schema) ->
      prop = undefined
      for prop of schema
        assert.isObject schema[prop]  if schema.hasOwnProperty(prop)
      return

    "all its types have pkeys": (schema) ->
      prop = undefined
      for prop of schema
        if schema.hasOwnProperty(prop)
          assert.include schema[prop], "pkey"
          assert.isString schema[prop].pkey
      return
)["export"] module
