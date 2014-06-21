# stamper-test.js
#
# Test the stamper module
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
vows.describe("stamper module interface").addBatch("When we require the stamper module":
  topic: ->
    require "../lib/stamper"

  "it works": (stamper) ->
    assert.isObject stamper
    return

  "and we get its Stamper export":
    topic: (stamper) ->
      stamper.Stamper

    "it exists": (Stamper) ->
      assert.isObject Stamper
      return

    "it has a stamp() method": (Stamper) ->
      assert.isFunction Stamper.stamp
      return

    "it has an unstamp() method": (Stamper) ->
      assert.isFunction Stamper.unstamp
      return

    "and we make a timestamp with no argument":
      topic: (Stamper) ->
        Stamper.stamp()

      "it works": (ts) ->
        assert.isString ts
        return

      "it looks correct": (ts) ->
        assert.match ts, /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/
        return

    "and we make a timestamp with a date argument":
      topic: (Stamper) ->
        d = Date.UTC(2000, 0, 1, 12, 34, 56)
        Stamper.stamp d

      "it works": (ts) ->
        assert.isString ts
        return

      "it looks correct": (ts) ->
        assert.match ts, /\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/
        return

      "it contains our date": (ts) ->
        assert.equal ts, "2000-01-01T12:34:56Z"
        return

    "and we unstamp a timestamp":
      topic: (Stamper) ->
        ts = "1968-10-14T13:32:12Z"
        Stamper.unstamp ts

      "it works": (dt) ->
        assert.instanceOf dt, Date
        return

      "its properties are correct": (dt) ->
        assert.equal dt.getUTCFullYear(), 1968
        assert.equal dt.getUTCMonth(), 9
        assert.equal dt.getUTCDate(), 14
        assert.equal dt.getUTCHours(), 13
        assert.equal dt.getUTCMinutes(), 32
        assert.equal dt.getUTCSeconds(), 12
        return
)["export"] module
