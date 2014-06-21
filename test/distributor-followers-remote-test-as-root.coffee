# distributor-followers-remote-test-as-root.js
#
# Test distribution to followers of a user
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
http = require("http")
querystring = require("querystring")
_ = require("underscore")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
pj = httputil.postJSON
gj = httputil.getJSON
dialbackApp = require("./lib/dialback").dialbackApp
setupApp = oauthutil.setupApp
suite = vows.describe("distributor remote test")
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
        newCredentials "fanatic", "give*me*that", "social.localhost", 80, @parallel()
        newCredentials "arbus", "shadowed*1", "photo.localhost", 80, @parallel()
        return
      ), callback
      return

    "it works": (err, cred1, cred2) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2
      return

    "and one user follows the other":
      topic: (cred1, cred2) ->
        url = "http://social.localhost/api/user/fanatic/feed"
        act =
          verb: "follow"
          object:
            id: "acct:arbus@photo.localhost"
            objectType: "person"

        callback = @callback
        pj url, cred1, act, (err, body, resp) ->
          if err
            callback err, null
          else
            callback null, body
          return

        return

      "it works": (err, body) ->
        assert.ifError err
        assert.isObject body
        return

      "and we wait a few seconds for delivery":
        topic: ->
          callback = @callback
          setTimeout (->
            callback null
            return
          ), 1000
          return

        "it works": (err) ->
          assert.ifError err
          return

        "and the second user posts an image to followers":
          topic: (act, cred1, cred2) ->
            url = "http://photo.localhost/api/user/arbus/feed"
            callback = @callback
            post =
              verb: "post"
              cc: [
                objectType: "collection"
                id: "http://photo.localhost/api/user/arbus/followers"
              ]
              object:
                objectType: "image"
                displayName: "My Photo"

            pj url, cred2, post, (err, act, resp) ->
              if err
                callback err, null
              else
                callback null, act
              return

            return

          "it works": (err, act) ->
            assert.ifError err
            assert.isObject act
            return

          "and we wait a few seconds for delivery":
            topic: ->
              callback = @callback
              setTimeout (->
                callback null
                return
              ), 1000
              return

            "it works": (err) ->
              assert.ifError err
              return

            "and we check the first user's inbox":
              topic: (posted, followed, cred1, cred2) ->
                callback = @callback
                url = "http://social.localhost/api/user/fanatic/inbox"
                gj url, cred1, (err, feed, resp) ->
                  if err
                    callback err, null, null
                  else
                    callback null, feed, posted
                  return

                return

              "it works": (err, feed, act) ->
                assert.ifError err
                assert.isObject feed
                assert.isObject act
                return

              "it includes the activity": (err, feed, act) ->
                assert.ifError err
                assert.isObject feed
                assert.isObject act
                assert.include feed, "items"
                assert.isArray feed.items
                assert.greater feed.items.length, 0
                assert.isObject _.find(feed.items, (item) ->
                  item.id is act.id
                )
                return

suite["export"] module
