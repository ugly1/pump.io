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
suite = vows.describe("user REST API")
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
            
            # sneaky, but we just need it for teardown
            cl.app = app
            cb err, cl
          return

      return

    return

  "it works": (err, cl) ->
    assert.ifError err
    assert.isObject cl
    return

  teardown: (cl) ->
    if cl and cl.del
      cl.del (err) ->

    cl.app.close()  if cl.app
    return

  "and we try to get a non-existent user":
    topic: (cl) ->
      httputil.getJSON "http://localhost:4815/api/user/nonexistent",
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret
      , invert(@callback)
      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we register a user":
    topic: (cl) ->
      register cl, "zardoz", "this*is*my*gun", @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we get the options on the user api endpoint": httputil.endpoint("/api/user/zardoz", [
      "GET"
      "PUT"
      "DELETE"
    ])
    "and we GET the user data without OAuth credentials":
      topic: ->
        cb = @callback
        options =
          host: "localhost"
          port: 4815
          path: "/api/user/zardoz"

        http.get(options, (res) ->
          if res.statusCode >= 400 and res.statusCode < 500
            cb null
          else
            cb new Error("Unexpected status code")
          return
        ).on "error", (err) ->
          cb err
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we GET the user data with invalid client credentials":
      topic: (user, cl) ->
        httputil.getJSON "http://localhost:4815/api/user/zardoz",
          consumer_key: "NOTACLIENT"
          consumer_secret: "NOTASECRET"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we GET the user data with client credentials and no access token":
      topic: (user, cl) ->
        httputil.getJSON "http://localhost:4815/api/user/zardoz",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        , @callback
        return

      "it works": (err, doc) ->
        assert.ifError err
        assert.include doc, "nickname"
        assert.include doc, "published"
        assert.include doc, "updated"
        assert.include doc, "profile"
        assert.isObject doc.profile
        assert.include doc.profile, "id"
        assert.include doc.profile, "objectType"
        assert.equal doc.profile.objectType, "person"
        assert.isFalse _.has(doc.profile, "_uuid")
        assert.isFalse _.has(doc.profile, "_user")
        return

    "and we GET the user data with client credentials and an invalid access token":
      topic: (user, cl) ->
        httputil.getJSON "http://localhost:4815/api/user/zardoz",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: "NOTATOKEN"
          token_secret: "NOTASECRET"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we GET the user data with client credentials and the same user's access token":
      topic: (user, cl) ->
        cb = @callback
        pair = pairOf(user)
        Step (->
          httputil.getJSON "http://localhost:4815/api/user/zardoz",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
            token: pair.token
            token_secret: pair.token_secret
          , this
          return
        ), (err, results) ->
          if err
            cb err, null
          else
            cb null, results
          return

        return

      "it works": goodUser

    "and we GET the user data with client credentials and a different user's access token":
      topic: (user, cl) ->
        cb = @callback
        Step (->
          register cl, "yankee", "d0odle|d4ndy", this
          return
        ), ((err, user2) ->
          pair = undefined
          throw err  if err
          pair = pairOf(user2)
          httputil.getJSON "http://localhost:4815/api/user/zardoz",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
            token: pair.token
            token_secret: pair.token_secret
          , this
          return
        ), (err, results) ->
          if err
            cb err, null
          else
            cb null, results
          return

        return

      "it works": goodUser

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

  "and we try to put a non-existent user":
    topic: (cl) ->
      httputil.putJSON "http://localhost:4815/api/user/nonexistent",
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret
      ,
        nickname: "nonexistent"
        password: "whatever"
      , invert(@callback)
      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we register a user":
    topic: (cl) ->
      register cl, "xerxes", "sparta!!", @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we PUT new user data without OAuth credentials":
      topic: (user, cl) ->
        cb = @callback
        options =
          host: "localhost"
          port: 4815
          path: "/api/user/xerxes"
          method: "PUT"
          headers:
            "User-Agent": "pump.io/" + version
            "Content-Type": "application/json"

        req = http.request(options, (res) ->
          if res.statusCode >= 400 and res.statusCode < 500
            cb null
          else
            cb new Error("Unexpected status code")
          return
        ).on("error", (err) ->
          cb err
          return
        )
        req.write JSON.stringify(
          nickname: "xerxes"
          password: "athens*1"
        )
        req.end()
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT new user data with invalid client credentials":
      topic: (user, cl) ->
        httputil.putJSON "http://localhost:4815/api/user/xerxes",
          consumer_key: "BADKEY"
          consumer_secret: "BADSECRET"
        ,
          nickname: "xerxes"
          password: "6|before|thebes"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT new user data with client credentials and no access token":
      topic: (user, cl) ->
        httputil.putJSON "http://localhost:4815/api/user/xerxes",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        ,
          nickname: "xerxes"
          password: "corinth,also"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT new user data with client credentials and an invalid access token":
      topic: (user, cl) ->
        httputil.putJSON "http://localhost:4815/api/user/xerxes",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: "BADTOKEN"
          token_secret: "BADSECRET"
        ,
          nickname: "xerxes"
          password: "thessaly?"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT new user data with client credentials and a different user's access token":
      topic: (user, cl) ->
        cb = @callback
        Step (->
          newPair cl, "themistocles", "salamis!", this
          return
        ), (err, pair) ->
          if err
            cb err
          else
            httputil.putJSON "http://localhost:4815/api/user/xerxes",
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: pair.token
              token_secret: pair.token_secret
            ,
              nickname: "xerxes"
              password: "isuck!haha"
            , invert(cb)
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT new user data with client credentials and the same user's access token":
      topic: (user, cl) ->
        cb = @callback
        pair = pairOf(user)
        httputil.putJSON "http://localhost:4815/api/user/xerxes",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "xerxes"
          password: "athens+1"
        , cb
        return

      "it works": (err, doc) ->
        assert.ifError err
        assert.include doc, "nickname"
        assert.include doc, "published"
        assert.include doc, "updated"
        assert.include doc, "profile"
        assert.isObject doc.profile
        assert.include doc.profile, "id"
        assert.include doc.profile, "objectType"
        assert.equal doc.profile.objectType, "person"
        assert.isFalse _.has(doc.profile, "_uuid")
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

  "and we register a user":
    topic: (cl) ->
      register cl, "c3po", "ih8anakin", @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we PUT third-party user data":
      topic: (user, cl) ->
        cb = @callback
        pair = pairOf(user)
        httputil.putJSON "http://localhost:4815/api/user/c3po",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "c3po"
          password: "ih8anakin"
          langs: 6000000
        , (err, body, res) ->
          cb err, body
          return

        return

      "it works": (err, res) ->
        assert.ifError err
        assert.include res, "langs"
        assert.equal res.langs, 6000000
        return

      "and we GET user with third-party data":
        topic: (dup, user, cl) ->
          pair = pairOf(user)
          httputil.getJSON "http://localhost:4815/api/user/c3po",
            consumer_key: cl.client_id
            consumer_secret: cl.client_secret
            token: pair.token
            token_secret: pair.token_secret
          , @callback
          return

        "it works": (err, res) ->
          assert.ifError err
          assert.include res, "langs"
          assert.equal res.langs, 6000000
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

  "and we register a user":
    topic: (cl) ->
      register cl, "willy", "w0nka+b4r", @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we PUT a new nickname":
      topic: (user, cl) ->
        pair = pairOf(user)
        httputil.putJSON "http://localhost:4815/api/user/willy",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "william"
          password: "w0nka+b4r"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT a new published value":
      topic: (user, cl) ->
        pair = pairOf(user)
        httputil.putJSON "http://localhost:4815/api/user/willy",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "willy"
          password: "w0nka+b4r"
          published: "2001-11-10T00:00:00"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT a new updated value":
      topic: (user, cl) ->
        pair = pairOf(user)
        httputil.putJSON "http://localhost:4815/api/user/willy",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "willy"
          password: "w0nka+b4r"
          updated: "2003-11-10T00:00:00"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT a new profile":
      topic: (user, cl) ->
        profile =
          objectType: "person"
          id: "urn:uuid:8cec1280-28a6-4173-a523-2207ea964a2a"

        pair = pairOf(user)
        httputil.putJSON "http://localhost:4815/api/user/willy",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "willy"
          password: "w0nka+b4r"
          profile: profile
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we PUT new profile data":
      topic: (user, cl) ->
        profile = user.profile
        pair = pairOf(user)
        profile.displayName = "William Q. Wonka"
        httputil.putJSON "http://localhost:4815/api/user/willy",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        ,
          nickname: "willy"
          password: "w0nka+b4r"
          profile: profile
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
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

  "and we register a user":
    topic: (cl) ->
      register cl, "victor", "les+miz!", @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we DELETE the user without OAuth credentials":
      topic: (user, cl) ->
        cb = @callback
        options =
          host: "localhost"
          port: 4815
          path: "/api/user/victor"
          method: "DELETE"
          headers:
            "User-Agent": "pump.io/" + version

        req = http.request(options, (res) ->
          if res.statusCode >= 400 and res.statusCode < 500
            cb null
          else
            cb new Error("Unexpected status code")
          return
        ).on("error", (err) ->
          cb err
          return
        )
        req.end()
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we DELETE the user with invalid client credentials":
      topic: (user, cl) ->
        httputil.delJSON "http://localhost:4815/api/user/victor",
          consumer_key: "BADKEY"
          consumer_secret: "BADSECRET"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we DELETE the user with client credentials and no access token":
      topic: (user, cl) ->
        httputil.delJSON "http://localhost:4815/api/user/victor",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        , invert(@callback)
        return

      "it works": (err) ->
        assert.ifError err
        return

    "and we DELETE the user with client credentials and an invalid access token":
      topic: (user, cl) ->
        httputil.delJSON "http://localhost:4815/api/user/victor",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: "BADTOKEN"
          token_secret: "BADSECRET"
        , invert(@callback)
        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we DELETE the user with client credentials and a different user's access token":
      topic: (user, cl) ->
        cb = @callback
        Step (->
          newPair cl, "napoleon", "the+3rd!", this
          return
        ), (err, pair) ->
          if err
            cb err
          else
            httputil.delJSON "http://localhost:4815/api/user/victor",
              consumer_key: cl.client_id
              consumer_secret: cl.client_secret
              token: pair.token
              token_secret: pair.token_secret
            , invert(cb)
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

    "and we DELETE the user with client credentials and the same user's access token":
      topic: (user, cl) ->
        cb = @callback
        pair = pairOf(user)
        httputil.delJSON "http://localhost:4815/api/user/victor",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
          token: pair.token
          token_secret: pair.token_secret
        , cb
        return

      "it works": (err, body, result) ->
        assert.ifError err
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

  "and we register two unrelated users":
    topic: (cl) ->
      callback = @callback
      Step (->
        register cl, "philip", "of|macedon", @parallel()
        register cl, "asoka", "in+india", @parallel()
        return
      ), callback
      return

    "it works": (err, user1, user2) ->
      assert.ifError err
      assert.isObject user1
      assert.isObject user2
      return

    "and we get the first user with client credentials":
      topic: (user1, user2, cl) ->
        cred = clientCred(cl)
        httputil.getJSON "http://localhost:4815/api/user/philip", cred, @callback
        return

      "it works": (err, doc, resp) ->
        assert.ifError err
        return

      "profile has no pump_io member": (err, doc, resp) ->
        assert.ifError err
        assert.include doc, "profile"
        assert.isObject doc.profile
        assert.isFalse _.has(doc.profile, "pump_io")
        return

    "and we get the first user with his own credentials":
      topic: (user1, user2, cl) ->
        cred = makeUserCred(cl, user1)
        httputil.getJSON "http://localhost:4815/api/user/philip", cred, @callback
        return

      "it works": (err, doc, resp) ->
        assert.ifError err
        return

      "the followed flag is false": (err, doc, resp) ->
        assert.ifError err
        assert.include doc, "profile"
        assert.isObject doc.profile
        assert.include doc.profile, "pump_io"
        assert.isObject doc.profile.pump_io
        assert.include doc.profile.pump_io, "followed"
        assert.isFalse doc.profile.pump_io.followed
        return

    "and we get the first user with the second's credentials":
      topic: (user1, user2, cl) ->
        cred = makeUserCred(cl, user2)
        httputil.getJSON "http://localhost:4815/api/user/philip", cred, @callback
        return

      "it works": (err, doc, resp) ->
        assert.ifError err
        return

      "the followed flag is false": (err, doc, resp) ->
        assert.ifError err
        assert.include doc, "profile"
        assert.isObject doc.profile
        assert.include doc.profile, "pump_io"
        assert.isObject doc.profile.pump_io
        assert.include doc.profile.pump_io, "followed"
        assert.isFalse doc.profile.pump_io.followed
        return

  "and we register two other users":
    topic: (cl) ->
      callback = @callback
      Step (->
        register cl, "ramses", "phara0h!", @parallel()
        register cl, "caesar", "don't-stab-me-bro", @parallel()
        return
      ), callback
      return

    "it works": (err, user1, user2) ->
      assert.ifError err
      assert.isObject user1
      assert.isObject user2
      return

    "and the second follows the first":
      topic: (user1, user2, cl) ->
        callback = @callback
        cred = makeUserCred(cl, user2)
        act =
          verb: "follow"
          object: user1.profile

        Step (->
          httputil.postJSON "http://localhost:4815/api/user/caesar/feed", cred, act, this
          return
        ), (err, doc, response) ->
          if err
            callback err
          else
            callback null
          return

        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we get the first user with client credentials":
        topic: (user1, user2, cl) ->
          cred = clientCred(cl)
          httputil.getJSON "http://localhost:4815/api/user/ramses", cred, @callback
          return

        "it works": (err, doc, resp) ->
          assert.ifError err
          return

        "profile has no pump_io member": (err, doc, resp) ->
          assert.ifError err
          assert.include doc, "profile"
          assert.isObject doc.profile
          assert.isFalse _.has(doc.profile, "pump_io")
          return

      "and we get the first user with his own credentials":
        topic: (user1, user2, cl) ->
          cred = makeUserCred(cl, user1)
          httputil.getJSON "http://localhost:4815/api/user/ramses", cred, @callback
          return

        "it works": (err, doc, resp) ->
          assert.ifError err
          return

        "the followed flag is false": (err, doc, resp) ->
          assert.ifError err
          assert.include doc, "profile"
          assert.isObject doc.profile
          assert.include doc.profile, "pump_io"
          assert.isObject doc.profile.pump_io
          assert.include doc.profile.pump_io, "followed"
          assert.isFalse doc.profile.pump_io.followed
          return

      "and we get the first user with the second's credentials":
        topic: (user1, user2, cl) ->
          cred = makeUserCred(cl, user2)
          httputil.getJSON "http://localhost:4815/api/user/ramses", cred, @callback
          return

        "it works": (err, doc, resp) ->
          assert.ifError err
          return

        "the followed flag is true": (err, doc, resp) ->
          assert.ifError err
          assert.include doc, "profile"
          assert.isObject doc.profile
          assert.include doc.profile, "pump_io"
          assert.isObject doc.profile.pump_io
          assert.include doc.profile.pump_io, "followed"
          assert.isTrue doc.profile.pump_io.followed
          return

suite["export"] module
