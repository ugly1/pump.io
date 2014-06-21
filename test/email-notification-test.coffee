# email-notification-test.js
#
# Test email notifications
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
_ = require("underscore")
simplesmtp = require("simplesmtp")
oauthutil = require("./lib/oauth")
httputil = require("./lib/http")
emailutil = require("./lib/email")
Browser = require("zombie")
Step = require("step")
http = require("http")
newClient = oauthutil.newClient
register = oauthutil.register
registerEmail = oauthutil.registerEmail
setupApp = oauthutil.setupApp
setupAppConfig = oauthutil.setupAppConfig
oneEmail = emailutil.oneEmail
confirmEmail = emailutil.confirmEmail
userCred = (cl, user) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: user.token
  token_secret: user.secret

suite = vows.describe("email notifications")
registerAndConfirm = (smtp, cl, email, nickname, password, callback) ->
  user = undefined
  Step (->
    oneEmail smtp, email, @parallel()
    registerEmail cl, nickname, password, email, @parallel()
    return
  ), ((err, message, results) ->
    throw err  if err
    user = results
    confirmEmail message, this
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, user
    return

  return

suite.addBatch "When we set up the app":
  topic: ->
    callback = @callback
    smtp = simplesmtp.createServer(disableDNSValidation: true)
    Step (->
      smtp.listen 1623, this
      return
    ), ((err) ->
      throw err  if err
      setupAppConfig
        hostname: "localhost"
        port: 4815
        requireEmail: true
        smtpserver: "localhost"
        smtpport: 1623
      , this
      return
    ), (err, app) ->
      if err
        callback err, null, null
      else
        callback null, app, smtp
      return

    return

  teardown: (app, smtp) ->
    app.close()  if app and app.close
    if smtp
      smtp.end (err) ->

    return

  "it works": (err, app, smtp) ->
    assert.ifError err
    return

  "and we get a new client":
    topic: (app, smtp) ->
      newClient @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and we register two users":
      topic: (cl, app, smtp) ->
        Step (->
          registerAndConfirm smtp, cl, "tony@pump.test", "tony", "you*can*tell", @parallel()
          registerAndConfirm smtp, cl, "stephanie@pump.test", "stephanie", "luv2dance", @parallel()
          return
        ), @callback
        return

      "it works": (err, tony, stephanie) ->
        assert.ifError err
        assert.isObject tony
        assert.isObject stephanie
        return

      "and one user sends the other a message":
        topic: (tony, stephanie, cl, app, smtp) ->
          callback = @callback
          url = "http://localhost:4815/api/user/tony/feed"
          cred = userCred(cl, tony)
          act =
            verb: "post"
            to: [stephanie.profile]
            object:
              objectType: "note"
              content: "All you need is a salad bowl, and a potato masher."

          Step (->
            oneEmail smtp, "stephanie@pump.test", @parallel()
            httputil.postJSON url, cred, act, @parallel()
            return
          ), (err, message, body, response) ->
            callback err, message, body
            return

          return

        "it works": (err, message, body) ->
          assert.ifError err
          assert.isObject message
          assert.isObject body
          return

suite["export"] module
