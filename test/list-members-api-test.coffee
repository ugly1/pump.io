# list-members-api-test.js
#
# Test user collections of people
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
Step = require("step")
_ = require("underscore")
http = require("http")
urlparse = require("url").parse
OAuth = require("oauth-evanp").OAuth
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
Queue = require("jankyqueue")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
newPair = oauthutil.newPair
register = oauthutil.register
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

assertValidList = (doc, count, itemCount) ->
  assert.include doc, "author"
  assert.include doc.author, "id"
  assert.include doc.author, "displayName"
  assert.include doc.author, "objectType"
  assert.include doc, "totalItems"
  assert.include doc, "items"
  assert.include doc, "displayName"
  assert.include doc, "url"
  assert.equal doc.totalItems, count  if _(count).isNumber()
  assert.lengthOf doc.items, itemCount  if _(itemCount).isNumber()
  return

assertValidActivity = (act) ->
  assert.isString act.id
  assert.include act, "actor"
  assert.isObject act.actor
  assert.include act.actor, "id"
  assert.isString act.actor.id
  assert.include act, "verb"
  assert.isString act.verb
  assert.include act, "object"
  assert.isObject act.object
  assert.include act.object, "id"
  assert.isString act.object.id
  assert.include act, "published"
  assert.isString act.published
  assert.include act, "updated"
  assert.isString act.updated
  return

suite = vows.describe("list members api test")

# A batch to test following/unfollowing users
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

    "and a user adds a lot of people to a list":
      topic: (cl) ->
        cb = @callback
        url = "http://localhost:4815/api/user/trent/feed"
        others = undefined
        pair = undefined
        cred = undefined
        list = undefined
        Step (->
          newPair cl, "trent", "Cahp6oat", @parallel()
          return
        ), ((err, results) ->
          throw err  if err
          pair = results
          cred = makeCred(cl, pair)
          act =
            verb: "create"
            object:
              objectType: "collection"
              displayName: "Homies"
              objectTypes: ["person"]

          httputil.postJSON url, cred, act, this
          return
        ), ((err, doc, response) ->
          i = undefined
          group = @group()
          throw err  if err
          list = doc.object
          i = 0
          while i < 50
            register cl, "other" + i, "Uloo8Eip", group()
            i++
          return
        ), ((err, users) ->
          group = @group()
          throw err  if err
          others = users
          _.each others, (other) ->
            act =
              verb: "add"
              object: other.profile
              target: list

            httputil.postJSON url, cred, act, group()
            return

          return
        ), (err) ->
          if err
            cb err, null, null
          else
            cb null, list, cred
          return

        return

      "it works": (err, list) ->
        assert.ifError err
        assert.isObject list
        return

      "and we get the members collection":
        topic: (list, cred) ->
          cb = @callback
          httputil.getJSON list.members.url, cred, (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          assertValidList feed, 50, 20
          return

        "it has a next link": (err, feed) ->
          assert.ifError err
          assert.include feed, "links"
          assert.include feed.links, "next"
          assert.include feed.links.next, "href"
          return

        "it has a prev link": (err, feed) ->
          assert.ifError err
          assert.include feed, "links"
          assert.include feed.links, "prev"
          assert.include feed.links.prev, "href"
          return

        "and we get its next link":
          topic: (feed, list, cred) ->
            cb = @callback
            httputil.getJSON feed.links.next.href, cred, (err, doc, response) ->
              cb err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 50, 20
            return

          "it has a next link": (err, feed) ->
            assert.ifError err
            assert.include feed, "links"
            assert.include feed.links, "next"
            assert.include feed.links.next, "href"
            return

          "it has a prev link": (err, feed) ->
            assert.ifError err
            assert.include feed, "links"
            assert.include feed.links, "prev"
            assert.include feed.links.prev, "href"
            return

          "and we get its prev link":
            topic: (middle, feed, list, cred) ->
              cb = @callback
              httputil.getJSON middle.links.prev.href, cred, (err, doc, response) ->
                cb err, doc, feed
                return

              return

            "it works": (err, feed, orig) ->
              assert.ifError err
              assertValidList feed, 50, 20
              return

            "it's the same as the current set": (err, feed, orig) ->
              i = undefined
              assert.ifError err
              assert.equal feed.items.length, orig.items.length
              i = 0
              while i < feed.items.length
                assert.equal feed.items[i].id, orig.items[i].id
                i++
              return

          "and we get its next link":
            topic: (middle, feed, list, cred) ->
              cb = @callback
              httputil.getJSON middle.links.next.href, cred, (err, doc, response) ->
                cb err, doc
                return

              return

            "it works": (err, feed) ->
              assert.ifError err
              assertValidList feed, 50, 10
              return

        "and we get its prev link":
          topic: (feed, list, cred) ->
            cb = @callback
            httputil.getJSON feed.links.prev.href, cred, (err, doc, response) ->
              cb err, doc
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            assertValidList feed, 50, 0
            return

          "it has no next link": (err, feed) ->
            assert.ifError err
            assert.include feed, "links"
            assert.isFalse _.has(feed.links, "next")
            return

          "it has no prev link": (err, feed) ->
            assert.ifError err
            assert.include feed, "links"
            assert.isFalse _.has(feed.links, "prev")
            return

suite["export"] module
