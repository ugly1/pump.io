# test/lib/email.js
#
# Some utilities for testing email behaviour
#
# Copyright 2012-2013, E14N https://e14n.com/
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
_ = require("underscore")
simplesmtp = require("simplesmtp")
oauthutil = require("./oauth")
httputil = require("./http")
Step = require("step")
http = require("http")
newClient = oauthutil.newClient
accessToken = oauthutil.accessToken
register = oauthutil.register
registerEmail = oauthutil.registerEmail
setupApp = oauthutil.setupApp
setupAppConfig = oauthutil.setupAppConfig
oneEmail = (smtp, addr, callback) ->
  data = undefined
  timeoutID = undefined
  isOurs = (envelope) ->
    _.contains envelope.to, addr

  starter = (envelope) ->
    if isOurs(envelope)
      data = ""
      smtp.on "data", accumulator
      smtp.once "dataReady", ender
    return

  accumulator = (envelope, chunk) ->
    data = data + chunk.toString()  if isOurs(envelope)
    return

  ender = (envelope, cb) ->
    msg = undefined
    if isOurs(envelope)
      clearTimeout timeoutID
      smtp.removeListener "data", accumulator
      msg = _.clone(envelope)
      msg.data = data
      callback null, msg
      process.nextTick ->
        cb null
        return

    return

  timeoutID = setTimeout(->
    callback new Error("Timeout waiting for email"), null
    return
  , 5000)
  smtp.on "startData", starter
  return

confirmEmail = (message, callback) ->
  urlre = /http:\/\/localhost:4815\/main\/confirm\/[a-zA-Z0-9_\-]+/
  match = urlre.exec(message.data)
  url = (if (match.length > 0) then match[0] else null)
  unless url
    callback new Error("No URL matched"), null
    return
  http.get(url, (res) ->
    body = ""
    res.on "data", (chunk) ->
      body += chunk
      return

    res.on "end", ->
      if res.statusCode < 200 or res.statusCode >= 300
        callback new Error("Bad status code " + res.statusCode + ": " + body)
      else
        callback null
      return

    return
  ).on "error", (err) ->
    callback err
    return

  return

exports.oneEmail = oneEmail
exports.confirmEmail = confirmEmail
