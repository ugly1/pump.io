# rawbody.js
#
# Middleware to grab the body of an HTTP request if it's not
# a well-known type
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
express = require("express")
fs = require("fs")
os = require("os")
path = require("path")
_ = require("underscore")
Step = require("step")
mm = require("./mimemap")
typeToExt = mm.typeToExt
randomString = require("./randomstring").randomString
maybeCleanup = (fname, callback) ->
  Step (->
    fs.stat fname, this
    return
  ), ((err, stat) ->
    if err
      if err.code is "ENOENT"
        
        # Good; it got used
        return
      else
        throw err
    fs.unlink fname, this
    return
  ), callback
  return

rawBody = (req, res, next) ->
  buf = new Buffer(0)
  len = undefined
  mimeType = undefined
  fname = undefined
  fdir = undefined
  skip = [
    "application/json"
    "application/x-www-form-urlencoded"
    "multipart/form-data"
  ]
  bufferData = (err, chunk) ->
    buf = Buffer.concat([
      buf
      chunk
    ])
    return

  if req.method isnt "PUT" and req.method isnt "POST"
    next()
    return
  mimeType = req.headers["content-type"]
  unless mimeType
    next()
    return
  mimeType = mimeType.split(";")[0]
  if _.contains(skip, mimeType) or _.has(express.bodyParser.parse, mimeType)
    next()
    return
  req.log.debug "Parsing raw body of request with type " + mimeType
  if _.has(req.headers, "content-length")
    try
      len = parseInt(req.headers["content-length"], 10)
    catch e
      next e
      return
  
  # Buffer here to catch stuff while pause is sputtering to a stop
  req.on "data", bufferData
  
  # Pause the request while we open our file
  req.pause()
  Step (->
    randomString 8, this
    return
  ), ((err, str) ->
    ws = undefined
    ext = undefined
    tmpdir = (if (_.isFunction(os.tmpdir)) then os.tmpdir() else (if (_.isFunction(os.tmpDir)) then os.tmpDir() else "/tmp"))
    throw err  if err
    ext = typeToExt(mimeType) or "bin"
    fname = path.join(tmpdir, str + "." + ext)

    ws = fs.createWriteStream(fname)
    ws.write buf  if buf.length
    req.removeListener "data", bufferData
    req.resume()
    ws.on "close", this
    req.pipe ws
    return
  ), (err) ->
    end = undefined
    if err
      next err
    else
      req.uploadFile = fname
      req.uploadMimeType = mimeType
      end = res.end
      
      # If needed, clean up our temp file
      res.end = (chunk, encoding) ->
        res.end = end
        res.end chunk, encoding
        maybeCleanup fname, (err) ->
          if err
            req.log.error
              err: err
              fname: fname
            , "Error cleaning up"
          return

        return

      next()
    return

  return

exports.rawBody = rawBody
