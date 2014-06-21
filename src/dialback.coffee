# dialback.js
#
# Copyright 2011-2012, E14N https://e14n.com/
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
Step = require("step")
wf = require("webfinger")
http = require("http")
https = require("https")
url = require("url")
URLMaker = require("./urlmaker").URLMaker
querystring = require("querystring")
path = require("path")
DialbackRequest = require("dialback-client").DialbackRequest
discoverHostEndpoint = (host, callback) ->
  Step (->
    wf.hostmeta host, this
    return
  ), (err, jrd) ->
    dialbacks = undefined
    if err
      callback err, null
      return
    unless jrd.hasOwnProperty("links")
      callback new Error("No links in host-meta for " + host), null
      return
    dialbacks = jrd.links.filter((link) ->
      link.hasOwnProperty("rel") and link.rel is "dialback" and link.hasOwnProperty("href")
    )
    if dialbacks.length is 0
      callback new Error("No dialback links in host-meta for " + host), null
      return
    callback null, dialbacks[0].href
    return

  return

discoverWebfingerEndpoint = (address, callback) ->
  Step (->
    wf.webfinger address, this
    return
  ), (err, jrd) ->
    dialbacks = undefined
    if err
      callback err, null
      return
    unless jrd.hasOwnProperty("links")
      callback new Error("No links in lrdd for " + address), null
      return
    dialbacks = jrd.links.filter((link) ->
      link.hasOwnProperty("rel") and link.rel is "dialback"
    )
    if dialbacks.length is 0
      callback new Error("No dialback links in lrdd for " + address), null
      return
    callback null, dialbacks[0].href
    return

  return

discoverEndpoint = (fields, callback) ->
  if fields.hasOwnProperty("host")
    discoverHostEndpoint fields.host, callback
  else discoverWebfingerEndpoint fields.webfinger, callback  if fields.hasOwnProperty("webfinger")
  return

postToEndpoint = (endpoint, params, callback) ->
  options = url.parse(endpoint)
  pstring = querystring.stringify(params)
  options.method = "POST"
  options.headers = "Content-Type": "application/x-www-form-urlencoded"
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
      if res.statusCode < 200 or res.statusCode > 300
        callback new Error("Error " + res.statusCode + ": " + body), null, null
      else
        callback null, body, res
      return

    return
  )
  req.on "error", (err) ->
    callback err, null, null
    return

  req.write pstring
  req.end()
  return


# XXX: separate request store
requests = {}
saveRequest = (id, url, date, token, callback) ->
  ms = Date.parse(date)
  props =
    endpoint: url
    id: id
    token: token
    timestamp: ms

  Step (->
    DialbackRequest.create props, this
    return
  ), (err, req) ->
    callback err
    return

  return

seenRequest = (id, url, date, token, callback) ->
  ms = Date.parse(date)
  props =
    endpoint: url
    id: id
    token: token
    timestamp: ms

  key = DialbackRequest.toKey(props)
  Step (->
    DialbackRequest.get key, this
    return
  ), (err, req) ->
    if err and (err.name is "NoSuchThingError")
      callback null, false
    else if err
      callback err, null
    else
      callback null, true
    return

  return

maybeDialback = (req, res, next) ->
  unless req.headers.hasOwnProperty("authorization")
    next()
    return
  dialback req, res, next
  return

dialback = (req, res, next) ->
  auth = undefined
  now = Date.now()
  fields = undefined
  unauthorized = (msg) ->
    res.status 401
    res.setHeader "WWW-Authentication", "Dialback"
    res.setHeader "Content-Type", "text/plain"
    res.send msg
    return

  parseFields = (str) ->
    fstr = str.substr(9) # everything after "Dialback "
    pairs = fstr.split(/,\s+/) # XXX: won't handle blanks inside values well
    fields = {}
    pairs.forEach (pair) ->
      kv = pair.split("=")
      key = kv[0]
      value = kv[1].replace(/^"|"$/g, "")
      fields[key] = value
      return

    fields

  unless req.headers.hasOwnProperty("authorization")
    unauthorized "No Authorization header"
    return
  auth = req.headers.authorization
  unless auth.substr(0, 9) is "Dialback "
    unauthorized "Authorization scheme is not 'Dialback'"
    return
  fields = parseFields(auth)
  
  # must have a token
  unless fields.hasOwnProperty("token")
    unauthorized "Authorization header has no 'token' field"
    return
  
  # must have a webfinger or host field
  if not fields.hasOwnProperty("host") and not fields.hasOwnProperty("webfinger")
    unauthorized "Authorization header has neither 'host' nor 'webfinger' fields"
    return
  fields.url = URLMaker.makeURL(req.originalUrl)
  unless req.headers.hasOwnProperty("date")
    unauthorized "No 'Date' header"
    return
  fields.date = req.headers.date
  if Math.abs(Date.parse(fields.date) - now) > 300000 # 5-minute window
    unauthorized "'Date' header is outside our 5-minute window"
    return
  Step (->
    seenRequest fields.host or fields.webfinger, fields.url, fields.date, fields.token, this
    return
  ), ((err, seen) ->
    throw err  if err
    if seen
      unauthorized "We've already seen this request."
      return
    else
      saveRequest fields.host or fields.webfinger, fields.url, fields.date, fields.token, this
    return
  ), ((err) ->
    throw err  if err
    discoverEndpoint fields, this
    return
  ), ((err, endpoint) ->
    throw err  if err
    postToEndpoint endpoint, fields, this
    return
  ), (err, body, res) ->
    if err
      unauthorized err.message
    else if fields.hasOwnProperty("host")
      req.remoteHost = fields.host
      next()
    else if fields.hasOwnProperty("webfinger")
      req.remoteUser = fields.webfinger
      next()
    return

  return

exports.dialback = dialback
exports.maybeDialback = maybeDialback
