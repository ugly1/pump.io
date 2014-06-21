# distributor-multiple-remote-test-as-root.js
#
# Test distribution to two remote users on the same server
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
suite = vows.describe("distributor multiple remote test")
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

  "and we register one user on one and two users on the other":
    topic: ->
      callback = @callback
      Step (->
        newCredentials "alicecooper", "rock*g0d", "photo.localhost", 80, @parallel()
        newCredentials "garth", "party*on1", "social.localhost", 80, @parallel()
        newCredentials "wayne", "party*on2", "social.localhost", 80, @parallel()
        return
      ), callback
      return

    "it works": (err, cred1, cred2, cred3) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2
      assert.isObject cred3
      return

    "and two users follows the first":
      topic: (cred1, cred2, cred3) ->
        act =
          verb: "follow"
          object:
            id: "acct:alicecooper@photo.localhost"
            objectType: "person"

        callback = @callback
        Step (->
          pj "http://social.localhost/api/user/garth/feed", cred2, act, @parallel()
          pj "http://social.localhost/api/user/wayne/feed", cred3, act, @parallel()
          return
        ), (err, posted1, posted2) ->
          callback err
          return

        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we wait a second for delivery":
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

        "and the first user posts an image":
          topic: (cred1, cred2, cred3) ->
            url = "http://photo.localhost/api/user/alicecooper/feed"
            callback = @callback
            post =
              verb: "post"
              object:
                objectType: "image"
                displayName: "My Photo"

            pj url, cred1, post, (err, act, resp) ->
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

          "and we wait a second for delivery":
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

            "and we check the other users' inboxes":
              topic: (posted, cred1, cred2, cred3) ->
                callback = @callback
                Step (->
                  gj "http://social.localhost/api/user/garth/inbox", cred2, @parallel()
                  gj "http://social.localhost/api/user/wayne/inbox", cred3, @parallel()
                  return
                ), (err, inbox2, inbox3) ->
                  callback err, inbox2, inbox3, posted
                  return

                return

              "it works": (err, inbox2, inbox3, act) ->
                assert.ifError err
                assert.isObject inbox2
                assert.isObject inbox3
                assert.isObject act
                return

              "they include the activity": (err, inbox2, inbox3, act) ->
                assert.ifError err
                assert.isObject inbox2
                assert.isObject inbox3
                assert.isObject act
                assert.include inbox2, "items"
                assert.isArray inbox2.items
                assert.greater inbox2.items.length, 0
                assert.isObject _.find(inbox2.items, (item) ->
                  item.id is act.id
                ), "Activity is not in first inbox"
                assert.include inbox3, "items"
                assert.isArray inbox3.items
                assert.greater inbox3.items.length, 0
                assert.isObject _.find(inbox3.items, (item) ->
                  item.id is act.id
                ), "Activity is not in second inbox"
                return

suite["export"] module
