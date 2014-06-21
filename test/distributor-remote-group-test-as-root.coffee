# distributor-remote-group-test-as-root.js
#
# Test joining and posting to remote groups
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
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
pj = httputil.postJSON
gj = httputil.getJSON
setupApp = oauthutil.setupApp
validActivity = actutil.validActivity
validActivityObject = actutil.validActivityObject
validFeed = actutil.validFeed
suite = vows.describe("distributor remote group test")
serverOf = (url) ->
  parts = urlparse(url)
  parts.hostname

suite.addBatch "When we set up three apps":
  topic: ->
    social = undefined
    photo = undefined
    callback = @callback
    Step (->
      setupApp 80, "social.localhost", @parallel()
      setupApp 80, "photo.localhost", @parallel()
      setupApp 80, "group.localhost", @parallel()
      return
    ), (err, social, photo, group) ->
      if err
        callback err, null, null
      else
        callback null, social, photo, group
      return

    return

  "it works": (err, social, photo) ->
    assert.ifError err
    return

  teardown: (social, photo, group) ->
    social.close()  if social and social.close
    photo.close()  if photo and photo.close
    group.close()  if group and group.close
    return

  "and we register one user on each":
    topic: ->
      callback = @callback
      Step (->
        newCredentials "groucho", "in*my*pajamas", "group.localhost", 80, @parallel()
        newCredentials "harpo", "honk|honk", "photo.localhost", 80, @parallel()
        newCredentials "chico", "watsamattayuface?", "social.localhost", 80, @parallel()
        return
      ), (err, groucho, harpo, chico) ->
        if err
          callback err, null
        else
          callback null,
            groucho: groucho
            harpo: harpo
            chico: chico

        return

      return

    "it works": (err, creds) ->
      assert.ifError err
      assert.isObject creds
      assert.isObject creds.groucho
      assert.isObject creds.harpo
      assert.isObject creds.chico
      return

    "and one user creates a group":
      topic: (creds) ->
        url = "http://group.localhost/api/user/groucho/feed"
        act =
          verb: "create"
          to: [
            id: "http://activityschema.org/collection/public"
            objectType: "collection"
          ]
          object:
            objectType: "group"
            displayName: "Marx Brothers"

        callback = @callback
        pj url, creds.groucho, act, (err, body, resp) ->
          if err
            callback err, null
          else
            callback null, body
          return

        return

      "it works": (err, body) ->
        assert.ifError err
        validActivity body
        return

      "and the other users join it":
        topic: (createAct, creds) ->
          callback = @callback
          group = createAct.object
          Step (->
            url = "http://photo.localhost/api/user/harpo/feed"
            act =
              verb: "join"
              object: group

            pj url, creds.harpo, act, this
            return
          ), ((err, body, resp) ->
            throw err  if err
            url = "http://social.localhost/api/user/chico/feed"
            act =
              verb: "join"
              object: group

            pj url, creds.chico, act, this
            return
          ), (err, body, resp) ->
            callback err
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and we wait a few seconds for delivery":
          topic: ->
            callback = @callback
            setTimeout (->
              callback null
              return
            ), 2000
            return

          "it works": (err) ->
            assert.ifError err
            return

          "and we check the group members feed":
            topic: (createAct, creds) ->
              callback = @callback
              url = createAct.object.members.url
              gj url, creds.groucho, (err, feed, resp) ->
                callback err, feed
                return

              return

            "it works": (err, feed) ->
              assert.ifError err
              validFeed feed
              return

            "it includes our remote users": (err, feed) ->
              assert.ifError err
              assert.isObject feed
              assert.include feed, "items"
              assert.isArray feed.items
              assert.greater feed.items.length, 0
              assert.isObject _.find(feed.items, (item) ->
                item.id is "acct:harpo@photo.localhost"
              )
              assert.isObject _.find(feed.items, (item) ->
                item.id is "acct:chico@social.localhost"
              )
              return

          "and one user posts a message to the group":
            topic: (createAct, creds) ->
              callback = @callback
              group = createAct.object
              url = "http://social.localhost/api/user/chico/feed"
              act =
                verb: "post"
                to: [group]
                object:
                  objectType: "note"
                  content: "You there, Pinky?"

              pj url, creds.chico, act, (err, act, resp) ->
                callback err, act
                return

              return

            "it works": (err, act) ->
              assert.ifError err
              validActivity act
              return

            "and we wait a few seconds for delivery":
              topic: ->
                callback = @callback
                setTimeout (->
                  callback null
                  return
                ), 2000
                return

              "it works": (err) ->
                assert.ifError err
                return

              "and we check the other user's inbox":
                topic: (postAct, createAct, creds) ->
                  url = "http://photo.localhost/api/user/harpo/inbox"
                  callback = @callback
                  gj url, creds.harpo, (err, feed, resp) ->
                    callback err, feed, postAct
                    return

                  return

                "it works": (err, feed, act) ->
                  assert.ifError err
                  validFeed feed
                  return

                "the posted note is in the feed": (err, feed, act) ->
                  assert.ifError err
                  assert.isObject feed
                  assert.include feed, "items"
                  assert.isArray feed.items
                  assert.greater feed.items.length, 0
                  assert.isObject _.find(feed.items, (item) ->
                    item.id is act.id
                  )
                  return

suite["export"] module
