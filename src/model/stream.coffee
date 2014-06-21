# stream.js
#
# A (potentially very long) stream of object IDs
#
# Copyright 2011,2012,2013 E14N https://e14n.com/
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
Schlock = require("schlock")
Queue = require("jankyqueue")
DatabankObject = databank.DatabankObject
IDMaker = require("../idmaker").IDMaker
NoSuchThingError = databank.NoSuchThingError
DatabankError = databank.DatabankError

# A stream is a potentially very large array of items -- usually
# string IDs or JSON-encoded references, although most objects should work.
#
# Streams are LIFO -- getting items 0-19 will get the most recent 20
# items.
#
# The data structure is an array of stream segments, each segment 1-2000 items
# in length. New segments are added to the end. New items are appended
# to the end of each array. So, adding the first 10,000 whole numbers to
# a stream, in order, would give a data structure kind of like this:
#
# [[9999, 9998, 9997, ..., 8763, 8762, 8761],
#  [8760, 8759, 8758, ..., 7433, 7432, 7431],
#  ...
#  [991, 990, 989, ..., 2, 1, 0]]
#
# The advantage of this backwards-looking structure is a) items keep their local index
# within a segment no matter how many items are added and b) Databank systems that
# support arrays natively seem to support append() natively more often than prepend.
#
# Total stream count, and count per segment, are kept in separate
# records so they can be atomically incremented or decremented.
#
# The most recently added items to a stream are much more likely to be retrieved
# than more recent ones.
Stream = DatabankObject.subClass("stream")
Stream.SOFT_LIMIT = 1000
Stream.HARD_LIMIT = 2000
NotInStreamError = (id, streamName) ->
  Error.captureStackTrace this, NotInStreamError
  @name = "NotInStreamError"
  @id = id
  @streamName = streamName
  @message = "id '" + id + "' not found in stream '" + streamName + "'"
  return

NotInStreamError:: = new DatabankError()
NotInStreamError::constructor = NotInStreamError

# Global locking system for streams
Stream.schlock = new Schlock()
Stream.beforeCreate = (props, callback) ->
  bank = Stream.bank()
  stream = null
  schlocked = false
  id = undefined
  unless props.name
    callback new Error("Gotta have a name"), null
    return
  id = props.name + ":stream:" + IDMaker.makeID()
  Step (->
    Stream.schlock.writeLock props.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    bank.create "streamsegmentcount", id, 0, @parallel()
    bank.create "streamsegment", id, [], @parallel()
    return
  ), ((err, cnt, seg) ->
    throw err  if err
    bank.create "streamcount", props.name, 0, @parallel()
    bank.create "streamsegments", props.name, [id], @parallel()
    return
  ), ((err, count, segments) ->
    throw err  if err
    Stream.schlock.writeUnlock props.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock props.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null, props
    return

  return


# put something in the stream
randBetween = (min, max) ->
  diff = max - min + 1
  Math.floor (Math.random() * diff) + min

Stream::deliver = (id, callback) ->
  stream = this
  bank = Stream.bank()
  schlocked = false
  current = null
  Step (->
    Stream.schlock.writeLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    bank.read "streamsegments", stream.name, this
    return
  ), ((err, segments) ->
    throw err  if err
    throw new Error("No segments in stream")  if segments.length is 0
    current = segments[segments.length - 1]
    bank.read "streamsegmentcount", current, this
    return
  ), ((err, cnt) ->
    throw err  if err
    
    # Once we hit the soft limit, we start thinking about
    # a new segment. To avoid conflicts, a bit, we do it at a
    # random point between soft and hard limit. If we actually
    # hit the hard limit, force it.
    if cnt > Stream.SOFT_LIMIT and (cnt > Stream.HARD_LIMIT or randBetween(0, Stream.HARD_LIMIT - Stream.SOFT_LIMIT) is 0)
      stream.newSegmentLockless this
    else
      this null, current
    return
  ), ((err, segmentId) ->
    throw err  if err
    bank.append "streamsegment", segmentId, id, @parallel()
    bank.incr "streamsegmentcount", segmentId, @parallel()
    bank.incr "streamcount", stream.name, @parallel()
    return
  ), ((err) ->
    throw err  if err
    Stream.schlock.writeUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null
    return

  return

Stream::remove = (id, callback) ->
  stream = this
  bank = Stream.bank()
  current = null
  schlocked = false
  segments = undefined
  segmentId = undefined
  Step (->
    Stream.schlock.writeLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    bank.read "streamsegments", stream.name, this
    return
  ), ((err, segments) ->
    i = undefined
    cb = this
    findFrom = (j) ->
      if j >= segments.length
        cb new NotInStreamError(id, stream.name), null
        return
      bank.indexOf "streamsegment", segments[j], id, (err, idx) ->
        if err
          cb err, null
        else if idx is -1
          findFrom j + 1
        else
          cb null, segments[j]
        return

      return

    throw err  if err
    findFrom 0
    return
  ), ((err, found) ->
    throw err  if err
    segmentId = found
    bank.remove "streamsegment", segmentId, id, this
    return
  ), ((err) ->
    throw err  if err
    bank.decr "streamsegmentcount", segmentId, @parallel()
    bank.decr "streamcount", stream.name, @parallel()
    return
  ), ((err) ->
    throw err  if err
    Stream.schlock.writeUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null
    return

  return

Stream::newSegment = (callback) ->
  stream = this
  id = undefined
  schlocked = false
  Step (->
    Stream.schlock.writeLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    stream.newSegmentLockless this
    return
  ), ((err, results) ->
    throw err  if err
    id = results
    Stream.schlock.writeUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.writeUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null, id
    return

  return

Stream::newSegmentLockless = (callback) ->
  bank = Stream.bank()
  stream = this
  id = stream.name + ":stream:" + IDMaker.makeID()
  Step (->
    bank.create "streamsegmentcount", id, 0, @parallel()
    bank.create "streamsegment", id, [], @parallel()
    return
  ), ((err, cnt, segment) ->
    throw err  if err
    bank.append "streamsegments", stream.name, id, this
    return
  ), (err) ->
    if err
      callback err, null
    else
      callback err, id
    return

  return

Stream::getItems = (start, end, callback) ->
  bank = Stream.bank()
  stream = this
  ids = undefined
  schlocked = undefined
  Step (->
    Stream.schlock.readLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.getItemsLockless start, end, this
    return
  ), ((err, results) ->
    throw err  if err
    ids = results
    Stream.schlock.readUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null, ids
    return

  return

Stream::getItemsLockless = (start, end, callback) ->
  bank = Stream.bank()
  stream = this
  ids = undefined
  getMore = getMore = (segments, segidx, start, end, callback) ->
    tip = undefined
    if segidx < 0
      callback null, []
      return
    tip = segments[segidx] # last segment
    Step (->
      bank.read "streamsegmentcount", tip, this
      return
    ), ((err, tipcount) ->
      p0 = @parallel()
      p1 = @parallel()
      throw err  if err
      if start < tipcount
        bank.slice "streamsegment", tip, Math.max((tipcount - end), 0), tipcount - start, p0
      else
        p0 null, []
      if end > tipcount and segidx > 0
        # end > tipcount => end - tipcount >= 0
        getMore segments, segidx - 1, Math.max(start - tipcount, 0), end - tipcount, p1
      else
        p1 null, []
      return
    ), (err, head, tail) ->
      if err
        callback err, null
      else
        head.reverse()
        callback null, head.concat(tail)
      return

    return

  if start < 0 or end < 0 or start > end
    callback new Error("Bad parameters"), null
    return
  Step (->
    
    # XXX: maybe just take slice from [0, end/HARD_LIMIT)
    bank.read "streamsegments", stream.name, this
    return
  ), ((err, segments) ->
    throw err  if err
    if not segments or segments.length is 0
      this null, []
      return
    getMore segments, segments.length - 1, start, end, this
    return
  ), (err, ids) ->
    if err
      callback err, null
    else
      callback null, ids
    return

  return


# XXX: Not atomic; can get out of whack if an insertion
# happens between indexOf() and getItems()
Stream::getItemsGreaterThan = (id, count, callback) ->
  stream = this
  ids = undefined
  schlocked = false
  if count < 0
    callback new Error("count must be >= 0)"), null
    return
  Step (->
    Stream.schlock.readLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.indexOfLockless id, this
    return
  ), ((err, idx) ->
    throw err  if err
    stream.getItemsLockless idx + 1, idx + count + 1, this
    return
  ), ((err, results) ->
    throw err  if err
    ids = results
    Stream.schlock.readUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null, ids
    return

  return


# XXX: Not atomic; can get out of whack if an insertion
# happens between indexOf() and getItems()
Stream::getItemsLessThan = (id, count, callback) ->
  stream = this
  ids = undefined
  schlocked = false
  Step (->
    Stream.schlock.readLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.indexOfLockless id, this
    return
  ), ((err, idx) ->
    throw err  if err
    stream.getItemsLockless Math.max(0, idx - count), idx, this
    return
  ), ((err, results) ->
    throw err  if err
    ids = results
    Stream.schlock.readUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null, ids
    return

  return

Stream::indexOf = (id, callback) ->
  stream = this
  schlocked = false
  idx = undefined
  Step (->
    Stream.schlock.readLock stream.name, this
    return
  ), ((err) ->
    throw err  if err
    schlocked = true
    stream.indexOfLockless id, this
    return
  ), ((err, results) ->
    throw err  if err
    idx = results
    Stream.schlock.readUnlock stream.name, this
    return
  ), (err) ->
    if err
      if schlocked
        Stream.schlock.readUnlock stream.name, (err2) ->
          callback err, null
          return

      else
        callback err, null
    else
      callback null, idx
    return

  return

Stream::indexOfLockless = (id, callback) ->
  bank = Stream.bank()
  stream = this
  indexOfSeg = indexOfSeg = (id, segments, segidx, offset, callback) ->
    tip = undefined
    cnt = undefined
    tip = segments[segidx]
    Step (->
      bank.read "streamsegmentcount", tip, this
      return
    ), ((err, result) ->
      throw err  if err
      cnt = result
      bank.indexOf "streamsegment", tip, id, this
      return
    ), (err, idx) ->
      rel = undefined
      result = undefined
      if err
        callback err, null
      else if idx is -1
        if segidx is 0
          callback null, -1
        else
          indexOfSeg id, segments, segidx - 1, offset + cnt, callback
      else
        rel = ((cnt - 1) - idx)
        result = rel + offset
        callback null, result
      return

    return

  Step (->
    
    # XXX: maybe just take slice from [0, end/HARD_LIMIT)
    bank.read "streamsegments", stream.name, this
    return
  ), ((err, segments) ->
    throw err  if err
    if not segments or segments.length is 0
      callback null, -1
      return
    indexOfSeg id, segments, segments.length - 1, 0, this
    return
  ), (err, idx) ->
    if err
      callback err, null
    else if idx is -1
      callback new NotInStreamError(id, stream.name), null
    else
      callback null, idx
    return

  return

Stream::count = (callback) ->
  Stream.count @name, callback
  return

Stream.count = (name, callback) ->
  bank = Stream.bank()
  bank.read "streamcount", name, callback
  return

Stream::getIDs = (start, end, callback) ->
  @getItems start, end, callback
  return

Stream::getIDsGreaterThan = (id, count, callback) ->
  @getItemsGreaterThan id, count, callback
  return

Stream::getIDsLessThan = (id, count, callback) ->
  @getItemsLessThan id, count, callback
  return

Stream::getObjects = (start, end, callback) ->
  stream = this
  Step (->
    stream.getItems start, end, this
    return
  ), (err, items) ->
    i = undefined
    objs = undefined
    if err
      callback err, null
    else
      objs = new Array(items.length)
      i = 0
      while i < items.length
        objs[i] = JSON.parse(items[i])
        i++
      callback err, objs
    return

  return

Stream::getObjectsGreaterThan = (obj, count, callback) ->
  stream = this
  Step (->
    stream.getItemsGreaterThan JSON.stringify(obj), count, this
    return
  ), (err, items) ->
    i = undefined
    objs = undefined
    if err
      callback err, null
    else
      objs = new Array(items.length)
      i = 0
      while i < items.length
        objs[i] = JSON.parse(items[i])
        i++
      callback err, objs
    return

  return

Stream::getObjectsLessThan = (obj, count, callback) ->
  stream = this
  Step (->
    stream.getItemsLessThan JSON.stringify(obj), count, this
    return
  ), (err, items) ->
    i = undefined
    objs = undefined
    if err
      callback err, null
    else
      objs = new Array(items.length)
      i = 0
      while i < items.length
        objs[i] = JSON.parse(items[i])
        i++
      callback err, objs
    return

  return

Stream::deliverObject = (obj, callback) ->
  @deliver JSON.stringify(obj), callback
  return

Stream::removeObject = (obj, callback) ->
  @remove JSON.stringify(obj), callback
  return

Stream::hasObject = (obj, callback) ->
  str = this
  Step (->
    str.indexOf JSON.stringify(obj), this
    return
  ), ((err, index) ->
    if err and err.name is "NotInStreamError"
      this null, false
    else if err and err.name isnt "NotInStreamError"
      this err, null
    else this null, true  unless err
    return
  ), callback
  return

Stream.schema =
  stream:
    pkey: "name"

  streamcount:
    pkey: "name"

  streamsegments:
    pkey: "name"

  streamsegment:
    pkey: "id"

  streamsegmentcount:
    pkey: "id"

Stream::dump = (callback) ->
  bank = Stream.bank()
  str = this
  res = {}
  Step (->
    bank.read "stream", str.name, @parallel()
    bank.read "streamcount", str.name, @parallel()
    bank.read "streamsegments", str.name, @parallel()
    return
  ), ((err, val, cnt, segs) ->
    i = undefined
    g1 = @group()
    g2 = @group()
    throw err  if err
    res.stream = val
    res.streamcount = cnt
    res.streamsegments = segs
    i = 0
    while i < segs.length
      bank.read "streamsegmentcount", segs[i], g1()
      bank.read "streamsegment", segs[i], g2()
      i++
    return
  ), (err, counts, segments) ->
    if err
      callback err, null
    else
      res.streamsegmentcount = counts
      res.streamsegment = segments
      callback null, res
    return

  return

MAX_EACH = 25
Stream::each = (iter, concur, callback) ->
  bank = Stream.bank()
  str = this
  q = undefined
  unless callback
    callback = concur
    concur = 16
  q = new Queue(concur)
  Step (->
    bank.read "streamsegments", str.name, this
    return
  ), ((err, segmentIDs) ->
    throw err  if err
    if segmentIDs.length is 0
      this null, []
    else
      bank.readAll "streamsegment", segmentIDs, this
    return
  ), ((err, segments) ->
    expected = 0
    actual = 0
    allEnqueued = false
    errorHappened = false
    finished = this
    safeIter = (item, callback) ->
      try
        iter item, callback
      catch err
        callback err
      return

    handler = (err) ->
      if errorHappened
        
        # just skip
        finished null
        return
      if err
        errorHappened = true
        finished err
      else
        actual++
        finished null  if actual >= expected and allEnqueued
      return

    _.each segments, (segment) ->
      expected += segment.length
      _.each segment, (item) ->
        q.enqueue safeIter, [item], handler
        return

      return

    allEnqueued = true
    
    # None were enqueued
    if expected is 0
      finished null
      return
  ), callback
  return


# A wrapper for .each() that passes a parsed object
# to the iterator
Stream::eachObject = (iter, callback) ->
  str = this
  objIter = (item, cb) ->
    obj = undefined
    try
      obj = JSON.parse(item)
      iter obj, cb
    catch err
      cb err
    return

  str.each objIter, callback
  return

exports.Stream = Stream
exports.NotInStreamError = NotInStreamError
