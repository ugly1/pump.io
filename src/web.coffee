# web.js
#
# Wrap http/https requests in a callback interface
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
urlparse = require("url").parse
http = require("http")
https = require("https")
version = require("./version").version
web =
  mod: (mod, options, reqBody, callback) ->
    req = undefined
    
    # Optional reqBody
    unless callback
      callback = reqBody
      reqBody = null
    
    # Add our user-agent header
    options.headers = {}  unless options.headers
    options.headers["User-Agent"] = "pump.io/" + version  unless options.headers["User-Agent"]
    req = mod.request(options, (res) ->
      resBody = ""
      res.setEncoding "utf8"
      res.on "data", (chunk) ->
        resBody = resBody + chunk
        return

      res.on "error", (err) ->
        callback err, null
        return

      res.on "end", ->
        res.body = resBody
        callback null, res
        return

      return
    )
    req.on "error", (err) ->
      callback err, null
      return

    req.write reqBody  if reqBody
    req.end()
    return

  https: (options, body, callback) ->
    @mod https, options, body, callback
    return

  http: (options, body, callback) ->
    @mod http, options, body, callback
    return

module.exports = web
