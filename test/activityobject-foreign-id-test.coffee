# activityobject-foreign-id-test.js
#
# Add an activity object with an externally-created ID
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
suite = vows.describe("activityobject foreign id test")

# A batch to test activity objects with foreign IDs
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
      newCredentials "jesse", "chili*p!", @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "and we GET the activity object endpoint with no ID parameter":
      topic: (cred) ->
        cb = @callback
        Step (->
          url = "http://localhost:4815/api/image"
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

      "it fails correctly": (err, image) ->
        assert.ifError err
        return

    "and we GET the activity object endpoint with an ID that doesn't exist":
      topic: (cred) ->
        cb = @callback
        Step (->
          url = "http://localhost:4815/api/image?id=tag:pump.io,2012:test:image:non-existent"
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

      "it fails correctly": (err, image) ->
        assert.ifError err
        return

    "and we create a new image with a foreign ID":
      topic: (cred) ->
        cb = @callback
        Step (->
          url = "http://localhost:4815/api/user/jesse/feed"
          activity =
            verb: "create"
            object:
              objectType: "image"
              id: "tag:pump.io,2012:test:image:1"
              displayName: "Me and Emilio down by the schoolyard"

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
        assert.equal activity.object.links.self.href, "http://localhost:4815/api/image?id=" + encodeURIComponent("tag:pump.io,2012:test:image:1")
        return

      "its likes feed uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.likes.url, "http://localhost:4815/api/image/likes?id=" + encodeURIComponent("tag:pump.io,2012:test:image:1")
        return

      "its replies feed uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.replies.url, "http://localhost:4815/api/image/replies?id=" + encodeURIComponent("tag:pump.io,2012:test:image:1")
        return

      "its shares feed uses the foreign ID format": (err, activity) ->
        assert.ifError err
        assert.equal activity.object.shares.url, "http://localhost:4815/api/image/shares?id=" + encodeURIComponent("tag:pump.io,2012:test:image:1")
        return

      "and we GET the image":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image?id=tag:pump.io,2012:test:image:1"
            httputil.getJSON url, cred, this
            return
          ), (err, doc, response) ->
            cb err, doc
            return

          return

        "it works": (err, image) ->
          assert.ifError err
          return

        "it looks correct": (err, image) ->
          assert.ifError err
          validActivityObject image
          return

      "and we GET the image replies":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image/replies?id=tag:pump.io,2012:test:image:1"
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

      "and we GET the image likes":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image/likes?id=tag:pump.io,2012:test:image:1"
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

      "and we GET the image shares":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image/shares?id=tag:pump.io,2012:test:image:1"
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

    "and we create another image with a foreign ID and comment on it":
      topic: (cred) ->
        cb = @callback
        url = "http://localhost:4815/api/user/jesse/feed"
        Step (->
          activity =
            verb: "create"
            object:
              objectType: "image"
              id: "tag:pump.io,2012:test:image:2"
              displayName: "Mr. White yo"

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "post"
            object:
              objectType: "comment"
              content: "Nice picture!"
              inReplyTo:
                objectType: "image"
                id: "tag:pump.io,2012:test:image:2"

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

      "and we GET the image replies":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image/replies?id=tag:pump.io,2012:test:image:2"
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

    "and we create another image with a foreign ID and like it":
      topic: (cred) ->
        cb = @callback
        url = "http://localhost:4815/api/user/jesse/feed"
        Step (->
          activity =
            verb: "create"
            object:
              objectType: "image"
              id: "tag:pump.io,2012:test:image:3"
              displayName: "Mike. He's OK."

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "like"
            object:
              objectType: "image"
              id: "tag:pump.io,2012:test:image:3"

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

      "and we GET the image likes":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image/likes?id=tag:pump.io,2012:test:image:3"
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

        "it's got our person": (err, feed, act) ->
          assert.ifError err
          assert.equal feed.totalItems, 1
          assert.equal feed.items.length, 1
          assert.isObject feed.items[0]
          assert.equal feed.items[0].id, act.actor.id
          return

    "and we create another image with a foreign ID and share it":
      topic: (cred) ->
        cb = @callback
        url = "http://localhost:4815/api/user/jesse/feed"
        Step (->
          activity =
            verb: "create"
            object:
              objectType: "image"
              id: "tag:pump.io,2012:test:image:4"
              displayName: "Me playing Rage"

          httputil.postJSON url, cred, activity, this
          return
        ), ((err, doc, response) ->
          throw err  if err
          activity =
            verb: "share"
            object:
              objectType: "image"
              id: "tag:pump.io,2012:test:image:4"

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

      "and we GET the shares":
        topic: (act, cred) ->
          cb = @callback
          Step (->
            url = "http://localhost:4815/api/image/shares?id=tag:pump.io,2012:test:image:4"
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

        "it's got our person": (err, feed, act) ->
          assert.ifError err
          assert.equal feed.totalItems, 1
          assert.equal feed.items.length, 1
          assert.isObject feed.items[0]
          assert.equal feed.items[0].id, act.actor.id
          return

suite["export"] module
