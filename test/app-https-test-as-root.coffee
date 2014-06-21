# app-https-test-as-root.js
#
# Test running the app over HTTPS
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
fs = require("fs")
path = require("path")
databank = require("databank")
Step = require("step")
http = require("http")
https = require("https")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
xrdutil = require("./lib/xrd")
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0"
suite = vows.describe("smoke test app interface over https")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
clientCred = (cl) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret

makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret

httpsURL = (url) ->
  parts = urlparse(url)
  parts.protocol is "https:"


# hostmeta links
hostmeta = links: [
  {
    rel: "lrdd"
    type: "application/xrd+xml"
    template: /{uri}/
  }
  {
    rel: "lrdd"
    type: "application/json"
    template: /{uri}/
  }
  {
    rel: "registration_endpoint"
    href: "https://secure.localhost/api/client/register"
  }
  {
    rel: "http://apinamespace.org/oauth/request_token"
    href: "https://secure.localhost/oauth/request_token"
  }
  {
    rel: "http://apinamespace.org/oauth/authorize"
    href: "https://secure.localhost/oauth/authorize"
  }
  {
    rel: "http://apinamespace.org/oauth/access_token"
    href: "https://secure.localhost/oauth/access_token"
  }
  {
    rel: "dialback"
    href: "https://secure.localhost/api/dialback"
  }
  {
    rel: "http://apinamespace.org/activitypub/whoami"
    href: "https://secure.localhost/api/whoami"
  }
]
webfinger = links: [
  {
    rel: "http://webfinger.net/rel/profile-page"
    type: "text/html"
    href: "https://secure.localhost/caterpillar"
  }
  {
    rel: "dialback"
    href: "https://secure.localhost/api/dialback"
  }
  {
    rel: "self"
    href: "https://secure.localhost/api/user/caterpillar/profile"
  }
  {
    rel: "activity-inbox"
    href: "https://secure.localhost/api/user/caterpillar/inbox"
  }
  {
    rel: "activity-outbox"
    href: "https://secure.localhost/api/user/caterpillar/feed"
  }
  {
    rel: "followers"
    href: "https://secure.localhost/api/user/caterpillar/followers"
  }
  {
    rel: "following"
    href: "https://secure.localhost/api/user/caterpillar/following"
  }
  {
    rel: "favorites"
    href: "https://secure.localhost/api/user/caterpillar/favorites"
  }
  {
    rel: "lists"
    href: "https://secure.localhost/api/user/caterpillar/lists/person"
  }
]
suite.addBatch "When we makeApp()":
  topic: ->
    config =
      port: 443
      hostname: "secure.localhost"
      key: path.join(__dirname, "data", "secure.localhost.key")
      cert: path.join(__dirname, "data", "secure.localhost.crt")
      driver: tc.driver
      params: tc.params
      nologger: true
      sockjs: false

    makeApp = require("../lib/app").makeApp
    process.env.NODE_ENV = "test"
    makeApp config, @callback
    return

  "it works": (err, app) ->
    assert.ifError err
    assert.isObject app
    return

  "and we app.run()":
    topic: (app) ->
      cb = @callback
      app.run (err) ->
        if err
          cb err, null
        else
          cb null, app
        return

      return

    teardown: (app) ->
      app.close()  if app and app.close
      return

    "it works": (err, app) ->
      assert.ifError err
      return

    "app is listening on correct port": (err, app) ->
      addr = app.address()
      assert.equal addr.port, 443
      return

    "and we GET the host-meta file": xrdutil.xrdContext("https://secure.localhost/.well-known/host-meta", hostmeta)
    "and we GET the host-meta.json file": xrdutil.jrdContext("https://secure.localhost/.well-known/host-meta.json", hostmeta)
    "and we register a new client":
      topic: ->
        oauthutil.newClient "secure.localhost", 443, @callback
        return

      "it works": (err, cred) ->
        assert.ifError err
        assert.isObject cred
        assert.include cred, "client_id"
        assert.include cred, "client_secret"
        assert.include cred, "expires_at"
        return

      "and we register a new user":
        topic: (cl) ->
          oauthutil.register cl, "caterpillar", "mush+room", "secure.localhost", 443, @callback
          return

        "it works": (err, user) ->
          assert.ifError err
          assert.isObject user
          return

        "and we test the lrdd endpoint": xrdutil.xrdContext("https://secure.localhost/api/lrdd?resource=caterpillar@secure.localhost", webfinger)
        "and we test the webfinger endpoint": xrdutil.jrdContext("https://secure.localhost/.well-known/webfinger?resource=caterpillar@secure.localhost", webfinger)
        "and we get the user":
          topic: (user, cl) ->
            url = "https://secure.localhost/api/user/caterpillar"
            httputil.getJSON url, clientCred(cl), @callback
            return

          "it works": (err, body, resp) ->
            assert.ifError err
            assert.isObject body
            return

          "the links look correct": (err, body, resp) ->
            assert.ifError err
            assert.isObject body
            assert.isObject body.profile
            assert.equal body.profile.id, "acct:caterpillar@secure.localhost"
            assert.equal body.profile.url, "https://secure.localhost/caterpillar"
            assert.isTrue httpsURL(body.profile.links.self.href)
            assert.isTrue httpsURL(body.profile.links["activity-inbox"].href)
            assert.isTrue httpsURL(body.profile.links["activity-outbox"].href)
            assert.isTrue httpsURL(body.profile.followers.url)
            assert.isTrue httpsURL(body.profile.following.url)
            assert.isTrue httpsURL(body.profile.lists.url)
            assert.isTrue httpsURL(body.profile.favorites.url)
            return

        "and we get a new request token":
          topic: (user, cl) ->
            oauthutil.requestToken cl, "secure.localhost", 443, @callback
            return

          "it works": (err, rt) ->
            assert.ifError err
            assert.isObject rt
            return

          "and we authorize the request token":
            topic: (rt, user, cl) ->
              oauthutil.authorize cl, rt,
                nickname: "caterpillar"
                password: "mush+room"
              , "secure.localhost", 443, @callback
              return

            "it works": (err, verifier) ->
              assert.ifError err
              assert.isString verifier
              return

            "and we get an access token":
              topic: (verifier, rt, user, cl) ->
                oauthutil.redeemToken cl, rt, verifier, "secure.localhost", 443, @callback
                return

              "it works": (err, pair) ->
                assert.ifError err
                assert.isObject pair
                return

              "and the user posts a note":
                topic: (pair, verifier, rt, user, cl) ->
                  url = "https://secure.localhost/api/user/caterpillar/feed"
                  act =
                    verb: "post"
                    object:
                      objectType: "note"
                      content: "Who are you?"

                  httputil.postJSON url, makeCred(cl, pair), act, @callback
                  return

                "it works": (err, act) ->
                  assert.ifError err
                  assert.isObject act
                  return

                "URLs look correct": (err, act) ->
                  assert.ifError err
                  assert.isObject act
                  assert.isTrue httpsURL(act.url)
                  assert.isTrue httpsURL(act.object.links.self.href)
                  assert.isTrue httpsURL(act.object.likes.url)
                  assert.isTrue httpsURL(act.object.replies.url)
                  assert.isTrue httpsURL(act.actor.links.self.href)
                  assert.isTrue httpsURL(act.actor.links["activity-inbox"].href)
                  assert.isTrue httpsURL(act.actor.links["activity-outbox"].href)
                  return

suite["export"] module
