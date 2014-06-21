# urlmaker.js
#
# URLs just like Mama used to make
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
url = require("url")
querystring = require("querystring")
URLMaker =
  hostname: null
  port: 80
  path: null
  makeURL: (relative, params) ->
    obj = undefined
    throw new Error("No hostname")  unless @hostname
    obj =
      protocol: (if (@port is 443) then "https:" else "http:")
      host: @makeHost()
      pathname: @makePath(relative)

    obj.search = querystring.stringify(params)  if params
    url.format obj

  normalize: (path) ->
    return ""  if not path or path.length is 0
    path = "/" + path  unless path[0] is "/"
    path = path.substr(0, path.length - 1)  if path[path.length - 1] is "/"
    path

  makeHost: (hostname, port) ->
    unless hostname
      hostname = @hostname
      port = @port
    if port is 80 or port is 443
      hostname
    else
      hostname + ":" + port

  makePath: (relative) ->
    fullPath = undefined
    relative = "/" + relative  if relative.length is 0 or relative[0] isnt "/"
    unless @path
      fullPath = relative
    else
      fullPath = @normalize(@path) + relative
    fullPath

exports.URLMaker = URLMaker
