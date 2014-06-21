# host-test-as-root.js
#
# Online test of the Host module
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
Browser = require("zombie")
URLMaker = require("../lib/urlmaker").URLMaker
DialbackClient = require("dialback-client")
databank = require("databank")
Databank = databank.Databank
DatabankObject = databank.DatabankObject
Host = require("../lib/model/host").Host
Credentials = require("../lib/model/credentials").Credentials
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupAppConfig = oauthutil.setupAppConfig
register = oauthutil.register
authorize = oauthutil.authorize
suite = vows.describe("host module interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
tinyApp = (port, hostname, callback) ->
  app = express.createServer()
  authcb = null
  app.configure ->
    app.set "port", port
    app.use express.bodyParser()
    app.use express.query()
    app.use app.router
    return

  app.setAuthCB = (cb) ->
    authcb = cb
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

  app.get "/main/authorized/:hostname", (req, res) ->
    if authcb
      authcb null, req.query.oauth_verifier
      authcb = null
    res.send "OK"
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
        URLMaker.hostname = "dialback.localhost"
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

  "and we ensure an invalid host":
    topic: ->
      callback = @callback
      Host.ensureHost "other.invalid", (err, cred) ->
        if err
          callback null
        else
          callback new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we ensure a valid host":
    topic: ->
      callback = @callback
      Host.ensureHost "social.localhost", callback
      return

    "it works": (err, host) ->
      assert.ifError err
      assert.isObject host
      return

    "and we check its properties": (err, host) ->
      assert.ifError err
      assert.isObject host
      assert.isString host.hostname
      assert.isString host.registration_endpoint
      assert.isString host.request_token_endpoint
      assert.isString host.access_token_endpoint
      assert.isString host.authorization_endpoint
      assert.isString host.whoami_endpoint
      assert.isNumber host.created
      assert.isNumber host.modified
      return

    "and we ensure the same host again":
      topic: (host) ->
        callback = @callback
        Host.ensureHost host.hostname, (err, dupe) ->
          callback err, dupe, host
          return

        return

      "it works": (err, dupe, host) ->
        assert.ifError err
        assert.isObject dupe
        assert.isObject host
        return

      "and we check its properties": (err, dupe, host) ->
        assert.ifError err
        assert.isObject host
        assert.isObject dupe
        assert.deepEqual dupe, host
        return

    "and we get a request token":
      topic: (host) ->
        host.getRequestToken @callback
        return

      "it works": (err, rt) ->
        assert.ifError err
        assert.isObject rt
        return

      "and we get the authorization url":
        topic: (rt, host) ->
          host.authorizeURL rt

        "it works": (url) ->
          assert.isString url
          return

      "and we authorize the request token":
        topic: (rt, host, app, dbapp) ->
          callback = @callback
          browser = new Browser(
            runScripts: false
            waitFor: 60000
          )
          cl = undefined
          Step (->
            Credentials.getForHost "social.localhost", host, this
            return
          ), ((err, results) ->
            throw err  if err
            cl = results
            register cl, "seth", "Aegh0eex", "social.localhost", 80, this
            return
          ), ((err, user) ->
            throw err  if err
            browser.visit host.authorizeURL(rt), this
            return
          ), ((err) ->
            throw err  if err
            throw new Error("Browser fail")  unless browser.success
            browser.fill "username", "seth", this
            return
          ), ((err) ->
            throw err  if err
            throw new Error("Browser fail")  unless browser.success
            browser.fill "password", "Aegh0eex", this
            return
          ), ((err) ->
            throw err  if err
            throw new Error("Browser fail")  unless browser.success
            browser.pressButton "#authenticate", this
            return
          ), ((err) ->
            throw err  if err
            throw new Error("Browser fail")  unless browser.success
            dbapp.setAuthCB @parallel()
            browser.pressButton "Authorize", @parallel()
            return
          ), (err, verifier, br) ->
            callback err, verifier
            return

          return

        "it works": (err, verifier) ->
          assert.ifError err
          assert.isString verifier
          return

        "and we get the access token":
          topic: (verifier, rt, host) ->
            host.getAccessToken rt, verifier, @callback
            return

          "it works": (err, pair) ->
            assert.ifError err
            assert.isObject pair
            assert.isString pair.token
            assert.isString pair.secret
            return

suite["export"] module
