# group-foreign-id-test.js
#
# Add a group with an externally-created ID
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
OAuth = require("oauth-evanp").OAuth
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
setupApp = oauthutil.setupApp
newClient = oauthutil.newClient
newPair = oauthutil.newPair
newCredentials = oauthutil.newCredentials
validActivity = actutil.validActivity
validActivityObject = actutil.validActivityObject
validFeed = actutil.validFeed
suite = vows.describe("group foreign id test")

# A batch to test groups with foreign IDs
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

  "and we register a user":
    topic: ->
      newCredentials "walter", "he1s3nbe4g", @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "and we GET the group endpoint with no ID parameter":
      topic: (cred) ->
        cb = @callback
        Step (->
          url = "http://localhost:4815/api/group"
          httputil.getJSON url, cred, this
          return
        ), (err, doc, response) ->
          if err and err.statusCode is 400
            cb null
          else if err
            cb err
          else
            cb new Error("Unexpected success")
          return

        return

      "it fails correctly": (err, group) ->
        assert.ifError err
        return

    "and we GET the group endpoint with an ID that doesn't exist":
      topic: (cred) ->
        cb = @callback
        Step (->
          url = "http://localhost:4815/api/group?id=tag:pump.io,2012:test:group:non-existent"
          httputil.getJSON url, cred, this
          return
        ), (err, doc, response) ->
          if err and err.statusCode is 404
            cb null
          else if err
            cb err
          else
            cb new Error("Unexpected success")
          return

        return

      "it fails correctly": (err, group) ->
        assert.ifError err
        return

    "and we create a new group with a foreign ID":
      topic: (cred) ->
        cb = @callback
        Step (->
          url = "http://localhost:4815/api/user/walter/feed"
          activity =
            verb: "create"
            object:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:1"
              displayName: "Friends"

          httputil.postJSON url, cred, activity, this
          return
        ), (err, doc, response) ->
          cb err, doc
          return

        return

      "it works": (err, activity) ->
        assert.ifError err
        return

      "it looks correct": (err, activity) ->
        assert.ifError err
        validActivity activity
        return

      "its self-link uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.links.self.href, "http://localhost:4815/api/group?id=" + encodeURIComponent("tag:pump.io,2012:test:group:1")
        return

      "its members feed uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.members.url, "http://localhost:4815/api/group/members?id=" + encodeURIComponent("tag:pump.io,2012:test:group:1")
        return

      "its inbox feed uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.links["activity-inbox"].href, "http://localhost:4815/api/group/inbox?id=" + encodeURIComponent("tag:pump.io,2012:test:group:1")
        return

      "its documents feed uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.documents.url, "http://localhost:4815/api/group/documents?id=" + encodeURIComponent("tag:pump.io,2012:test:group:1")
        return

      "and we GET the group":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group?id=tag:pump.io,2012:test:group:1"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, group) ->
          assert.ifError err
          return

        "it looks correct": (err, group) ->
          assert.ifError err
          validActivityObject group
          return

      "and we GET the group members":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group/members?id=tag:pump.io,2012:test:group:1"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          validFeed feed
          return

        "it's empty": (err, feed) ->
          assert.ifError err
          assert.equal feed.totalItems, 0
          assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
          return

      "and we GET the group inbox":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group/inbox?id=tag:pump.io,2012:test:group:1"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          validFeed feed
          return

        "it's empty": (err, feed) ->
          assert.ifError err
          assert.equal feed.totalItems, 0
          assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
          return

      "and we GET the group documents feed":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group/documents?id=tag:pump.io,2012:test:group:1"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          validFeed feed
          return

        "it's empty": (err, feed) ->
          assert.ifError err
          assert.equal feed.totalItems, 0
          assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
          return

    "and we create another group with a foreign ID and join it":
      topic: (cred) ->
        cb = @callback
        url = "http://localhost:4815/api/user/walter/feed"
        Step (->
          activity =
            verb: "create"
            object:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:2"
              displayName: "Family"

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "join"
            object:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:2"

          httputil.postJSON url, cred, activity, this
          return
        ), (err, doc, response) ->
          cb err, doc
          return

        return

      "it works": (err, activity) ->
        assert.ifError err
        return

      "it looks correct": (err, activity) ->
        assert.ifError err
        validActivity activity
        return

      "and we GET the group members":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group/members?id=tag:pump.io,2012:test:group:2"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, feed) ->
          assert.ifError err
          validFeed feed
          return

        "it's got one member": (err, feed) ->
          assert.ifError err
          assert.equal feed.totalItems, 1
          return

    "and we create another group with a foreign ID and post to it":
      topic: (cred) ->
        cb = @callback
        url = "http://localhost:4815/api/user/walter/feed"
        Step (->
          activity =
            verb: "create"
            object:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:3"
              displayName: "Enemies"

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "post"
            to: [
              objectType: "group"
              id: "tag:pump.io,2012:test:group:3"
            ]
            object:
              objectType: "note"
              content: "I am the one who knocks."

          httputil.postJSON url, cred, activity, this
          return
        ), (err, doc, response) ->
          cb err, doc
          return

        return

      "it works": (err, activity) ->
        assert.ifError err
        return

      "it looks correct": (err, activity) ->
        assert.ifError err
        validActivity activity
        return

      "and we GET the group inbox":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group/inbox?id=tag:pump.io,2012:test:group:3"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it works": (err, feed, act) ->
          assert.ifError err
          validFeed feed
          return

        "it's got our activity": (err, feed, act) ->
          assert.ifError err
          assert.equal feed.totalItems, 1
          assert.equal feed.items.length, 1
          assert.isObject feed.items[0]
          assert.equal feed.items[0].id, act.id
          return

    "and we create another group with a foreign ID and post an image to it":
      topic: (cred) ->
        cb = @callback
        url = "http://localhost:4815/api/user/walter/feed"
        Step (->
          activity =
            verb: "create"
            object:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:4"
              displayName: "Criminals"

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "join"
            object:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:4"

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "post"
            object:
              id: "http://photo.example/heisenberg/me-making-meth.jpg"
              objectType: "image"
              displayName: "Ha ha ha"
              url: "http://photo.example/heisenberg/me-making-meth.jpg"

            target:
              objectType: "group"
              id: "tag:pump.io,2012:test:group:4"

          httputil.postJSON url, cred, activity, this
          return
        ), (err, doc, response) ->
          cb err, doc
          return

        return

      "it works": (err, activity) ->
        assert.ifError err
        return

      "it looks correct": (err, activity) ->
        assert.ifError err
        validActivity activity
        return

      "and we GET the documents feed":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/group/documents?id=tag:pump.io,2012:test:group:4"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc, act
            return

          return

        "it works": (err, feed, act) ->
          assert.ifError err
          validFeed feed
          return

        "it's got our activity": (err, feed, act) ->
          assert.ifError err
          assert.equal feed.totalItems, 1
          assert.equal feed.items.length, 1
          assert.isObject feed.items[0]
          assert.equal feed.items[0].id, act.object.id
          return

suite["export"] module
