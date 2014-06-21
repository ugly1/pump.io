# proxy.js
#
# A proxy for a remote request
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
databank = require("databank")
_ = require("underscore")
Step = require("step")
IDMaker = require("../idmaker").IDMaker
Stamper = require("../stamper").Stamper
DatabankObject = databank.DatabankObject
NoSuchThingError = databank.NoSuchThingError
Proxy = DatabankObject.subClass("proxy")
Proxy.schema =
  pkey: "url"
  fields: [
    "id"
    "created"
  ]
  indices: ["id"]

Proxy.beforeCreate = (props, callback) ->
  unless props.url
    callback new Error("No URL specified"), null
    return
  props.id = IDMaker.makeID()
  props.created = Stamper.stamp()
  callback null, props
  return

Proxy.ensureAll = (urls, callback) ->
  pmap = undefined
  tryCreate = (url, cb) ->
    Step (->
      Proxy.create
        url: url
      , this
      return
    ), (err, result) ->
      if err and err.name is "AlreadyExistsError"
        Proxy.get url, cb
      else if err
        cb err, null
      else
        cb null, result
      return

    return

  Step (->
    Proxy.readAll urls, this
    return
  ), ((err, results) ->
    group = @group()
    throw err  if err
    pmap = results
    _.each pmap, (proxy, url) ->
      tryCreate url, group()  unless proxy
      return

    return
  ), (err, proxies) ->
    if err
      callback err, null
    else
      _.each proxies, (proxy) ->
        pmap[proxy.url] = proxy
        return

      callback null, pmap
    return

  return

Proxy.ensureURL = (url, callback) ->
  tryCreate = (url, cb) ->
    Step (->
      Proxy.create
        url: url
      , this
      return
    ), (err, result) ->
      if err and err.name is "AlreadyExistsError"
        Proxy.get url, cb
      else if err
        cb err, null
      else
        cb null, result
      return

    return

  Step (->
    Proxy.get url, this
    return
  ), (err, result) ->
    delta = undefined
    if err and err.name is "NoSuchThingError"
      tryCreate url, callback
    else if err
      callback err, null
    else
      callback null, result
    return

  return

Proxy.whitelist = []
exports.Proxy = Proxy
