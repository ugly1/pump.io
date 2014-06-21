# host.js
#
# data object representing a remote host
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
_ = require("underscore")
wf = require("webfinger")
qs = require("querystring")
Step = require("step")
Schlock = require("schlock")
OAuth = require("oauth-evanp").OAuth
DatabankObject = require("databank").DatabankObject
URLMaker = require("../urlmaker").URLMaker
version = require("../version").version
RemoteRequestToken = require("./remoterequesttoken").RemoteRequestToken
Credentials = require("./credentials").Credentials
Host = DatabankObject.subClass("host")
OAUTH_RT = "http://apinamespace.org/oauth/request_token"
OAUTH_AT = "http://apinamespace.org/oauth/access_token"
OAUTH_AUTHZ = "http://apinamespace.org/oauth/authorize"
WHOAMI = "http://apinamespace.org/activitypub/whoami"
OAUTH_CRED = "registration_endpoint"
Host.schema =
  pkey: "hostname"
  fields: [
    "registration_endpoint"
    "request_token_endpoint"
    "access_token_endpoint"
    "authorization_endpoint"
    "whoami_endpoint"
    "created"
    "updated"
  ]

Host.beforeCreate = (props, callback) ->
  unless props.hostname
    callback new Error("Hostname is required"), null
    return
  props.created = Date.now()
  props.modified = props.created
  callback null, props
  return

Host::beforeUpdate = (props, callback) ->
  props.modified = Date.now()
  callback null, props
  return

Host::beforeSave = (callback) ->
  host = this
  unless host.hostname
    callback new Error("Hostname is required")
    return
  host.modified = Date.now()
  host.created = host.modified  unless host.created
  callback null
  return


# prevent clashes for same host
Host.schlock = new Schlock()
Host.ensureHost = (hostname, callback) ->
  host = undefined
  if Host.invalidHostname(hostname)
    callback new Error("Well-known invalid host: " + hostname)
    return
  Step (->
    Host.schlock.writeLock hostname, this
    return
  ), ((err) ->
    throw err  if err
    Host.get hostname, this
    return
  ), ((err, results) ->
    if err and err.name is "NoSuchThingError"
      Host.discover hostname, this
    else if err
      throw err
    else
      
      # XXX: update endpoints?
      this null, results
    return
  ), ((err, results) ->
    throw err  if err
    host = results
    Host.schlock.writeUnlock hostname, this
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback null, host
    return

  return

Host.discover = (hostname, callback) ->
  props = hostname: hostname
  Step (->
    wf.hostmeta hostname, this
    return
  ), ((err, jrd) ->
    throw err  if err
    prop = undefined
    rel = undefined
    rels =
      registration_endpoint: OAUTH_CRED
      request_token_endpoint: OAUTH_RT
      access_token_endpoint: OAUTH_AT
      authorization_endpoint: OAUTH_AUTHZ
      whoami_endpoint: WHOAMI

    for prop of rels
      rel = rels[prop]
      links = _.where(jrd.links,
        rel: rel
      )
      if links.length is 0
        callback new Error(hostname + " does not implement " + rel), null
        return
      else
        props[prop] = links[0].href
    Host.create props, this
    return
  ), callback
  return

Host::getRequestToken = (callback) ->
  host = this
  oa = undefined
  Step (->
    host.getOAuth this
    return
  ), ((err, results) ->
    throw err  if err
    oa = results
    oa.getOAuthRequestToken this
    return
  ), ((err, token, secret, other) ->
    throw err  if err
    RemoteRequestToken.create
      token: token
      secret: secret
      hostname: host.hostname
    , this
    return
  ), callback
  return

Host::authorizeURL = (rt) ->
  host = this
  separator = undefined
  if _.contains(host.authorization_endpoint, "?")
    separator = "&"
  else
    separator = "?"
  host.authorization_endpoint + separator + "oauth_token=" + rt.token

Host::getAccessToken = (rt, verifier, callback) ->
  host = this
  oa = undefined
  Step (->
    host.getOAuth this
    return
  ), ((err, results) ->
    throw err  if err
    oa = results
    oa.getOAuthAccessToken rt.token, rt.secret, verifier, this
    return
  ), (err, token, secret, res) ->
    if err
      callback err, null
    else
      
      # XXX: Mark rt as used?
      # XXX: Save the verifier somewhere?
      callback null,
        token: token
        secret: secret

    return

  return

Host::whoami = (token, secret, callback) ->
  host = this
  oa = undefined
  Step (->
    host.getOAuth this
    return
  ), ((err, results) ->
    throw err  if err
    oa = results
    oa.get host.whoami_endpoint, token, secret, this
    return
  ), ((err, doc, response) ->
    obj = undefined
    throw err  if err
    obj = JSON.parse(doc)
    this null, obj
    return
  ), callback
  return

Host::getOAuth = (callback) ->
  host = this
  Step (->
    Credentials.getForHost URLMaker.hostname, host, this
    return
  ), ((err, cred) ->
    oa = undefined
    throw err  if err
    oa = new OAuth(host.request_token_endpoint, host.access_token_endpoint, cred.client_id, cred.client_secret, "1.0", URLMaker.makeURL("/main/authorized/" + host.hostname), "HMAC-SHA1", null, # nonce size; use default
      "User-Agent": "pump.io/" + version
    )
    this null, oa
    return
  ), callback
  return

Host.invalidHostname = (hostname) ->
  examples = [
    "example.com"
    "example.org"
    "example.net"
  ]
  tlds = [
    "example"
    "invalid"
  ]
  parts = undefined
  return true  if _.contains(examples, hostname.toLowerCase())
  parts = hostname.split(".")
  return true  if _.contains(tlds, parts[parts.length - 1])
  false

exports.Host = Host
