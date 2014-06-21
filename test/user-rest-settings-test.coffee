# user-rest-test.js
#
# Test the client registration API
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
http = require("http")
vows = require("vows")
Step = require("step")
_ = require("underscore")
OAuth = require("oauth-evanp").OAuth
version = require("../lib/version").version
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
newPair = oauthutil.newPair
register = oauthutil.register
suite = vows.describe("user settings REST API")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

pairOf = (user) ->
  token: user.token
  token_secret: user.secret

makeUserCred = (cl, user) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: user.token
  token_secret: user.secret

clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret

invert = (callback) ->
  (err) ->
    if err
      callback null
    else
      callback new Error("Unexpected success")
    return

goodUser = (err, doc) ->
  profile = undefined
  assert.ifError err
  assert.isObject doc
  assert.include doc, "nickname"
  assert.include doc, "published"
  assert.include doc, "updated"
  assert.include doc, "profile"
  assert.isObject doc.profile
  profile = doc.profile
  assert.include doc.profile, "id"
  assert.include doc.profile, "objectType"
  assert.equal doc.profile.objectType, "person"
  assert.include doc.profile, "favorites"
  assert.include doc.profile, "followers"
  assert.include doc.profile, "following"
  assert.include doc.profile, "lists"
  assert.isFalse _.has(doc.profile, "_uuid")
  assert.isFalse _.has(doc.profile, "_user")
  assert.isFalse _.has(doc.profile, "_user")
  return

suite.addBatch "When we set up the app":
  topic: ->
    cb = @callback
    setupApp (err, app) ->
      if err
        cb err, null, null
      else
        newClient (err, cl) ->
          if err
            cb err, null, null
          else
            cb err, cl, app
          return

      return

    return

  "it works": (err, cl, app) ->
    assert.ifError err
    assert.isObject cl
    return

  teardown: (cl, app) ->
    if cl and cl.del
      cl.del (err) ->

    app.close()  if app
    return

  "and we register two users":
    topic: (cl) ->
      callback = @callback
      Step (->
        register cl, "ahmose", "theFirst!", @parallel()
        register cl, "tarquin", "of|rome.", @parallel()
        return
      ), callback
      return

    "it works": (err, user1, user2) ->
      assert.ifError err
      assert.isObject user1
      assert.isObject user2
      return

    "and we set the first user's settings":
      topic: (user1, user2, cl) ->
        callback = @callback
        user1.settings = {}  unless user1.settings
        user1.settings["pump.io"] = {}  unless user1.settings["pump.io"]
        user1.settings["pump.io"]["user-rest-test"] = 42
        user1.password = "theFirst!"
        httputil.putJSON "http://localhost:4815/api/user/ahmose", makeUserCred(cl, user1), _.omit(user1, "token", "secret"), (err, obj) ->
          callback err
          return

        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we get the first user's settings with its own credentials":
        topic: (user1, user2, cl) ->
          callback = @callback
          httputil.getJSON "http://localhost:4815/api/user/ahmose", makeUserCred(cl, user1), (err, obj) ->
            callback err, obj
            return

          return

        "it works": (err, user) ->
          assert.ifError err
          return

        "it has our setting": (err, user) ->
          assert.ifError err
          assert.isObject user
          assert.isObject user.settings
          assert.isObject user.settings["pump.io"]
          assert.isNumber user.settings["pump.io"]["user-rest-test"]
          assert.equal user.settings["pump.io"]["user-rest-test"], 42
          return

      "and we get the first user's settings with the other user's credentials":
        topic: (user1, user2, cl) ->
          callback = @callback
          httputil.getJSON "http://localhost:4815/api/user/ahmose", makeUserCred(cl, user2), (err, obj) ->
            callback err, obj
            return

          return

        "it works": (err, user) ->
          assert.ifError err
          return

        "it does not have the setting": (err, user) ->
          assert.ifError err
          assert.isObject user
          assert.isUndefined user.settings
          return

suite["export"] module
