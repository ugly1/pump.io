# confirmation.js
#
# Random code for confirming an email address
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
Stamper = require("../stamper").Stamper
NoSuchThingError = databank.NoSuchThingError
Confirmation = DatabankObject.subClass("confirmation")
now = ->
  Math.floor Date.now() / 1000

Confirmation.schema =
  pkey: "nickname_email"
  fields: [
    "nickname"
    "email"
    "code"
    "confirmed"
    "timestamp"
  ]
  indices: [
    "code"
    "nickname"
  ]

exports.Confirmation = Confirmation
Confirmation.pkey = ->
  "nickname_email"

Confirmation.makeKey = (props) ->
  props.nickname + "/" + props.email

Confirmation.beforeCreate = (props, callback) ->
  callback new Error("Not enough properties"), null  if not _(props).has("nickname") or not _(props).has("email")
  props.nickname_email = Confirmation.makeKey(props)
  props.timestamp = Stamper.stamp()
  props.confirmed = false
  Step (->
    randomString 8, this
    return
  ), (err, str) ->
    if err
      callback err, null
    else
      props.code = str
      callback null, props
    return

  return
