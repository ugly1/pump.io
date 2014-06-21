# distributor-remote-list-test-as-root.js
#
# Test distribution to remote members of a local list
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
http = require("http")
querystring = require("querystring")
_ = require("underscore")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
validActivityObject = actutil.validActivityObject
validActivity = actutil.validActivity
validFeed = actutil.validFeed
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
pj = httputil.postJSON
gj = httputil.getJSON
dialbackApp = require("./lib/dialback").dialbackApp
setupApp = oauthutil.setupApp
suite = vows.describe("distributor remote list test")
serverOf = (url) ->
  parts = urlparse(url)
  parts.hostname

suite.addBatch "When we set up two apps":
  topic: ->
    social = undefined
    photo = undefined
    callback = @callback
    Step (->
      setupApp 80, "social.localhost", @parallel()
      setupApp 80, "photo.localhost", @parallel()
      return
    ), (err, social, photo) ->
      if err
        callback err, null, null
      else
        callback null, social, photo
      return

    return

  "it works": (err, social, photo) ->
    assert.ifError err
    return

  teardown: (social, photo) ->
    social.close()  if social and social.close
    photo.close()  if photo and photo.close
    return

  "and we register one user on each":
    topic: ->
      callback = @callback
      Step (->
        newCredentials "claire", "clean*water", "social.localhost", 80, @parallel()
        newCredentials "adam", "mustache*1", "photo.localhost", 80, @parallel()
        return
      ), callback
      return

    "it works": (err, cred1, cred2) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2
      return

    "and one user adds the other to a list":
      topic: (cred1, cred2) ->
        url = "http://social.localhost/api/user/claire/feed"
        callback = @callback
        list = undefined
        Step (->
          act =
            verb: "create"
            object:
              objectType: "collection"
              displayName: "Lovers"
              objectTypes: ["person"]

          pj url, cred1, act, this
          return
        ), ((err, create) ->
          act = undefined
          throw err  if err
          list = create.object
          act =
            verb: "add"
            object:
              id: "acct:adam@photo.localhost"
              objectType: "person"

            target: list

          pj url, cred1, act, this
          return
        ), (err, add) ->
          if err
            callback err, null
          else
            callback err, list
          return

        return

      "it works": (err, list) ->
        assert.ifError err
        validActivityObject list
        return

      "and they send a note to that list":
        topic: (list, cred1, cred2) ->
          url = "http://social.localhost/api/user/claire/feed"
          act =
            verb: "post"
            to: [list]
            object:
              objectType: "note"
              content: "Hello."

          callback = @callback
          pj url, cred1, act, (err, body, resp) ->
            callback err, body
            return

          return

        "it works": (err, act) ->
          assert.ifError err
          validActivity act
          return

        "and we wait a couple seconds for delivery":
          topic: (post, list, cred1, cred2) ->
            callback = @callback
            setTimeout (->
              callback null
              return
            ), 2000
            return

          "it works": (err) ->
            assert.ifError err
            return

          "and we check the second user's inbox":
            topic: (post, list, cred1, cred2) ->
              url = "http://photo.localhost/api/user/adam/inbox"
              callback = @callback
              gj url, cred2, (err, feed, resp) ->
                if err
                  callback err, null, null, null
                else
                  callback null, feed, post, list
                return

              return

            "it works": (err, feed, post, list) ->
              assert.ifError err
              validFeed feed
              validActivity post
              return

            "it includes the activity": (err, feed, post, list) ->
              assert.ifError err
              assert.isObject feed
              assert.isObject post
              assert.include feed, "items"
              assert.isArray feed.items
              assert.greater feed.items.length, 0
              assert.isObject _.find(feed.items, (item) ->
                item.id is post.id
              )
              return

suite["export"] module
