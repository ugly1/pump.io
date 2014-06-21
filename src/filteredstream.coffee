# filteredstream.js
#
# A (potentially very long) stream of object IDs, filtered asynchronously
#
# Copyright 2012 E14N https://e14n.com/
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
util = require("util")
Stream = require("./model/stream").Stream
FilteredStream = (str, filter) ->
  @str = str
  @filter = filter
  return

util.inherits FilteredStream, Stream
FilteredStream::getItems = (start, end, callback) ->
  fs = this
  str = @str
  f = @filter
  chunk = undefined
  ids = []
  Step (->
    str.getItems 0, end, this
    return
  ), ((err, result) ->
    i = undefined
    group = @group()
    throw err  if err
    chunk = result
    i = 0
    while i < chunk.length
      f chunk[i], group()
      i++
    return
  ), ((err, flags) ->
    i = undefined
    throw err  if err
    i = 0
    while i < chunk.length
      ids.push chunk[i]  if flags[i]
      i++
    
    # If we got all we wanted, or we tapped out upstream...
    if ids.length is end or chunk.length < end
      callback null, ids
    else
      
      # Get some more
      # XXX: last ID in chunk might not pass filter
      fs.getItemsGreaterThan chunk[chunk.length - 1], end - ids.length, this
    return
  ), (err, rest) ->
    result = undefined
    if err
      callback err, null
    else
      callback null, ids.concat(rest).slice(start, end)
    return

  return

FilteredStream::getItemsGreaterThan = (id, count, callback) ->
  fs = this
  str = @str
  f = @filter
  chunk = undefined
  ids = []
  Step (->
    str.getItemsGreaterThan id, count, this
    return
  ), ((err, result) ->
    i = undefined
    group = @group()
    throw err  if err
    chunk = result
    i = 0
    while i < chunk.length
      f chunk[i], group()
      i++
    return
  ), ((err, flags) ->
    i = undefined
    throw err  if err
    i = 0
    while i < chunk.length
      ids.push chunk[i]  if flags[i]
      i++
    
    # If we got all we wanted, or we tapped out upstream...
    if ids.length is count or chunk.length < count
      callback null, ids
    else
      
      # Get some more
      # XXX: last ID in chunk might not pass filter
      fs.getItemsGreaterThan chunk[chunk.length - 1], count - ids.length, this
    return
  ), (err, rest) ->
    if err
      callback err, null
    else
      callback null, ids.concat(rest)
    return

  return

FilteredStream::getItemsLessThan = (id, count, callback) ->
  fs = this
  str = @str
  f = @filter
  chunk = undefined
  ids = []
  Step (->
    str.getItemsLessThan id, count, this
    return
  ), ((err, result) ->
    i = undefined
    group = @group()
    throw err  if err
    chunk = result
    i = 0
    while i < chunk.length
      f chunk[i], group()
      i++
    return
  ), ((err, flags) ->
    i = undefined
    throw err  if err
    i = 0
    while i < chunk.length
      ids.push chunk[i]  if flags[i]
      i++
    
    # If we got all we wanted, or we tapped out upstream...
    if ids.length is count or chunk.length < count
      callback null, ids
    else
      
      # Get some more
      # XXX: last ID in chunk might not pass filter
      fs.getItemsLessThan chunk[0], count - ids.length, this
    return
  ), (err, rest) ->
    if err
      callback err, null
    else
      callback null, rest.concat(ids)
    return

  return

FilteredStream::count = (callback) ->
  @str.count callback
  return

exports.FilteredStream = FilteredStream
