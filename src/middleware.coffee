# middleware.js
#
# Some things you may need
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
databank = require("databank")
Step = require("step")
_ = require("underscore")
bcrypt = require("bcrypt")
fs = require("fs")
path = require("path")
os = require("os")
randomString = require("./randomstring").randomString
Activity = require("./model/activity").Activity
User = require("./model/user").User
Client = require("./model/client").Client
HTTPError = require("./httperror").HTTPError
NoSuchThingError = databank.NoSuchThingError

# If there is a user in the params, gets that user and
# adds them to the request as req.user
# also adds the user's profile to the request as req.profile
# Note: req.user != req.principalUser
reqUser = (req, res, next) ->
  user = undefined
  Step (->
    User.get req.params.nickname, this
    return
  ), ((err, results) ->
    if err
      if err.name is "NoSuchThingError"
        throw new HTTPError(err.message, 404)
      else
        throw err
    user = results
    user.expand this
    return
  ), (err) ->
    if err
      next err
    else
      req.user = user
      req.person = user.profile
      next()
    return

  return

sameUser = (req, res, next) ->
  if not req.principal or not req.user or req.principal.id isnt req.user.profile.id
    next new HTTPError("Not authorized", 401)
  else
    next()
  return

fileContent = (req, res, next) ->
  if req.headers["content-type"] is "application/json"
    binaryJSONContent req, res, next
  else
    otherFileContent req, res, next
  return

otherFileContent = (req, res, next) ->
  req.uploadMimeType = req.headers["content-type"]
  req.uploadContent = req.body
  next()
  return

binaryJSONContent = (req, res, next) ->
  obj = req.body
  fname = undefined
  data = undefined
  unless _.has(obj, "mimeType")
    next new HTTPError("No mime type", 400)
    return
  req.uploadMimeType = obj.mimeType
  unless _.has(obj, "data")
    next new HTTPError("No data", 400)
    return
  
  # Un-URL-safe the data
  obj.data.replace /\-/g, "+"
  obj.data.replace /_/g, "/"
  if obj.data.length % 3 is 1
    obj.data += "=="
  else obj.data += "="  if obj.data.length % 3 is 2
  try
    data = new Buffer(obj.data, "base64")
  catch err
    next err
    return
  Step (->
    randomString 8, this
    return
  ), ((err, str) ->
    ws = undefined
    throw err  if err
    fname = path.join(os.tmpDir(), str + ".bin")
    ws = fs.createWriteStream(fname)
    ws.on "close", this
    ws.write data
    ws.end()
    return
  ), (err) ->
    if err
      next err
    else
      req.uploadFile = fname
      next()
    return

  return


# Add a generator object to writeable requests
reqGenerator = (req, res, next) ->
  client = req.client
  unless client
    next new HTTPError("No client", 500)
    return
  Step (->
    client.asActivityObject this
    return
  ), ((err, obj) ->
    throw err  if err
    req.generator = obj
    this null
    return
  ), next
  return

exports.reqUser = reqUser
exports.reqGenerator = reqGenerator
exports.sameUser = sameUser
exports.fileContent = fileContent
