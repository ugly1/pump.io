# oauth-test.js
#
# Test the client registration API
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
_ = require("underscore")
querystring = require("querystring")
http = require("http")
fs = require("fs")
path = require("path")
OAuth = require("oauth-evanp").OAuth
Browser = require("zombie")
version = require("../lib/version").version
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
setupApp = oauthutil.setupApp
setupAppConfig = oauthutil.setupAppConfig
requestToken = oauthutil.requestToken
newClient = oauthutil.newClient
register = oauthutil.register
accessToken = oauthutil.accessToken
ignore = (err) ->

tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite = vows.describe("OAuth authorization")
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback
    return

  teardown: (app) ->
    app.close()  if app
    return

  "it works": (err, app) ->
    assert.ifError err
    return

  "and we try to get the authorization form without a request token":
    topic: ->
      cb = @callback
      options =
        host: "localhost"
        port: 4815
        path: "/oauth/authorize"

      http.get(options, (res) ->
        if res.statusCode >= 400 and res.statusCode < 500
          cb null
        else
          cb new Error("Unexpected status code")
        return
      ).on "error", (err) ->
        cb err
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we try to get the authorization form with an invalid request token":
    topic: ->
      cb = @callback
      options =
        host: "localhost"
        port: 4815
        path: "/oauth/authorize?oauth_token=NOTAREQUESTTOKEN"

      http.get(options, (res) ->
        if res.statusCode >= 400 and res.statusCode < 500
          cb null
        else
          cb new Error("Unexpected status code")
        return
      ).on "error", (err) ->
        cb err
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we try to get an access token without any OAuth credentials":
    topic: ->
      cb = @callback
      httputil.post "localhost", 4815, "/oauth/access_token", {}, (err, res, body) ->
        if err
          cb err
        else if res.statusCode is 400
          cb null
        else
          cb new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we try to get an access token with an invalid client key":
    topic: ->
      cb = @callback
      oa = undefined
      oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", "NOTACLIENT", "NOTASECRET", "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
        "User-Agent": "pump.io/" + version
      )
      oa.getOAuthAccessToken "NOTATOKEN", "NOTATOKENSECRET", "NOTAVERIFIER", (err, token, secret) ->
        if err
          cb null
        else
          cb new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we try to get an access token with an valid client key and invalid client secret":
    topic: ->
      cb = @callback
      Step (->
        newClient this
        return
      ), (err, cl) ->
        throw err  if err
        oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", cl.client_id, "NOTASECRET", "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
          "User-Agent": "pump.io/" + version
        )
        oa.getOAuthAccessToken "NOTATOKEN", "NOTATOKENSECRET", "NOTAVERIFIER", (err, token, secret) ->
          if err
            cb null, cl
          else
            cb new Error("Unexpected success"), null
          return

        return

      return

    "it fails correctly": (err, cl) ->
      assert.ifError err
      return

    teardown: (cl) ->
      cl.del ignore  if cl and cl.del
      return

  "and we try to get an access token with an valid client key and valid client secret and invalid request token":
    topic: ->
      cb = @callback
      Step (->
        newClient this
        return
      ), (err, cl) ->
        throw err  if err
        oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
          "User-Agent": "pump.io/" + version
        )
        oa.getOAuthAccessToken "NOTATOKEN", "NOTATOKENSECRET", "NOTAVERIFIER", (err, token, secret) ->
          if err
            cb null, cl
          else
            cb new Error("Unexpected success"), null
          return

        return

      return

    "it fails correctly": (err, cl) ->
      assert.ifError err
      return

    teardown: (cl) ->
      cl.del ignore  if cl and cl.del
      return

  "and we try to get an access token with an valid client key and valid client secret and valid request token and invalid request token secret":
    topic: ->
      cb = @callback
      cl = undefined
      Step (->
        newClient this
        return
      ), ((err, client) ->
        throw err  if err
        cl = client
        requestToken cl, this
        return
      ), (err, rt) ->
        oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
          "User-Agent": "pump.io/" + version
        )
        oa.getOAuthAccessToken rt.token, "NOTATOKENSECRET", "NOTAVERIFIER", (err, token, secret) ->
          if err
            cb null,
              cl: cl
              rt: rt

          else
            cb new Error("Unexpected success"), null
          return

        return

      return

    "it fails correctly": (err, res) ->
      assert.ifError err
      return

    teardown: (res) ->
      res.cl.del ignore  if res.cl and res.cl.del
      res.rt.del ignore  if res.rt and res.rt.del
      return

  "and we try to get an access token with an valid client key and valid client secret and valid request token and valid request token secret and invalid verifier":
    topic: ->
      cb = @callback
      cl = undefined
      Step (->
        newClient this
        return
      ), ((err, client) ->
        throw err  if err
        cl = client
        requestToken cl, this
        return
      ), (err, rt) ->
        oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
          "User-Agent": "pump.io/" + version
        )
        oa.getOAuthAccessToken rt.token, rt.token_secret, "NOTAVERIFIER", (err, token, secret) ->
          if err
            cb null,
              cl: cl
              rt: rt

          else
            cb new Error("Unexpected success"), null
          return

        return

      return

    "it fails correctly": (err, res) ->
      assert.ifError err
      return

    teardown: (res) ->
      res.cl.del ignore  if res.cl and res.cl.del
      res.rt.del ignore  if res.rt and res.rt.del
      return

  "and we submit the authentication form with the wrong password":
    topic: ->
      callback = @callback
      cl = undefined
      br = undefined
      Step (->
        newClient this
        return
      ), ((err, results) ->
        throw err  if err
        cl = results
        httputil.postJSON "http://localhost:4815/api/users",
          consumer_key: cl.client_id
          consumer_secret: cl.client_secret
        ,
          nickname: "dormouse"
          password: "feed*ur*head"
        , this
        return
      ), ((err, user) ->
        throw err  if err
        requestToken cl, this
        return
      ), ((err, rt) ->
        throw err  if err
        br = new Browser(runScripts: false)
        br.visit "http://localhost:4815/oauth/authorize?oauth_token=" + rt.token, this
        return
      ), ((err, br) ->
        throw err  if err
        throw new Error("Browser error")  unless br.success
        br.fill "username", "dormouse", this
        return
      ), ((err) ->
        throw err  if err
        br.fill "password", "BADPASSWORD", this
        return
      ), ((err) ->
        throw err  if err
        br.pressButton "#authenticate", this
        return
      ), (err) ->
        if err and br.statusCode >= 400 and br.statusCode < 500
          callback null
        else if err
          callback err
        else
          callback new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we submit the authentication form with a non-existent user":
    topic: ->
      callback = @callback
      cl = undefined
      br = undefined
      Step (->
        newClient this
        return
      ), ((err, results) ->
        throw err  if err
        cl = results
        requestToken cl, this
        return
      ), ((err, rt) ->
        throw err  if err
        br = new Browser(runScripts: false)
        br.visit "http://localhost:4815/oauth/authorize?oauth_token=" + rt.token, this
        return
      ), ((err, br) ->
        throw err  if err
        throw new Error("Browser error")  unless br.success
        br.fill "username", "nonexistent", this
        return
      ), ((err) ->
        throw err  if err
        br.fill "password", "DOESNTMATTER", this
        return
      ), ((err) ->
        throw err  if err
        br.pressButton "#authenticate", this
        return
      ), (err) ->
        if err and br.statusCode >= 400 and br.statusCode < 500
          callback null
        else if err
          callback err
        else
          callback new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we create a client using the api":
    topic: ->
      newClient @callback
      return

    "it works": (err, cl) ->
      assert.ifError err
      assert.isObject cl
      assert.isString cl.client_id
      assert.isString cl.client_secret
      return

    "and we create a user using the API":
      topic: (cl) ->
        cb = @callback
        Step (->
          newClient this
          return
        ), ((err, other) ->
          throw err  if err
          httputil.postJSON "http://localhost:4815/api/users",
            consumer_key: other.client_id
            consumer_secret: other.client_secret
          ,
            nickname: "alice"
            password: "white*rabbit"
          , this
          return
        ), (err, user, resp) ->
          cb err, user
          return

        return

      "it works": (err, user) ->
        assert.ifError err
        assert.isObject user
        return

      "and we request a request token with valid client_id and client_secret":
        topic: (user, cl) ->
          requestToken cl, @callback
          return

        "it works": (err, cred) ->
          assert.ifError err
          assert.isObject cred
          return

        "it has the right results": (err, cred) ->
          assert.include cred, "token"
          assert.isString cred.token
          assert.include cred, "token_secret"
          assert.isString cred.token_secret
          return

        "and we get the authentication form":
          topic: (rt) ->
            cb = @callback
            Browser.runScripts = false
            Browser.visit "http://localhost:4815/oauth/authorize?oauth_token=" + rt.token, cb
            return

          "it works": (err, browser) ->
            assert.ifError err
            assert.ok browser.success
            return

          "it contains the login form": (err, browser) ->
            assert.ok browser.query("form#oauth-authentication")
            return

          "and we submit the authentication form":
            topic: (browser) ->
              cb = @callback
              browser.fill "username", "alice", (err) ->
                if err
                  cb err
                else
                  browser.fill "password", "white*rabbit", (err) ->
                    if err
                      cb err
                    else
                      browser.pressButton "#authenticate", (err) ->
                        cb err, browser
                        return

                    return

                return

              return

            "it works": (err, browser) ->
              assert.ifError err
              assert.ok browser.success
              return

            "it has the right location": (err, browser) ->
              assert.equal browser.location.pathname, "/oauth/authorize"
              return

            "it contains the authorization form": (err, browser) ->
              assert.ok browser.query("form#authorize")
              return

            "and we submit the authorization form":
              topic: (browser) ->
                cb = @callback
                browser.pressButton "Authorize", (err) ->
                  if err
                    cb err, null
                  else unless browser.success
                    cb new Error("Browser not successful"), null
                  else
                    cb null,
                      token: browser.text("#token")
                      verifier: browser.text("#verifier")

                  return

                return

              "it works": (err, results) ->
                assert.ifError err
                return

              "results include token and verifier": (err, results) ->
                assert.isString results.token
                assert.isString results.verifier
                return

              "and we try to get an access token":
                topic: (pair) ->
                  cb = @callback
                  oa = undefined
                  rt = arguments_[5]
                  cl = arguments_[7]
                  oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
                    "User-Agent": "pump.io/" + version
                  )
                  oa.getOAuthAccessToken pair.token, rt.token_secret, pair.verifier, (err, token, secret) ->
                    if err
                      cb new Error(err.data), null
                    else
                      cb null,
                        token: token
                        token_secret: secret

                    return

                  return

                "it works": (err, pair) ->
                  assert.ifError err
                  return

                "results are correct": (err, pair) ->
                  assert.isObject pair
                  assert.include pair, "token"
                  assert.isString pair.token
                  assert.include pair, "token_secret"
                  assert.isString pair.token_secret
                  return

                "and we try to get another access token with the same data":
                  topic: ->
                    cb = @callback
                    oa = undefined
                    pair = arguments_[1]
                    rt = arguments_[6]
                    cl = arguments_[8]
                    oa = new OAuth("http://localhost:4815/oauth/request_token", "http://localhost:4815/oauth/access_token", cl.client_id, cl.client_secret, "1.0", "oob", "HMAC-SHA1", null, # nonce size; use default
                      "User-Agent": "pump.io/" + version
                    )
                    oa.getOAuthAccessToken pair.token, rt.token_secret, pair.verifier, (err, token, secret) ->
                      if err
                        cb null
                      else
                        cb new Error("Unexpected success")
                      return

                    return

                  "it fails correctly": (err) ->
                    assert.ifError err
                    return

suite["export"] module
