# host-test.js
#
# Test the host module
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
URLMaker = require("../lib/urlmaker").URLMaker
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("host module interface")
testSchema =
  pkey: "hostname"
  fields: [
    "registration_endpoint"
    "request_token_endpoint"
    "access_token_endpoint"
    "authorization_endpoint"
    "whoami_endpoint"
    "created"
    "updated"
  ]

testData =
  create:
    hostname: "social.localhost"
    registration_endpoint: "https://social.localhost/api/registration"
    request_token_endpoint: "https://social.localhost/api/request_token"
    access_token_endpoint: "https://social.localhost/api/access_token"
    authorization_endpoint: "https://social.localhost/api/authorization"
    whoami_endpoint: "https://social.localhost/api/whoami"

  update:
    timestamp: 1337801765

mb = modelBatch("host", "Host", testSchema, testData)
mb["When we require the host module"]["and we get its Host class export"]["and we create a host instance"]["auto-generated fields are there"] = (err, created) ->
  assert.ifError err
  assert.include created, "created"
  assert.include created, "modified"
  return

mb["When we require the host module"]["and we get its Host class export"]["and we create a host instance"]["and we modify it"]["it is modified"] = (err, updated) ->
  assert.ifError err
  assert.include updated, "created"
  assert.include updated, "modified"
  assert.notEqual updated.created, updated.modified
  return

suite.addBatch mb
suite.addBatch "When we get the Host class":
  topic: ->
    require("../lib/model/host").Host

  "it works": (Host) ->
    assert.isFunction Host
    return

  "and we check its class methods":
    topic: (Host) ->
      Host

    "it has an ensureHost method": (Host) ->
      assert.isFunction Host.ensureHost
      return

  "and we make an instance":
    topic: (Host) ->
      new Host(hostname: "simple.example")

    "it works": (host) ->
      assert.isObject host
      return

    "and we check its methods":
      topic: (host) ->
        host

      "it has a getRequestToken() method": (host) ->
        assert.isFunction host.getRequestToken
        return

      "it has an authorizeURL() method": (host) ->
        assert.isFunction host.authorizeURL
        return

      "it has a getAccessToken() method": (host) ->
        assert.isFunction host.getAccessToken
        return

      "it has a whoami() method": (host) ->
        assert.isFunction host.whoami
        return

suite["export"] module
