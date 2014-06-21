# activityspam.js
#
# tests activity for spam against a spam server
#
# Copyright 2011-2012, E14N https://e14n.com/
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
Step = require("step")
OAuth = require("oauth-evanp").OAuth
HTTPError = require("./httperror").HTTPError
version = require("./version").version
host = undefined
clientID = undefined
clientSecret = undefined
oa = undefined
log = undefined
ActivitySpam =
  init: (params) ->
    host = params.host or "https://spamicity.info"
    clientID = params.clientID
    clientSecret = params.clientSecret
    log = params.log
    oa = new OAuth(null, null, clientID, clientSecret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
      "User-Agent": "pump.io/" + version
    )
    return

  test: (act, callback) ->
    json = undefined
    try
      json = JSON.stringify(act)
    catch e
      callback e, null
      return
    unless oa
      
      # With no
      callback null, null, null
      return
    log.info
      act: act.id
      host: host
    , "Testing activity"
    Step (->
      oa.post host + "/is-this-spam", null, null, json, "application/json", this
      return
    ), ((err, body, resp) ->
      obj = undefined
      throw err  if err
      throw new HTTPError(body, resp.statusCode)  if resp.statusCode >= 400 and resp.statusCode < 600
      throw new Error("Incorrect response type")  if not resp.headers or not resp.headers["content-type"] or resp.headers["content-type"].substr(0, "application/json".length) isnt "application/json"
      
      # Throws an exception
      obj = JSON.parse(body)
      throw new Error("Unexpected response content")  if not _.isBoolean(obj.isSpam) or not _.isNumber(obj.probability)
      this null, obj.isSpam, obj.probability
      return
    ), (err, isSpam, probability) ->
      if err
        log.warn
          act: act.id
          host: host
          err: err
        , "Error testing activity."
        callback null, null, 0.5
      else
        callback null, isSpam, probability
      return

    return

module.exports = ActivitySpam
