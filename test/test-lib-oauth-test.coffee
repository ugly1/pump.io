# test-lib-oauth-test.js
#
# Test the test libraries
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
suite = vows.describe("user REST API")
suite.addBatch "When we load the module":
  topic: ->
    require "./lib/oauth"

  "it works": (oauth) ->
    assert.isObject oauth
    return

  "it has a setupApp() export": (oauth) ->
    assert.isTrue _(oauth).has("setupApp")
    assert.isFunction oauth.setupApp
    return

  "it has a newClient() export": (oauth) ->
    assert.isTrue _(oauth).has("newClient")
    assert.isFunction oauth.newClient
    return

  "it has a register() export": (oauth) ->
    assert.isTrue _(oauth).has("register")
    assert.isFunction oauth.register
    return

  "it has a requestToken() export": (oauth) ->
    assert.isTrue _(oauth).has("requestToken")
    assert.isFunction oauth.requestToken
    return

  "it has a newCredentials() export": (oauth) ->
    assert.isTrue _(oauth).has("newCredentials")
    assert.isFunction oauth.newCredentials
    return

  "it has a accessToken() export": (oauth) ->
    assert.isTrue _(oauth).has("accessToken")
    assert.isFunction oauth.accessToken
    return

  "and we setup the app":
    topic: (oauth) ->
      oauth.setupApp @callback
      return

    "it works": (err, app) ->
      assert.ifError err
      assert.isObject app
      return

    teardown: (app) ->
      app.close()  if app and app.close
      return

    "and we create a new client":
      topic: (app, oauth) ->
        oauth.newClient @callback
        return

      "it works": (err, client) ->
        assert.ifError err
        assert.isObject client
        assert.include client, "client_id"
        assert.isString client.client_id
        assert.include client, "client_secret"
        assert.isString client.client_secret
        return

      "and we register a new user":
        topic: (client, app, oauth) ->
          oauth.register client, "alice", "ch3z|p4niSSe", @callback
          return

        "it works": (err, user) ->
          assert.ifError err
          assert.isObject user
          return

        "and we get a new access token":
          topic: (user, client, app, oauth) ->
            oauth.accessToken client,
              nickname: "alice"
              password: "ch3z|p4niSSe"
            , @callback
            return

          "it works": (err, pair) ->
            assert.ifError err
            assert.isObject pair
            assert.include pair, "token"
            assert.isString pair.token
            assert.include pair, "token_secret"
            assert.isString pair.token_secret
            return

    "and we get new credentials":
      topic: (app, oauth) ->
        oauth.newCredentials "jasper", "johns,artist", @callback
        return

      "it works": (err, cred) ->
        assert.ifError err
        assert.isObject cred
        assert.include cred, "consumer_key"
        assert.isString cred.consumer_key
        assert.include cred, "consumer_secret"
        assert.isString cred.consumer_secret
        assert.include cred, "token"
        assert.isString cred.token
        assert.include cred, "token_secret"
        assert.isString cred.token_secret
        return

suite["export"] module
