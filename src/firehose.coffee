# firehose.js
#
# Update a remote firehose
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
http = require("http")
https = require("https")
urlparse = require("url").parse
Queue = require("jankyqueue")
Step = require("step")
web = require("./web")
HTTPError = require("./httperror").HTTPError

# How many pings we should have going at once
QUEUE_MAX = 25
host = null
log = null
mod = null
options = null
q = new Queue(QUEUE_MAX)

# Main interface
Firehose =
  setup: (hostname, plog) ->
    host = hostname
    if plog
      log = plog.child(
        component: "firehose"
        firehose: hostname
      )
      log.debug "Setting up firehose."
    return

  ping: (activity, callback) ->
    hose = this
    if log
      log.debug
        activity: activity.id
      , "Enqueuing ping."
    
    # If there's no host, silently skip
    unless host
      if log
        log.warn
          activity: activity.id
        , "Skipping; no host."
      callback null
      return
    
    # Enqueue 
    q.enqueue pinger, [activity], callback
    return


# Actually pings the firehose
pinger = (activity, callback) ->
  Step (->
    getEndpointOptions this
    return
  ), ((err, mod, options) ->
    req = undefined
    json = undefined
    opts = _.clone(options)
    throw err  if err
    json = JSON.stringify(activity)
    opts.headers = {}  unless opts.headers
    opts.headers["Content-Length"] = json.length
    opts.headers["Content-Type"] = "application/json"
    if log
      log.info
        activity: activity.id
      , "Pinging firehose"
    web.mod mod, opts, json, this
    return
  ), (err, res) ->
    if err
      
      # XXX: retry
      log.error err  if log
      callback err
    else if res.statusCode >= 400 and res.statusCode < 600
      err = new HTTPError(res.body, res.statusCode)
      log.error err  if log
      callback err
    else
      callback null
    return

  return


# Does this response include some indication that the endpoint allows POST requests?
allowsPost = (res) ->
  allow = undefined
  return false  unless _(res.headers).has("allow")
  allow = res.headers.allow.split(",").map((s) ->
    s.trim()
  )
  _.contains allow, "POST"


# Get the options needed to ping the firehose endpoint
# callback is called with err, mod, options
# mod is http or https
getEndpointOptions = (callback) ->
  if mod and options
    callback null, mod, options
    return
  unless host
    callback new Error("No host"), null, null
    return
  
  # Test the HTTPS endpoint
  Step (->
    topt =
      hostname: host
      port: 443
      path: "/ping"
      method: "OPTIONS"

    web.https topt, this
    return
  
  # If that works, return options and HTTPS mod
  # If it doesn't, test the HTTP endpoint
  ), ((err, res) ->
    topt = undefined
    allow = undefined
    if not err and allowsPost(res)
      options =
        hostname: host
        port: 443
        path: "/ping"
        method: "POST"

      mod = https
      callback null, mod, options
    else
      topt =
        hostname: host
        port: 80
        path: "/ping"
        method: "OPTIONS"

      web.http topt, this
    return
  
  # If that works, return options and HTTP mod
  # If it doesn't, fail
  ), (err, res) ->
    if not err and allowsPost(res)
      options =
        hostname: host
        port: 80
        path: "/ping"
        method: "POST"

      mod = http
      callback null, mod, options
    else
      callback new Error("No suitable endpoints"), null, null
    return

  return

module.exports = Firehose
