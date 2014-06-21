# proxy-test.js
#
# Test the proxy module
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
assert = require("assert")
vows = require("vows")
databank = require("databank")
URLMaker = require("../lib/urlmaker").URLMaker
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("proxy module interface")
testSchema =
  pkey: "url"
  fields: [
    "id"
    "created"
  ]
  indices: ["id"]

testData =
  create:
    url: "http://social.example/api/user/fred/followers"

  update:
    foo: "bar"

mb = modelBatch("proxy", "Proxy", testSchema, testData)
mb["When we require the proxy module"]["and we get its Proxy class export"]["and we create a proxy instance"]["auto-generated fields are there"] = (err, created) ->
  assert.ifError err
  assert.isString created.id
  assert.isString created.created
  return

mb["When we require the proxy module"]["and we get its Proxy class export"]["and we create a proxy instance"]["and we modify it"]["it is modified"] = (err, updated) ->
  assert.ifError err
  return

suite.addBatch mb
suite["export"] module
