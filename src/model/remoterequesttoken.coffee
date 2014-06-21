# remoterequesttoken.js
#
# data object representing a remoterequesttoken
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
DatabankObject = require("databank").DatabankObject
RemoteRequestToken = DatabankObject.subClass("remoterequesttoken")
RemoteRequestToken.schema =
  pkey: "hostname_token"
  fields: [
    "hostname"
    "token"
    "secret"
  ]

RemoteRequestToken.key = (hostname, token) ->
  hostname + "/" + token

RemoteRequestToken.beforeCreate = (props, callback) ->
  i = undefined
  required = [
    "hostname"
    "token"
    "secret"
  ]
  fail = false
  i = 0
  while i < required.length
    unless _.has(props, required[i])
      callback new Error("Missing required property: " + required[i]), null
      return
    i++
  props.hostname_token = RemoteRequestToken.key(props.hostname, props.token)  unless _.has(props, "hostname_token")
  callback null, props
  return

exports.RemoteRequestToken = RemoteRequestToken
