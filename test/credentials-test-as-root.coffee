# credentials-test-as-root.js
#
# Online test of the Credentials module
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
querystring = require("querystring")
_ = require("underscore")
fs = require("fs")
path = require("path")
express = require("express")
DialbackClient = require("dialback-client")
databank = require("databank")
Databank = databank.Databank
DatabankObject = databank.DatabankObject
Credentials = require("../lib/model/credentials").Credentials
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupAppConfig = oauthutil.setupAppConfig
suite = vows.describe("credentials module interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
tinyApp = (port, hostname, callback) ->
  app = express.createServer()
  app.configure ->
    app.set "port", port
    app.use express.bodyParser()
    app.use app.router
    return

  app.get "/.well-known/host-meta.json", (req, res) ->
    res.json links: [
      {
        rel: "lrdd"
        type: "application/json"
        template: "http://" + hostname + "/lrdd.json?uri={uri}"
      }
      {
        rel: "dialback"
        href: "http://" + hostname + "/api/dialback"
      }
    ]
    return

  app.get "/lrdd.json", (req, res) ->
    uri = req.query.uri
    parts = uri.split("@")
    username = parts[0]
    hostname = parts[1]
    res.json links: [
      rel: "dialback"
      href: "http://" + hostname + "/api/dialback"
    ]
    return

  app.on "error", (err) ->
    callback err, null
    return

  app.listen port, hostname, ->
    callback null, app
    return

  return

suite.addBatch "When we set up the app":
  topic: ->
    app = undefined
    callback = @callback
    db = Databank.get(tc.driver, tc.params)
    Step (->
      db.connect {}, this
      return
    ), ((err) ->
      throw err  if err
      DatabankObject.bank = db
      setupAppConfig
        port: 80
        hostname: "social.localhost"
        driver: "memory"
        params: {}
      , this
      return
    ), ((err, result) ->
      throw err  if err
      app = result
      tinyApp 80, "dialback.localhost", this
      return
    ), (err, dbapp) ->
      dialbackClient = undefined
      if err
        callback err, null, null
      else
        Credentials.dialbackClient = new DialbackClient(
          hostname: "dialback.localhost"
          bank: db
          app: dbapp
          url: "/api/dialback"
        )
        callback err, app, dbapp
      return

    return

  teardown: (app, dbapp) ->
    app.close()
    dbapp.close()
    return

  "it works": (err, app, dbapp) ->
    assert.ifError err
    return

  "and we try to get credentials for an invalid user":
    topic: ->
      callback = @callback
      Credentials.getFor "acct:user8@something.invalid", "http://social.localhost/api/user/frank/inbox", (err, cred) ->
        if err
          callback null
        else
          callback new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we try to get host credentials for a valid user":
    topic: ->
      callback = @callback
      Credentials.getForHostname "acct:user2@dialback.localhost", "social.localhost", callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "results include client_id and client_secret": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.include cred, "client_id"
      assert.include cred, "client_secret"
      return

  "and we try to get host credentials for a valid host":
    topic: ->
      callback = @callback
      Credentials.getForHostname "dialback.localhost", "social.localhost", callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "results include client_id and client_secret": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.include cred, "client_id"
      assert.include cred, "client_secret"
      return

  "and we try to get host credentials for a valid Host object":
    topic: ->
      callback = @callback
      Host = require("../lib/model/host").Host
      Step (->
        Host.ensureHost "social.localhost", this
        return
      ), ((err, host) ->
        throw err  if err
        Credentials.getForHost "acct:user3@dialback.localhost", host, this
        return
      ), callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "results include client_id and client_secret": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.include cred, "client_id"
      assert.include cred, "client_secret"
      return

  "and we try to get credentials for a valid user":
    topic: ->
      callback = @callback
      Credentials.getFor "acct:user1@dialback.localhost", "http://social.localhost/api/user/frank/inbox", callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "results include client_id and client_secret": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      assert.include cred, "client_id"
      assert.include cred, "client_secret"
      return

    "and we try to get credentials for the same user again":
      topic: (cred1) ->
        callback = @callback
        Credentials.getFor "acct:user1@dialback.localhost", "http://social.localhost/api/user/frank/inbox", (err, cred2) ->
          callback err, cred1, cred2
          return

        return

      "it works": (err, cred1, cred2) ->
        assert.ifError err
        assert.isObject cred2
        return

      "results include client_id and client_secret": (err, cred1, cred2) ->
        assert.ifError err
        assert.isObject cred2
        assert.include cred2, "client_id"
        assert.include cred2, "client_secret"
        return

      "results include same client_id and client_secret": (err, cred1, cred2) ->
        assert.ifError err
        assert.isObject cred2
        assert.equal cred2.client_id, cred1.client_id
        assert.equal cred2.client_secret, cred1.client_secret
        return

suite["export"] module
