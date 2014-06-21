# lib/saveupload.js
#
# The necessary recipe for saving uploaded files
#
# Copyright 2012,2013 E14N https://e14n.com/
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
path = require("path")
fs = require("fs")
mkdirp = require("mkdirp")
_ = require("underscore")
gm = require("gm")
HTTPError = require("../lib/httperror").HTTPError
ActivityObject = require("../lib/model/activityobject").ActivityObject
URLMaker = require("../lib/urlmaker").URLMaker
randomString = require("../lib/randomstring").randomString
mm = require("./mimemap")
thumbnail = require("./thumbnail")
mover = require("./mover")
safeMove = mover.safeMove
typeToClass = mm.typeToClass
typeToExt = mm.typeToExt
extToType = mm.extToType
addImageMetadata = thumbnail.addImageMetadata
addAvatarMetadata = thumbnail.addAvatarMetadata
autorotate = thumbnail.autorotate

# Since saveUpload and saveAvatar are so similar, except for a single
# function call, I have a factory and then use it below.
saver = (thumbnailer) ->
  (user, mimeType, fileName, uploadDir, params, callback) ->
    props = undefined
    now = new Date()
    ext = typeToExt(mimeType)
    dir = path.join(user.nickname, "" + now.getUTCFullYear(), "" + (now.getUTCMonth() + 1), "" + now.getUTCDate())
    fulldir = path.join(uploadDir, dir)
    slug = undefined
    obj = undefined
    fname = undefined
    Cls = typeToClass(mimeType)
    
    # params are optional
    unless callback
      callback = params
      params = {}
    Step (->
      mkdirp fulldir, this
      return
    ), ((err) ->
      throw err  if err
      randomString 4, this
      return
    ), ((err, rnd) ->
      throw err  if err
      slug = path.join(dir, rnd + "." + ext)
      fname = path.join(uploadDir, slug)

      
      # autorotate requires a copy, so we do it here
      if Cls.type is ActivityObject.IMAGE
        autorotate fileName, fname, this
      else
        safeMove fileName, fname, this
      return
    ), ((err) ->
      url = undefined
      throw err  if err
      url = URLMaker.makeURL("uploads/" + slug)
      switch Cls.type
        when ActivityObject.IMAGE
          props =
            _slug: slug
            author: user.profile
            image:
              url: url
        when ActivityObject.AUDIO, ActivityObject.VIDEO
          props =
            _slug: slug
            author: user.profile
            stream:
              url: url
        when ActivityObject.FILE
          props =
            _slug: slug
            author: user.profile
            fileUrl: url
            mimeType: mimeType
        else
          throw new Error("Unknown type.")
      
      # XXX: summary, or content?
      props.content = params.description  if _.has(params, "description")
      props.displayName = params.title  if _.has(params, "title")
      
      # Images get some additional metadata
      if Cls.type is ActivityObject.IMAGE
        thumbnailer props, uploadDir, this
      else
        this null, props
      return
    ), ((err, props) ->
      throw err  if err
      Cls.create props, this
      return
    ), ((err, result) ->
      throw err  if err
      obj = result
      user.uploadsStream this
      return
    ), ((err, str) ->
      throw err  if err
      str.deliverObject
        id: obj.id
        objectType: obj.objectType
      , this
      return
    ), (err) ->
      if err
        callback err, null
      else
        callback null, obj
      return

    return

saveUpload = saver(addImageMetadata)
saveAvatar = saver(addAvatarMetadata)
exports.saveUpload = saveUpload
exports.saveAvatar = saveAvatar
