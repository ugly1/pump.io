# routes/uploads.js
#
# For the /uploads/* endpoints
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
connect = require("connect")
send = connect.middleware.static.send
cutils = connect.utils
fs = require("fs")
path = require("path")
Step = require("step")
_ = require("underscore")
Activity = require("../lib/model/activity").Activity
HTTPError = require("../lib/httperror").HTTPError
mm = require("../lib/mimemap")
authc = require("../lib/authc")
typeToClass = mm.typeToClass
typeToExt = mm.typeToExt
extToType = mm.extToType
hasOAuth = authc.hasOAuth
userOrClientAuth = authc.userOrClientAuth
principal = authc.principal

# Default expires is one year
EXPIRES = 365 * 24 * 60 * 60 * 1000
addRoutes = (app) ->
  if app.session
    app.get "/uploads/*", app.session, everyAuth, uploadedFile
  else
    app.get "/uploads/*", everyAuth, uploadedFile
  return


# XXX: Add remoteUserAuth
everyAuth = (req, res, next) ->
  if hasOAuth(req)
    userOrClientAuth req, res, next
  else if req.session
    principal req, res, next
  else
    next()
  return


# Check downloads of uploaded files
uploadedFile = (req, res, next) ->
  slug = req.params[0]
  ext = slug.match(/\.(.*)$/)[1]
  type = extToType(ext)
  Cls = typeToClass(type)
  profile = req.principal
  obj = undefined
  req.log.debug
    profile: profile
    slug: slug
  , "Checking permissions"
  Step (->
    Cls.search
      _slug: slug
    , this
    return
  ), ((err, objs) ->
    throw err  if err
    if not objs or objs.length isnt 1
      Cls.search
        _fslug: slug
      , this
    else
      this null, objs
    return
  ), ((err, objs) ->
    throw err  if err
    throw new Error("Bad number of records for uploads")  if not objs or objs.length isnt 1
    obj = objs[0]
    if profile and obj.author and profile.id is obj.author.id
      send req, res, next,
        path: slug
        root: req.app.config.uploaddir

      return
    Activity.postOf obj, this
    return
  ), ((err, post) ->
    throw err  if err
    throw new HTTPError("Not allowed", 403)  unless post
    post.checkRecipient profile, this
    return
  ), (err, flag) ->
    if err
      next err
    else unless flag
      next new HTTPError("Not allowed", 403)
    else
      send req, res, next,
        path: slug
        root: req.app.config.uploaddir

    return

  return

exports.addRoutes = addRoutes
