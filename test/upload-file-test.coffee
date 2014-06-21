# upload-file-test.js
#
# Test uploading a file to a server
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
os = require("os")
fs = require("fs")
path = require("path")
mkdirp = require("mkdirp")
rimraf = require("rimraf")
_ = require("underscore")
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
validFeed = actutil.validFeed
setupAppConfig = oauthutil.setupAppConfig
newCredentials = oauthutil.newCredentials
newPair = oauthutil.newPair
newClient = oauthutil.newClient
register = oauthutil.register
suite = vows.describe("upload file test")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

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

  "and we set up the app":
    topic: (dir) ->
      setupAppConfig
        uploaddir: dir
      , @callback
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

      "and we create a new user":
        topic: (cl) ->
          newPair cl, "mike", "stormtroopers_hittin_the_ground", @callback
          return

        "it works": (err, pair) ->
          assert.ifError err
          assert.isObject pair
          return

        "and we check the uploads endpoint": httputil.endpoint("/api/user/mike/uploads", [
          "POST"
          "GET"
        ])
        "and we get the uploads endpoint of a new user":
          topic: (pair, cl) ->
            cred = makeCred(cl, pair)
            callback = @callback
            url = "http://localhost:4815/api/user/mike/uploads"
            Step (->
              httputil.getJSON url, cred, this
              return
            ), (err, feed, response) ->
              callback err, feed

            return

          "it works": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            return

          "it is correct": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            validFeed feed
            return

          "it is empty": (err, feed) ->
            assert.ifError err
            assert.isObject feed
            assert.equal feed.totalItems, 0
            assert.lengthOf feed.items, 0
            return

          "and we upload a file":
            topic: (feed, pair, cl) ->
              cred = makeCred(cl, pair)
              callback = @callback
              url = "http://localhost:4815/api/user/mike/uploads"
              fileName = path.join(__dirname, "data", "image1.jpg")
              Step (->
                httputil.postFile url, cred, fileName, "image/jpeg", this
                return
              ), (err, doc, response) ->
                callback err, doc

              return

            "it works": (err, doc) ->
              assert.ifError err
              assert.isObject doc
              return

            "it looks right": (err, doc) ->
              assert.ifError err
              assert.isObject doc
              assert.include doc, "objectType"
              assert.equal doc.objectType, "image"
              assert.include doc, "fullImage"
              assert.isObject doc.fullImage
              assert.include doc.fullImage, "url"
              assert.isString doc.fullImage.url
              assert.isFalse _.has(doc, "_slug")
              assert.isFalse _.has(doc, "_uuid")
              return

            "and we get the file":
              topic: (doc, feed, pair, cl) ->
                cred = makeCred(cl, pair)
                callback = @callback
                url = doc.fullImage.url
                oa = undefined
                oa = httputil.newOAuth(url, cred)
                Step (->
                  oa.get url, cred.token, cred.token_secret, this
                  return
                ), (err, data, response) ->
                  callback err, data
                  return

                return

              "it works": (err, data) ->
                assert.ifError err
                return

            "and we get the uploads feed again":
              topic: (doc, feed, pair, cl) ->
                cred = makeCred(cl, pair)
                callback = @callback
                url = "http://localhost:4815/api/user/mike/uploads"
                Step (->
                  httputil.getJSON url, cred, this
                  return
                ), (err, feed, response) ->
                  callback err, feed, doc

                return

              "it works": (err, feed, doc) ->
                assert.ifError err
                assert.isObject feed
                return

              "it is correct": (err, feed, doc) ->
                assert.ifError err
                assert.isObject feed
                validFeed feed
                return

              "it has our upload": (err, feed, doc) ->
                assert.ifError err
                assert.isObject feed
                assert.equal feed.totalItems, 1
                assert.lengthOf feed.items, 1
                assert.equal feed.items[0].id, doc.id
                return

            "and we post an activity with the upload as the object":
              topic: (upl, feed, pair, cl) ->
                cred = makeCred(cl, pair)
                callback = @callback
                url = "http://localhost:4815/api/user/mike/feed"
                act =
                  verb: "post"
                  object: upl

                Step (->
                  httputil.postJSON url, cred, act, this
                  return
                ), (err, doc, response) ->
                  callback err, doc

                return

              "it works": (err, act) ->
                assert.ifError err
                assert.isObject act
                return

      "and we register another user":
        topic: (cl) ->
          newPair cl, "tom", "pick*eat*rate", @callback
          return

        "it works": (err, pair) ->
          assert.ifError err
          assert.isObject pair
          return

        "and we upload a file as a Binary object":
          topic: (pair, cl) ->
            cred = makeCred(cl, pair)
            callback = @callback
            url = "http://localhost:4815/api/user/tom/uploads"
            fileName = path.join(__dirname, "data", "image2.jpg")
            Step (->
              fs.readFile fileName, this
              return
            ), ((err, data) ->
              bin = undefined
              throw err  if err
              bin =
                length: data.length
                mimeType: "image/jpeg"

              bin.data = data.toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(RegExp("=", "g"), "")
              httputil.postJSON url, cred, bin, this
              return
            ), (err, doc, result) ->
              if err
                callback err, null
              else
                callback null, doc
              return

            return

          "it works": (err, doc) ->
            assert.ifError err
            assert.isObject doc
            return

          "it looks right": (err, doc) ->
            assert.ifError err
            assert.isObject doc
            assert.include doc, "objectType"
            assert.equal doc.objectType, "image"
            assert.include doc, "fullImage"
            assert.isObject doc.fullImage
            assert.include doc.fullImage, "url"
            assert.isString doc.fullImage.url
            assert.isFalse _.has(doc, "_slug")
            assert.isFalse _.has(doc, "_uuid")
            return

suite["export"] module
