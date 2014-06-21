# major-stream-shares-test.js
#
# Test that objects have "shares" stream in */major streams
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
Step = require("step")
_ = require("underscore")
http = require("http")
OAuth = require("oauth-evanp").OAuth
Browser = require("zombie")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
register = oauthutil.register
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

suite = vows.describe("Test shares items in major streams")
haveShares = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (act) ->
    assert.include act, "object"
    assert.isObject act.object
    assert.include act.object, "shares"
    assert.isObject act.object.shares
    assert.include act.object.shares, "totalItems"
    assert.include act.object.shares, "url"
    return

  return

correctShares = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (act) ->
    assert.include act, "object"
    assert.isObject act.object
    assert.include act.object, "shares"
    assert.isObject act.object.shares
    assert.include act.object.shares, "totalItems"
    if act.object.secretNumber % 2
      assert.equal act.object.shares.totalItems, 1
      assert.include act.object.shares, "items"
      assert.lengthOf act.object.shares.items, 1
    else
      assert.equal act.object.shares.totalItems, 0
    return

  return

haveShared = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (act) ->
    assert.include act, "object"
    assert.isObject act.object
    assert.include act.object, "pump_io"
    assert.isObject act.object.pump_io
    assert.include act.object.pump_io, "shared"
    assert.isBoolean act.object.pump_io.shared
    return

  return

noShared = (feed) ->
  assert.include feed, "items"
  assert.isArray feed.items
  assert.lengthOf feed.items, 20
  _.each feed.items, (act) ->
    assert.include act, "object"
    assert.isObject act.object
    assert.isFalse _.has(act.object, "pump_io") and _.has(act.object.pump_io, "shared")
    return

  return

sharedIs = (val) ->
  (feed) ->
    assert.include feed, "items"
    assert.isArray feed.items
    assert.lengthOf feed.items, 20
    _.each feed.items, (act) ->
      assert.include act, "object"
      assert.isObject act.object
      assert.include act.object, "pump_io"
      assert.isObject act.object.pump_io
      assert.include act.object.pump_io, "shared"
      if act.object.secretNumber % 2
        assert.equal act.object.pump_io.shared, val
      else
        assert.equal act.object.pump_io.shared, false
      return

    return

sameUser = (url, objects) ->
  ctx =
    topic: (pair0, pair1, cl) ->
      callback = @callback
      cred = makeCred(cl, pair0)
      Step (->
        httputil.getJSON url, cred, this
        return
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed
        return

      return

    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed
      return

    "and we examine the feed":
      topic: (feed) ->
        feed

      "all items have shares": haveShares
      "some items have non-empty shares": correctShares
      "all items have the shared flag": haveShared
      "all items have shared = false": sharedIs(false)

  ctx

justClient = (url, objects) ->
  ctx =
    topic: (pair0, pair1, cl) ->
      callback = @callback
      cred =
        consumer_key: cl.client_id
        consumer_secret: cl.client_secret

      Step (->
        httputil.getJSON url, cred, this
        return
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed
        return

      return

    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed
      return

    "and we examine the feed":
      topic: (feed) ->
        feed

      "all items have shares": haveShares
      "some items have non-empty shares": correctShares
      "no items have the shared flag": noShared

  ctx

otherUser = (url, objects) ->
  ctx =
    topic: (pair0, pair1, cl) ->
      callback = @callback
      cred = makeCred(cl, pair1)
      Step (->
        httputil.getJSON url, cred, this
        return
      ), (err, feed, response) ->
        if err
          callback err, null
        else
          callback null, feed
        return

      return

    "it works": (err, feed) ->
      assert.ifError err
      assert.isObject feed
      return

    "and we examine the feed":
      topic: (feed) ->
        feed

      "all items have shares": haveShares
      "some items have non-empty shares": correctShares
      "all items have the shared flag": haveShared
      "all items have correct shared value": sharedIs(true)

  ctx


# A batch to test favoriting/unfavoriting objects
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "it works": (err, app) ->
    assert.ifError err
    return

  "and we register a client":
    topic: ->
      newClient @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      return

    "and we register two users":
      topic: (cl) ->
        callback = @callback
        Step (->
          newPair cl, "thecat", "forgetting-something...", @parallel()
          newPair cl, "carl", "im@ikea!", @parallel()
          return
        ), callback
        return

      "it works": (err, pair0, pair1) ->
        assert.ifError err
        assert.isObject pair0
        assert.isObject pair1
        return

      "and the first one posts a bunch of notes and the second one shares every other one":
        topic: (pair0, pair1, cl) ->
          callback = @callback
          cred0 = makeCred(cl, pair0)
          cred1 = makeCred(cl, pair1)
          url0 = "http://localhost:4815/api/user/thecat/feed"
          url1 = "http://localhost:4815/api/user/carl/feed"
          posts = undefined
          Step (->
            group = @group()
            _.times 20, (i) ->
              act =
                to: [pair0.user.profile]
                cc: [
                  objectType: "collection"
                  id: "http://activityschema.org/collection/public"
                ]
                verb: "post"
                object:
                  objectType: "note"
                  secretNumber: i
                  content: "I feel like I'm forgetting something " + i

              httputil.postJSON url0, cred0, act, group()
              return

            return
          ), ((err, results) ->
            group = @group()
            throw err  if err
            posts = results
            _.each posts, (post, i) ->
              if i % 2
                act =
                  verb: "share"
                  object: post.object

                httputil.postJSON url1, cred1, act, group()
              return

            return
          ), (err, shares) ->
            if err
              callback err
            else
              callback null
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we check their major inbox with same user credentials": sameUser("http://localhost:4815/api/user/thecat/inbox/major")
        "and we check their major feed with same user credentials": sameUser("http://localhost:4815/api/user/thecat/feed/major")
        "and we check their major direct inbox with same user credentials": sameUser("http://localhost:4815/api/user/thecat/inbox/direct/major")
        "and we check their major feed with client credentials": justClient("http://localhost:4815/api/user/thecat/feed/major")
        "and we check the first user's major feed with different user credentials": otherUser("http://localhost:4815/api/user/thecat/feed/major")

suite["export"] module
