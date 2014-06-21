# distributor-remote-update-cred-test-as-root.js
#
# Test automatically updating remote credentials on failure
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
        newCredentials "alice", "t4steful", "social.localhost", 80, @parallel()
        newCredentials "bob", "gritty*1", "photo.localhost", 80, @parallel()
        return
      ), callback
      return

    "it works": (err, cred1, cred2) ->
      assert.ifError err
      assert.isObject cred1
      assert.isObject cred2
      return

    "and one user sends another a note":
      topic: (cred1, cred2) ->
        url = "http://social.localhost/api/user/alice/feed"
        act =
          verb: "note"
          to: [
            objectType: "person"
            id: "acct:bob@photo.localhost"
          ]
          object:
            objectType: "note"
            content: "Hi Bob"

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
          ), 5000
          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we clear the remote credentials":
          topic: (body, cred1, cred2, social, photo) ->
            photo.killCred "alice@social.localhost", @callback
            return

          "it works": (err) ->
            assert.ifError err
            return

          "and one user sends the other another note":
            topic: (body, cred1, cred2, social, photo) ->
              url = "http://social.localhost/api/user/alice/feed"
              act =
                verb: "note"
                to: [
                  objectType: "person"
                  id: "acct:bob@photo.localhost"
                ]
                object:
                  objectType: "note"
                  content: "Hi again, Bob"

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
                ), 5000
                return

              "it works": (err) ->
                assert.ifError err
                return

              "and we check the recipients' inbox":
                topic: (second, first, cred1, cred2, social, photo) ->
                  url = "http://photo.localhost/api/user/bob/inbox"
                  callback = @callback
                  gj url, cred2, (err, feed, resp) ->
                    if err
                      callback err, null, null
                    else
                      callback null, feed, second
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
