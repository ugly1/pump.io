# lib/mover.js
#
# Move files from one place on disk to another
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
fs = require("fs")
_ = require("underscore")
safeMove = (oldName, newName, callback) ->
  Step (->
    fs.rename oldName, newName, this
    return
  ), ((err) ->
    if err
      if err.code is "EXDEV"
        slowMove oldName, newName, this
      else
        throw err
    else
      this null
    return
  ), callback
  return

slowMove = (oldName, newName, callback) ->
  rs = undefined
  ws = undefined
  onClose = ->
    clear()
    callback null
    return

  onError = (err) ->
    clear()
    callback err
    return

  clear = ->
    rs.removeListener "error", onError
    ws.removeListener "error", onError
    ws.removeListener "close", onClose
    return

  try
    rs = fs.createReadStream(oldName)
    ws = fs.createWriteStream(newName)
  catch err
    callback err
    return
  ws.on "close", onClose
  rs.on "error", onError
  ws.on "error", onError
  rs.pipe ws
  return

exports.safeMove = safeMove
