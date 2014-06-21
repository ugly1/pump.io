# nonce.js
#
# A nonce in an OAuth call
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
databank = require("databank")
_ = require("underscore")
DatabankObject = databank.DatabankObject
Step = require("step")
randomString = require("../randomstring").randomString
NoSuchThingError = databank.NoSuchThingError
Nonce = DatabankObject.subClass("nonce")
ignore = (err) ->

now = ->
  Math.floor Date.now() / 1000

Nonce.schema =
  pkey: "token_nonce"
  fields: [
    "nonce"
    "consumer_key"
    "access_token"
    "timestamp"
  ]

exports.Nonce = Nonce
Nonce.pkey = ->
  "token_nonce"

Nonce.makeKey = (consumer_key, access_token, nonce, timestamp) ->
  if access_token
    consumer_key + "/" + access_token + "/" + timestamp.toString(10) + "/" + nonce
  else
    consumer_key + "/" + timestamp.toString(10) + "/" + nonce

Nonce.beforeCreate = (props, callback) ->
  callback new Error("Not enough properties"), null  if not _(props).has("consumer_key") or not _(props).has("timestamp") or not _(props).has("nonce")
  props.token_nonce = Nonce.makeKey(props.consumer_key, props.access_token or null, props.nonce, props.timestamp)
  callback null, props
  return


# double the timestamp timeout in ../lib/provider.js, in seconds
TIMELIMIT = 600
Nonce.seenBefore = (consumer_key, access_token, nonce, timestamp, callback) ->
  key = Nonce.makeKey(consumer_key, access_token or null, nonce, parseInt(timestamp, 10))
  Step (->
    Nonce.get key, this
    return
  ), ((err, found) ->
    props = undefined
    if err and (err.name is "NoSuchThingError") # database miss
      props =
        consumer_key: consumer_key
        nonce: nonce
        timestamp: parseInt(timestamp, 10)

      props.access_token = access_token  if access_token
      Nonce.create props, this
    else if err # regular old error
      throw err
    else
      callback null, true
    return
  ), (err, nonce) ->
    if err
      callback err, null
    else
      callback err, false
    return

  return

Nonce.cleanup = ->
  todel = []
  Nonce.scan ((nonce) ->
    todel.push nonce  if now() - nonce.timestamp > TIMELIMIT
    return
  ), (err) ->
    Step (->
      group = @group()
      _.each todel, (nonce) ->
        nonce.del group()
        return

      return
    ), (err) ->

    return

  return

# Do nothing!
