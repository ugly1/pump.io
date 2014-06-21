# register-email-required-test.js
#
# Test behavior when email registration is required
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
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

suite = vows.describe("registration with email")

# A batch to test some of the layout basics
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

    "and we try to register a user with no email address":
      topic: (cl, app, smtp) ->
        callback = @callback
        register cl, "florida", "good*times", (err, result, response) ->
          if err and err.statusCode is 400
            callback null
          else
            callback new Error("Unexpected success")
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we register a user with an email address":
      topic: (cl, app, smtp) ->
        callback = @callback
        Step (->
          oneEmail smtp, "jamesjr@pump.test", @parallel()
          registerEmail cl, "jj", "dyn|o|mite!", "jamesjr@pump.test", @parallel()
          return
        ), callback
        return

      "it works correctly": (err, message, user) ->
        assert.ifError err
        assert.isObject user
        assert.isObject message
        return

      "the email is not included": (err, message, user) ->
        assert.ifError err
        assert.isObject user
        assert.isFalse _.include(user, "email")
        return

      "and we confirm the email address":
        topic: (message, user, cl) ->
          confirmEmail message, @callback
          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we fetch the user with client credentials":
          topic: (message, user, cl) ->
            cred =
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret

            httputil.getJSON "http://localhost:4815/api/user/jj", cred, @callback
            return

          "it works": (err, user, response) ->
            assert.ifError err
            assert.isObject user
            return

          "the email address is not included": (err, user, response) ->
            assert.ifError err
            assert.isObject user
            assert.isFalse _.has(user, "email")
            return

        "and we fetch the user with user credentials for a different user":
          topic: (message, jj, cl, app, smtp) ->
            callback = @callback
            james = undefined
            Step (->
              oneEmail smtp, "jamessr@pump.test", @parallel()
              registerEmail cl, "james", "work|hard", "jamessr@pump.test", @parallel()
              return
            ), ((err, message, results) ->
              throw err  if err
              james = results
              confirmEmail message, this
              return
            ), ((err) ->
              throw err  if err
              cred =
                consumer_key: cl.client_id
                consumer_secret: cl.client_secret
                token: james.token
                token_secret: james.secret

              httputil.getJSON "http://localhost:4815/api/user/jj", cred, this
              return
            ), (err, doc, response) ->
              if err
                callback err, null
              else
                callback null, doc
              return

            return

          "it works": (err, doc) ->
            assert.ifError err
            assert.isObject doc
            return

          "the email address is not included": (err, doc) ->
            assert.ifError err
            assert.isObject doc
            assert.isFalse _.has(doc, "email")
            return

        "and we fetch the user with user credentials for the same user":
          topic: (message, user, cl) ->
            cred =
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: user.token
              token_secret: user.secret

            httputil.getJSON "http://localhost:4815/api/user/jj", cred, @callback
            return

          "it works": (err, user) ->
            assert.ifError err
            assert.isObject user
            return

          "the email address is included": (err, user) ->
            assert.ifError err
            assert.isObject user
            assert.include user, "email"
            return

        "and we fetch the user feed with client credentials":
          topic: (message, user, cl) ->
            cred =
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret

            httputil.getJSON "http://localhost:4815/api/users", cred, @callback
            return

          "it works": (err, feed, response) ->
            assert.ifError err
            assert.isObject feed
            return

          "the email address is not included": (err, feed, response) ->
            target = undefined
            assert.ifError err
            assert.isObject feed
            target = _.filter(feed.items, (user) ->
              user.nickname is "jj"
            )
            assert.lengthOf target, 1
            assert.isObject target[0]
            assert.isFalse _.has(target[0], "email")
            return

        "and we fetch the user feed with user credentials for a different user":
          topic: (message, jj, cl, app, smtp) ->
            callback = @callback
            thelma = undefined
            Step (->
              oneEmail smtp, "thelma@pump.test", @parallel()
              registerEmail cl, "thelma", "dance4fun", "thelma@pump.test", @parallel()
              return
            ), ((err, message, results) ->
              throw err  if err
              thelma = results
              confirmEmail message, this
              return
            ), ((err) ->
              throw err  if err
              cred =
                consumer_key: cl.client_id
                consumer_secret: cl.client_secret
                token: thelma.token
                token_secret: thelma.secret

              httputil.getJSON "http://localhost:4815/api/users", cred, this
              return
            ), (err, doc, response) ->
              if err
                callback err, null
              else
                callback null, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            return

          "the email address is not included": (err, feed) ->
            target = undefined
            assert.ifError err
            assert.isObject feed
            target = _.filter(feed.items, (user) ->
              user.nickname is "jj"
            )
            assert.lengthOf target, 1
            assert.isObject target[0]
            assert.isFalse _.has(target[0], "email")
            return

        "and we fetch the user feed with user credentials for the same user":
          topic: (message, user, cl) ->
            cred =
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: user.token
              token_secret: user.secret

            httputil.getJSON "http://localhost:4815/api/users", cred, @callback
            return

          "it works": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            return

          "the email address is included": (err, feed) ->
            target = undefined
            assert.ifError err
            assert.isObject feed
            target = _.filter(feed.items, (user) ->
              user.nickname is "jj"
            )
            assert.lengthOf target, 1
            assert.isObject target[0]
            assert.isTrue _.has(target[0], "email")
            return

    "and we register another user with an email address":
      topic: (cl, app, smtp) ->
        callback = @callback
        Step (->
          oneEmail smtp, "bookman@pump.test", @parallel()
          registerEmail cl, "bookman", "i*am*super.", "bookman@pump.test", @parallel()
          return
        ), callback
        return

      "it works correctly": (err, message, user) ->
        assert.ifError err
        assert.isObject user
        assert.isObject message
        return

      "the email is not included": (err, message, user) ->
        assert.ifError err
        assert.isObject user
        assert.isFalse _.include(user, "email")
        return

      "and we fetch the user with user credentials without confirmation":
        topic: (message, user, cl) ->
          callback = @callback
          cred =
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
            token: user.token
            token_secret: user.secret

          Step (->
            httputil.getJSON "http://localhost:4815/api/user/bookman", cred, this
            return
          ), (err, body, resp) ->
            if err and err.statusCode and err.statusCode is 403
              callback null
            else if err
              callback err
            else
              callback new Error("Unexpected success")
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

suite["export"] module
