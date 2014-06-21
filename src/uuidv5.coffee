# uuidv5.js
#
# Make a v5 UUID from a string
#
# Copyright 2011-2013, E14N https://e14n.com/
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

# Originally from uuid.js

#     uuid.js
#
#     Copyright (c) 2010-2012 Robert Kieffer
#     MIT License - http://opensource.org/licenses/mit-license.php
#
# Branch for v5 UUIDs by OrangeDog
# http://github.com/OrangeDog

# Maps for number <-> hex string conversion

# **`parse()` - Parse a UUID into its component bytes**
parse = (s, buf, offset) ->
  i = (buf and offset) or 0
  ii = 0
  buf = buf or []
  s.toLowerCase().replace /[0-9a-f]{2}/g, (oct) ->
    # Don't overflow!
    buf[i + ii++] = _hexToByte[oct]  if ii < 16
    return

  
  # Zero out remaining bytes if string was short
  buf[i + ii++] = 0  while ii < 16
  buf

# **`unparse()` - Convert UUID byte array (ala parse()) into a string**
unparse = (buf, offset) ->
  i = offset or 0
  bth = _byteToHex
  bth[buf[i++]] + bth[buf[i++]] + bth[buf[i++]] + bth[buf[i++]] + "-" + bth[buf[i++]] + bth[buf[i++]] + "-" + bth[buf[i++]] + bth[buf[i++]] + "-" + bth[buf[i++]] + bth[buf[i++]] + "-" + bth[buf[i++]] + bth[buf[i++]] + bth[buf[i++]] + bth[buf[i++]] + bth[buf[i++]] + bth[buf[i++]]
uuidv5 = (data, ns) ->
  i = undefined
  v = undefined
  output = new Buffer(16)
  unless data
    i = 0
    while i < 16
      output[i] = 0
      i++
    return unparse(output)
  ns = parse(ns, new Buffer(16))  if typeof ns is "string"
  hash = crypto.createHash("sha1")
  hash.update ns or ""
  hash.update data or ""
  v = 0x50
  digest = hash.digest()
  if _.isString(digest)
    output.write digest, 0, 16, "binary"
  else digest.copy output  if _.isObject(digest) and digest instanceof Buffer
  output[8] = output[8] & 0x3f | 0xa0 # set variant
  output[6] = output[6] & 0x0f | v # set version
  unparse output
_ = require("underscore")
crypto = require("crypto")
_byteToHex = []
_hexToByte = {}
i = 0

while i < 256
  _byteToHex[i] = (i + 0x100).toString(16).substr(1)
  _hexToByte[_byteToHex[i]] = i
  i++
namespaces =
  DNS: "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
  URL: "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
  OID: "6ba7b812-9dad-11d1-80b4-00c04fd430c8"
  X500: "6ba7b814-9dad-11d1-80b4-00c04fd430c8"

module.exports = uuidv5
uuidv5.ns = namespaces
