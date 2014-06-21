# proxy-url-test-as-root.js
#
# Test that remote objects get pump_io.proxyURL properties
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
util = require("util")
assert = require("assert")
vows = require("vows")
Step = require("step")
http = require("http")
mkdirp = require("mkdirp")
rimraf = require("rimraf")
os = require("os")
fs = require("fs")
path = require("path")
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
setupAppConfig = oauthutil.setupAppConfig
setupApp = oauthutil.setupApp
suite = vows.describe("proxy url test")
serverOf = (url) ->
  parts = urlparse(url)
  parts.hostname

assertProxyURL = (obj, prop) ->
  assert.isObject obj[prop], "Property '" + prop + "' is not an object"
  assert.isObject obj[prop].pump_io, "Property '" + prop + "' has no pump_io object property"
  assert.isString obj[prop].pump_io.proxyURL, "Property '" + prop + "' has no proxyURL in its pump_io section"
  return

suite.addBatch "When we create a temporary upload dir":
  topic: ->
    callback = @callback
    dirname = path.join(os.tmpDir(), "upload-file-test", "" + Date.now())
    mkdirp dirname, (err) ->
      if err
        callback err, null
      else
        callback null, dirname
      return

    return

  "it works": (err, dir) ->
    assert.ifError err
    assert.isString dir
    return

  teardown: (dir) ->
    rimraf dir, (err) ->

    return

  "And we set up two apps":
    topic: (dir) ->
      social = undefined
      photo = undefined
      callback = @callback
      Step (->
        setupAppConfig
          port: 80
          hostname: "social.localhost"
        , @parallel()
        setupAppConfig
          port: 80
          hostname: "photo.localhost"
          uploaddir: dir
        , @parallel()
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
          newCredentials "colin", "t4steful", "social.localhost", 80, @parallel()
          newCredentials "jane", "gritty*1", "photo.localhost", 80, @parallel()
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
          url = "http://social.localhost/api/user/colin/feed"
          act =
            verb: "follow"
            object: cred2.user.profile

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
            ), 2000
            return

          "it works": (err) ->
            assert.ifError err
            return

          "and the second user posts an image":
            topic: (act, cred1, cred2) ->
              up = "http://photo.localhost/api/user/jane/uploads"
              feed = "http://photo.localhost/api/user/jane/feed"
              fileName = path.join(__dirname, "data", "image1.jpg")
              callback = @callback
              Step (->
                httputil.postFile up, cred2, fileName, "image/jpeg", this
                return
              ), ((err, doc, response) ->
                post = undefined
                throw err  if err
                post =
                  verb: "post"
                  object: doc

                pj feed, cred2, post, this
                return
              ), (err, act, resp) ->
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
                ), 2000
                return

              "it works": (err) ->
                assert.ifError err
                return

              "and we check the first user's inbox":
                topic: (posted, followed, cred1, cred2) ->
                  callback = @callback
                  url = "http://social.localhost/api/user/colin/inbox"
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

                "the activity includes proxy URLs": (err, feed, act) ->
                  fi0 = undefined
                  assert.ifError err
                  assert.isObject feed
                  assert.isObject act
                  assert.include feed, "items"
                  assert.isArray feed.items
                  assert.greater feed.items.length, 0
                  fi0 = _.find(feed.items, (item) ->
                    item.id is act.id
                  )
                  assert.isObject fi0
                  assertProxyURL fi0, "object"
                  assertProxyURL fi0.object, "likes"
                  assertProxyURL fi0.object, "replies"
                  assertProxyURL fi0.object, "shares"
                  assertProxyURL fi0.object, "image"
                  assertProxyURL fi0.object, "fullImage"
                  return

                "and we get the image proxyURL":
                  topic: (feed, posted, postedBefore, followed, cred1, cred2) ->
                    callback = @callback
                    fi0 = _.find(feed.items, (item) ->
                      item.id is posted.id
                    )
                    url = fi0.object.image.pump_io.proxyURL
                    oa = undefined
                    oa = httputil.newOAuth(url, cred1)
                    oa.get url, cred1.token, cred1.token_secret, (err, data, response) ->
                      callback err, data
                      return

                    return

                  "it works": (err, data) ->
                    assert.ifError err
                    assert.isString data
                    return

                "and we get the replies proxyURL":
                  topic: (feed, posted, postedBefore, followed, cred1, cred2) ->
                    callback = @callback
                    fi0 = _.find(feed.items, (item) ->
                      item.id is posted.id
                    )
                    url = fi0.object.replies.pump_io.proxyURL
                    oa = undefined
                    gj url, cred1, (err, replies, resp) ->
                      callback err, replies
                      return

                    return

                  "it works": (err, data) ->
                    assert.ifError err
                    assert.isObject data
                    return

suite["export"] module
