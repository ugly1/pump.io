# provider-test.js
#
# Test the provider module
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
schema = require("../lib/schema")
URLMaker = require("../lib/urlmaker").URLMaker
randomString = require("../lib/randomstring").randomString
Client = require("../lib/model/client").Client
RequestToken = require("../lib/model/requesttoken").RequestToken
AccessToken = require("../lib/model/accesstoken").AccessToken
User = require("../lib/model/user").User
methodContext = require("./lib/methods").methodContext
Databank = databank.Databank
DatabankObject = databank.DatabankObject
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))

# Need this to make IDs

# Dummy databank
vows.describe("provider module interface").addBatch("When we get the provider module":
  topic: ->
    cb = @callback
    URLMaker.hostname = "example.net"
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      mod = require("../lib/provider")
      DatabankObject.bank = db
      cb null, mod
      return

    return

  "there is one": (err, mod) ->
    assert.isObject mod
    return

  "and we get its Provider export":
    topic: (mod) ->
      mod.Provider

    "it exists": (Provider) ->
      assert.isFunction Provider
      return

    "and we create a new Provider with predefined keys":
      topic: (Provider) ->
        clients = [
          client_id: "AAAAAAAAAA"
          client_secret: "BBBBBBBBBB"
        ]
        new Provider(null, clients)

      "it exists": (provider) ->
        assert.isObject provider
        return

      "and we use applicationByConsumerKey() on a bogus key":
        topic: (provider) ->
          cb = @callback
          provider.applicationByConsumerKey "BOGUSCONSUMERKEY", (err, result) ->
            if err
              cb null
            else
              cb new Error("Got unexpected results")
            return

          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and we use applicationByConsumerKey() on a valid key":
        topic: (provider) ->
          callback = @callback
          Step (->
            Client.create
              title: "Test App"
              description: "App for testing"
            , this
            return
          ), ((err, client) ->
            throw err  if err
            provider.applicationByConsumerKey client.consumer_key, this
            return
          ), callback
          return

        "it works": (err, client) ->
          assert.ifError err
          assert.isObject client
          assert.instanceOf client, Client
          return

        "it has the right fields": (err, client) ->
          assert.isString client.consumer_key
          assert.isString client.secret
          return

      "and we use applicationByConsumerKey() on a configured key":
        topic: (provider) ->
          callback = @callback
          provider.applicationByConsumerKey "AAAAAAAAAA", callback
          return

        "it works": (err, client) ->
          assert.ifError err
          assert.isObject client
          return

        "it has the right fields": (err, client) ->
          assert.ifError err
          assert.isString client.consumer_key
          assert.isString client.secret
          return
)["export"] module
