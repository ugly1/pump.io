# distributor-remote-test-as-root.js
#
# Test distribution to remote servers
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
actutil = require("./lib/activity")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
validActivity = actutil.validActivity
pj = httputil.postJSON
gj = httputil.getJSON
setupApp = oauthutil.setupApp
suite = vows.describe("remote activity object test")
serverOf = (url) ->
  parts = urlparse(url)
  parts.hostname

testLink = (rel) ->
  (err, body) ->
    annie = body.object
    assert.isObject annie
    assert.isObject annie.links
    assert.isObject annie.links[rel]
    assert.isString annie.links[rel].href
    assert.equal serverOf(annie.links[rel].href), "photo.localhost", "Mismatch on link " + rel
    return

testFeed = (feed) ->
  (err, body) ->
    annie = body.object
    assert.isObject annie
    assert.isObject annie.links
    assert.isObject annie[feed]
    assert.isString annie[feed].url
    assert.equal serverOf(annie[feed].url), "photo.localhost", "Mismatch on " + feed + " feed"
    return

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
        newCredentials "magazine", "t4steful", "social.localhost", 80, @parallel()
        newCredentials "annie", "glamourous*1", "photo.localhost", 80, @parallel()
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
        url = "http://social.localhost/api/user/magazine/feed"
        act =
          verb: "follow"
          object:
            id: "acct:annie@photo.localhost"
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
        validActivity body
        return

      "the self link is correct": testLink("self")
      "the activity-inbox link is correct": testLink("activity-inbox")
      "the activity-outbox link is correct": testLink("activity-outbox")
      "the following feed is correct": testFeed("following")
      "the favorites feed is correct": testFeed("favorites")
      "the followers feed is correct": testFeed("followers")
      "the lists feed is correct": testFeed("lists")

suite["export"] module
