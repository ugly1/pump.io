# urlmaker-test.js
#
# Test the urlmaker module
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
_ = require("underscore")
assert = require("assert")
vows = require("vows")
parseURL = require("url").parse
suite = vows.describe("urlmaker module interface")
suite.addBatch "When we require the urlmaker module":
  topic: ->
    require "../lib/urlmaker"

  "it exists": (urlmaker) ->
    assert.isObject urlmaker
    return

  "and we get the URLMaker singleton":
    topic: (urlmaker) ->
      urlmaker.URLMaker

    "it exists": (URLMaker) ->
      assert.isObject URLMaker
      return

    "it has a hostname property": (URLMaker) ->
      assert.include URLMaker, "hostname"
      return

    "it has a port property": (URLMaker) ->
      assert.include URLMaker, "port"
      return

    "it has a makeURL method": (URLMaker) ->
      assert.include URLMaker, "makeURL"
      assert.isFunction URLMaker.makeURL
      return

suite.addBatch "When we set up the URLMaker":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

  "and we make an URL":
    topic: (URLMaker) ->
      URLMaker.makeURL "login"

    "it exists": (url) ->
      assert.isString url
      return

    "its parts are correct": (url) ->
      parts = parseURL(url)
      assert.equal parts.hostname, "example.com"
      assert.equal parts.port, 3001
      assert.equal parts.host, "example.com:3001"
      assert.equal parts.path, "/login"
      return

suite.addBatch "When we set up the URLMaker with the default port":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 80
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

  "and we set its properties to default port":
    topic: (URLMaker) ->
      URLMaker.makeURL "login"

    "it exists": (url) ->
      assert.isString url
      return

    "its parts are correct": (url) ->
      parts = parseURL(url)
      assert.equal parts.hostname, "example.com"
      
      # undefined in 0.8.x, null in 0.10.x
      assert.isTrue _.isNull(parts.port) or _.isUndefined(parts.port)
      assert.equal parts.host, "example.com" # NOT example.com:80
      assert.equal parts.path, "/login"
      return

suite.addBatch "When we set up the URLMaker":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 2342
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

  "and we include parameters":
    topic: (URLMaker) ->
      URLMaker.makeURL "/users",
        offset: 10
        count: 30


    "it exists": (url) ->
      assert.isString url
      return

    "its parts are correct": (url) ->
      
      # parse query params too
      parts = parseURL(url, true)
      assert.equal parts.hostname, "example.com"
      assert.equal parts.port, 2342
      assert.equal parts.host, "example.com:2342"
      assert.equal parts.pathname, "/users"
      assert.isObject parts.query
      assert.include parts.query, "offset"
      assert.equal parts.query.offset, 10
      assert.include parts.query, "count"
      assert.equal parts.query.count, 30
      return

suite.addBatch "When we set up the URLMaker with a prefix path":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker.path = "pumpio"
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

  "and we make an URL":
    topic: (URLMaker) ->
      URLMaker.makeURL "login"

    "it exists": (url) ->
      assert.isString url
      return

    "its parts are correct": (url) ->
      parts = parseURL(url)
      assert.equal parts.hostname, "example.com"
      assert.equal parts.port, 3001
      assert.equal parts.host, "example.com:3001"
      assert.equal parts.path, "/pumpio/login"
      return

suite.addBatch "When we set up the URLMaker":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

  "and we make URLs with and without initial slash":
    topic: (URLMaker) ->
      without: URLMaker.makeURL("login")
      with: URLMaker.makeURL("/login")

    "they are equal": (urls) ->
      assert.equal urls["with"], urls.without
      return

suite.addBatch "When we set up the URLMaker with a prefix path":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker.path = "pumpio"
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

  "and we make URLs with and without initial slash":
    topic: (URLMaker) ->
      without: URLMaker.makeURL("login")
      with: URLMaker.makeURL("/login")

    "they are equal": (urls) ->
      assert.equal urls["with"], urls.without
      return

suite.addBatch "When we set up URLMaker":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  "and we have a slash before the path":
    topic: (URLMaker) ->
      URLMaker.path = "/pumpio"
      URLMaker.makeURL "/login"

    "it works": (url) ->
      assert.equal parseURL(url).path, "/pumpio/login"
      return

  "and we have a slash after the path":
    topic: (URLMaker) ->
      URLMaker.path = "pumpio/"
      URLMaker.makeURL "/login"

    "it works": (url) ->
      assert.equal parseURL(url).path, "/pumpio/login"
      return

  "and we have a slash on both sides of the path":
    topic: (URLMaker) ->
      URLMaker.path = "/pumpio/"
      URLMaker.makeURL "/login"

    "it works": (url) ->
      assert.equal parseURL(url).path, "/pumpio/login"
      return

  "and we have no slashes in the path":
    topic: (URLMaker) ->
      URLMaker.path = "pumpio"
      URLMaker.makeURL "/login"

    "it works": (url) ->
      assert.equal parseURL(url).path, "/pumpio/login"
      return

  teardown: (URLMaker) ->
    URLMaker.hostname = null
    URLMaker.port = null
    URLMaker.path = null
    return

suite.addBatch "When we set up URLMaker":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  "and we make a default host":
    topic: (URLMaker) ->
      URLMaker.makeHost()

    "it works": (host) ->
      assert.equal host, "example.com:3001"
      return

  "and we make a host with the default port":
    topic: (URLMaker) ->
      URLMaker.makeHost "example.net", 80

    "it works": (host) ->
      assert.equal host, "example.net"
      return

  "and we make a host with the default SSL port":
    topic: (URLMaker) ->
      URLMaker.makeHost "example.net", 443

    "it works": (host) ->
      assert.equal host, "example.net"
      return

  "and we make a host with a non-default port":
    topic: (URLMaker) ->
      URLMaker.makeHost "example.net", 8080

    "it works": (host) ->
      assert.equal host, "example.net:8080"
      return

suite.addBatch "When we set up URLMaker":
  topic: ->
    URLMaker = require("../lib/urlmaker").URLMaker
    URLMaker.hostname = "example.com"
    URLMaker.port = 3001
    URLMaker

  "it works": (URLMaker) ->
    assert.isObject URLMaker
    return

  "and we make a path":
    topic: (URLMaker) ->
      URLMaker.path = null
      URLMaker.makePath "login"

    "it works": (path) ->
      assert.equal path, "/login"
      return

  "and we make a path with a prefix":
    topic: (URLMaker) ->
      URLMaker.path = "pumpio"
      URLMaker.makePath "login"

    "it works": (path) ->
      assert.equal path, "/pumpio/login"
      return

suite["export"] module
