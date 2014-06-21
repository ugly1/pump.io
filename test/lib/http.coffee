# http.js
#
# HTTP utilities for testing
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
http = require("http")
https = require("https")
assert = require("assert")
querystring = require("querystring")
_ = require("underscore")
Step = require("step")
fs = require("fs")
express = require("express")
util = require("util")
version = require("../../lib/version").version
OAuth = require("oauth-evanp").OAuth
urlparse = require("url").parse
OAuthJSONError = (obj) ->
  Error.captureStackTrace this, OAuthJSONError
  @name = "OAuthJSONError"
  _.extend this, obj
  return

OAuthJSONError:: = new Error()
OAuthJSONError::constructor = OAuthJSONError
OAuthJSONError::toString = ->
  "OAuthJSONError (" + @statusCode + "): " + @data

newOAuth = (serverURL, cred) ->
  oa = undefined
  parts = undefined
  parts = urlparse(serverURL)
  oa = new OAuth("http://" + parts.host + "/oauth/request_token", "http://" + parts.host + "/oauth/access_token", cred.consumer_key, cred.consumer_secret, "1.0", null, "HMAC-SHA1", null, # nonce size; use default
    "User-Agent": "pump.io/" + version
  )
  oa

endpoint = (url, hostname, port, methods) ->
  unless port
    methods = hostname
    hostname = "localhost"
    port = 4815
  else unless methods
    methods = port
    port = 80
  context =
    topic: ->
      options hostname, port, url, @callback
      return

    "it exists": (err, allow, res, body) ->
      assert.ifError err
      assert.equal res.statusCode, 200
      return

  checkMethod = (method) ->
    (err, allow, res, body) ->
      assert.include allow, method
      return

  i = undefined
  i = 0
  while i < methods.length
    context["it supports " + methods[i]] = checkMethod(methods[i])
    i++
  context

options = (host, port, path, callback) ->
  reqOpts =
    host: host
    port: port
    path: path
    method: "OPTIONS"
    headers:
      "User-Agent": "pump.io/" + version

  mod = (if (port is 443) then https else http)
  req = mod.request(reqOpts, (res) ->
    body = ""
    res.setEncoding "utf8"
    res.on "data", (chunk) ->
      body = body + chunk
      return

    res.on "error", (err) ->
      callback err, null, null, null
      return

    res.on "end", ->
      allow = []
      if _(res.headers).has("allow")
        allow = res.headers.allow.split(",").map((s) ->
          s.trim()
        )
      callback null, allow, res, body
      return

    return
  )
  req.on "error", (err) ->
    callback err, null, null, null
    return

  req.end()
  return

post = (host, port, path, params, callback) ->
  requestBody = querystring.stringify(params)
  reqOpts =
    hostname: host
    port: port
    path: path
    method: "POST"
    headers:
      "Content-Type": "application/x-www-form-urlencoded"
      "Content-Length": requestBody.length
      "User-Agent": "pump.io/" + version

  mod = (if (port is 443) then https else http)
  req = mod.request(reqOpts, (res) ->
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

head = (url, callback) ->
  options = urlparse(url)
  options.method = "HEAD"
  options.headers = "User-Agent": "pump.io/" + version
  mod = (if (options.protocol is "https:") then https else http)
  req = mod.request(options, (res) ->
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

  req.end()
  return

jsonHandler = (callback) ->
  (err, data, response) ->
    obj = undefined
    if err
      callback new OAuthJSONError(err), null, null
    else
      try
        obj = JSON.parse(data)
        callback null, obj, response
      catch e
        callback e, null, null
    return

postJSON = (serverUrl, cred, payload, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  toSend = JSON.stringify(payload)
  oa.post serverUrl, cred.token, cred.token_secret, toSend, "application/json", jsonHandler(callback)
  return

postFile = (serverUrl, cred, fileName, mimeType, callback) ->
  Step (->
    fs.readFile fileName, this
    return
  ), ((err, data) ->
    oa = undefined
    if err
      callback err, null, null
    else
      oa = newOAuth(serverUrl, cred)
      oa.post serverUrl, cred.token, cred.token_secret, data, mimeType, this
    return
  ), jsonHandler(callback)
  return

putJSON = (serverUrl, cred, payload, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  toSend = JSON.stringify(payload)
  oa.put serverUrl, cred.token, cred.token_secret, toSend, "application/json", jsonHandler(callback)
  return

getJSON = (serverUrl, cred, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  oa.get serverUrl, cred.token, cred.token_secret, jsonHandler(callback)
  return

delJSON = (serverUrl, cred, callback) ->
  oa = undefined
  toSend = undefined
  oa = newOAuth(serverUrl, cred)
  oa["delete"] serverUrl, cred.token, cred.token_secret, jsonHandler(callback)
  return

getfail = (rel, status) ->
  status = 400  unless status
  topic: ->
    callback = @callback
    req = undefined
    timeout = setTimeout(->
      req.abort()  if req
      callback new Error("Timeout getting " + rel)
      return
    , 10000)
    req = http.get("http://localhost:4815" + rel, (res) ->
      clearTimeout timeout
      if res.statusCode isnt status
        callback new Error("Bad status code: " + res.statusCode)
      else
        callback null
      return
    )
    return

  "it fails with the correct error code": (err) ->
    assert.ifError err
    return

dialbackPost = (endpoint, id, token, ts, requestBody, contentType, callback) ->
  reqOpts = urlparse(endpoint)
  auth = undefined
  reqOpts.method = "POST"
  reqOpts.headers =
    "Content-Type": contentType
    "Content-Length": requestBody.length
    "User-Agent": "pump.io/" + version

  if id.indexOf("@") is -1
    auth = "Dialback host=\"" + id + "\", token=\"" + token + "\""
  else
    auth = "Dialback webfinger=\"" + id + "\", token=\"" + token + "\""
  mod = (if (reqOpts.protocol is "https:") then https else http)
  reqOpts.headers["Authorization"] = auth
  reqOpts.headers["Date"] = (new Date(ts)).toUTCString()
  req = mod.request(reqOpts, (res) ->
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

proxy = (options, callback) ->
  server = express.createServer()
  front = _.defaults(options.front or {},
    hostname: "localhost"
    port: 2342
    path: "/pumpio"
  )
  back = _.defaults(options.back or {},
    hostname: "localhost"
    port: 4815
    path: ""
  )
  server.all front.path + "/*", (req, res, next) ->
    full = req.originalUrl
    rel = full.substr(front.path.length + 1)
    options =
      hostname: back.hostname
      port: back.port
      method: req.route.method.toUpperCase()
      path: back.path + "/" + rel
      headers: _.extend(req.headers,
        Via: "pump.io-test-proxy/0.1.0"
      )

    breq = http.request(options, (bres) ->
      res.status bres.statusCode
      _.each bres.headers, (value, name) ->
        res.header name, value
        return

      util.pump bres, res
      return
    )
    breq.on "error", (err) ->
      next err
      return

    util.pump req, breq
    return

  
  # XXX: need to call callback on an error
  server.listen front.port, front.hostname, ->
    callback null, server
    return

  return

exports.options = options
exports.post = post
exports.head = head
exports.postJSON = postJSON
exports.postFile = postFile
exports.getJSON = getJSON
exports.putJSON = putJSON
exports.delJSON = delJSON
exports.endpoint = endpoint
exports.getfail = getfail
exports.dialbackPost = dialbackPost
exports.newOAuth = newOAuth
exports.proxy = proxy
