# user-inbox-api-test-as-root.js
#
# Test posting to the user inbox
#
# Copyright 2012-2013, E14N https://e14n.com/
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
version = require("../lib/version").version
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
dialbackApp = require("./lib/dialback").dialbackApp
setupApp = oauthutil.setupApp
validActivity = actutil.validActivity
clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret

assoc = (id, token, ts, callback) ->
  URL = "http://localhost:4815/api/client/register"
  requestBody = querystring.stringify(type: "client_associate")
  parseJSON = (err, response, data) ->
    obj = undefined
    if err
      callback err, null, null
    else
      try
        obj = JSON.parse(data)
        callback null, obj, response
      catch e
        callback e, null, null
    return

  ts = Date.now()  unless ts
  httputil.dialbackPost URL, id, token, ts, requestBody, "application/x-www-form-urlencoded", parseJSON
  return

suite = vows.describe("user inbox API")
suite.addBatch "When we set up the app":
  topic: ->
    app = undefined
    callback = @callback
    Step (->
      setupApp this
      return
    ), ((err, result) ->
      throw err  if err
      app = result
      dialbackApp 80, "social.localhost", this
      return
    ), (err, dbapp) ->
      if err
        callback err, null, null
      else
        callback err, app, dbapp
      return

    return

  teardown: (app, dbapp) ->
    app.close()
    dbapp.close()
    return

  "and we register a new user":
    topic: ->
      newCredentials "louisck", "hilarious!", @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "and we check the inbox endpoint": httputil.endpoint("/api/user/louisck/inbox", [
      "GET"
      "POST"
    ])
    "and we post to the inbox without credentials":
      topic: ->
        act =
          actor:
            id: "acct:user1@social.localhost"
            objectType: "person"

          id: "http://social.localhost/activity/1"
          verb: "post"
          object:
            id: "http://social.localhost/note/1"
            objectType: "note"
            content: "Hello, world!"

        requestBody = JSON.stringify(act)
        reqOpts =
          host: "localhost"
          port: 4815
          path: "/api/user/louisck/inbox"
          method: "POST"
          headers:
            "Content-Type": "application/json"
            "Content-Length": requestBody.length
            "User-Agent": "pump.io/" + version

        callback = @callback
        req = http.request(reqOpts, (res) ->
          body = ""
          res.setEncoding "utf8"
          res.on "data", (chunk) ->
            body = body + chunk
            return

          res.on "error", (err) ->
            callback err, null, null
            return

          res.on "end", ->
            callback null, res, body
            return

          return
        )
        req.on "error", (err) ->
          callback err, null, null
          return

        req.write requestBody
        req.end()
        return

      "and it fails correctly": (err, res, body) ->
        assert.ifError err
        assert.greater res.statusCode, 399
        assert.lesser res.statusCode, 500
        return

    "and we post to the inbox with unattributed OAuth credentials":
      topic: ->
        callback = @callback
        Step (->
          newClient this
          return
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user1@social.localhost"
              objectType: "person"

            id: "http://social.localhost/activity/2"
            verb: "post"
            object:
              id: "http://social.localhost/note/2"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
          return
        ), (err, body, res) ->
          if err and err.statusCode is 401
            callback null
          else if err
            callback err
          else
            callback new Error("Unexpected success")
          return

        return

      "and it fails correctly": (err) ->
        assert.ifError err
        return

    "and we post to the inbox with OAuth credentials for a host":
      topic: ->
        callback = @callback
        Step (->
          assoc "social.localhost", "VALID1", Date.now(), this
          return
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "http://social.localhost/"
              objectType: "service"

            id: "http://social.localhost/activity/3"
            verb: "post"
            to: [
              objectType: "person"
              id: "http://localhost:4815/api/user/louisck"
            ]
            object:
              id: "http://social.localhost/note/2"
              objectType: "note"
              content: "Hello from the service!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
          return
        ), callback
        return

      "it works": (err, act, resp) ->
        assert.ifError err
        assert.isObject act
        return

    "and we post to the inbox with OAuth credentials for an unrelated webfinger":
      topic: ->
        callback = @callback
        Step (->
          assoc "user0@social.localhost", "VALID2", Date.now(), this
          return
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user2@social.localhost"
              objectType: "person"

            id: "http://social.localhost/activity/4"
            verb: "post"
            object:
              id: "http://social.localhost/note/3"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
          return
        ), (err, body, res) ->
          if err and err.statusCode is 400
            callback null
          else if err
            callback err
          else
            callback new Error("Unexpected success")
          return

        return

      "and it fails correctly": (err) ->
        assert.ifError err
        return

    "and we post an activity to the inbox with OAuth credentials for the actor":
      topic: ->
        callback = @callback
        Step (->
          assoc "user3@social.localhost", "VALID1", Date.now(), this
          return
        ), ((err, cl) ->
          throw err  if err
          url = "http://localhost:4815/api/user/louisck/inbox"
          act =
            actor:
              id: "acct:user3@social.localhost"
              objectType: "person"

            to: [
              objectType: "collection"
              id: "http://social.localhost/user/user2/followers"
            ]
            id: "http://social.localhost/activity/5"
            verb: "post"
            object:
              id: "http://social.localhost/note/3"
              objectType: "note"
              content: "Hello again, world!"

          cred = clientCred(cl)
          httputil.postJSON url, cred, act, this
          return
        ), callback
        return

      "it works": (err, act, resp) ->
        assert.ifError err
        assert.isObject act
        return

      "and we check the user's inbox":
        topic: (act, resp, cred) ->
          callback = @callback
          url = "http://localhost:4815/api/user/louisck/inbox"
          httputil.getJSON url, cred, (err, feed, result) ->
            callback err, feed, act
            return

          return

        "it works": (err, feed, act) ->
          assert.ifError err
          assert.isObject feed
          return

        "it includes our posted activity": (err, feed, act) ->
          assert.ifError err
          assert.isObject feed
          assert.include feed, "items"
          assert.isArray feed.items
          assert.greater feed.items.length, 0
          assert.isTrue _.some(feed.items, (item) ->
            _.isObject(item) and item.id is act.id
          )
          return

    "and the user joins a remote group":
      topic: (cred) ->
        url = "http://localhost:4815/api/user/louisck/feed"
        callback = @callback
        act =
          verb: "join"
          object:
            id: "http://social.localhost/group/fathers"
            displayName: "Fathers"
            objectType: "group"

        httputil.postJSON url, cred, act, (err, body, resp) ->
          callback err, body
          return

        return

      "it works": (err, act) ->
        assert.ifError err
        validActivity act
        return

      "and we post an activity to the inbox with OAuth credentials for the host of the remote group":
        topic: ->
          callback = @callback
          Step (->
            assoc "social.localhost", "VALID2", Date.now(), this
            return
          ), ((err, cl) ->
            throw err  if err
            url = "http://localhost:4815/api/user/louisck/inbox"
            act =
              actor:
                id: "acct:user4@photo.localhost"
                objectType: "person"

              id: "http://social.localhost/activity/6"
              verb: "post"
              to: [
                objectType: "group"
                id: "http://social.localhost/group/fathers"
              ]
              object:
                id: "http://social.localhost/note/4"
                objectType: "note"
                content: "Hello via the group!"

            cred = clientCred(cl)
            httputil.postJSON url, cred, act, this
            return
          ), callback
          return

        "it works": (err, act, resp) ->
          assert.ifError err
          assert.isObject act
          return

suite["export"] module
