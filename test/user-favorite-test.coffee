# user-favorite-test.js
#
# Test the user favoriting mechanism
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
assert = require("assert")
vows = require("vows")
databank = require("databank")
_ = require("underscore")
Step = require("step")
fs = require("fs")
path = require("path")
schema = require("../lib/schema").schema
URLMaker = require("../lib/urlmaker").URLMaker
Databank = databank.Databank
DatabankObject = databank.DatabankObject
a2m = (arr, prop) ->
  i = undefined
  map = {}
  key = undefined
  value = undefined
  i = 0
  while i < arr.length
    value = arr[i]
    key = value[prop]
    map[key] = value
    i++
  map

suite = vows.describe("user favorite interface")
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite.addBatch "When we get the User class":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      User = undefined
      DatabankObject.bank = db
      User = require("../lib/model/user").User or null
      cb null, User
      return

    return

  "it exists": (User) ->
    assert.isFunction User
    return

  "and we create a user":
    topic: (User) ->
      props =
        nickname: "bert"
        password: "p1dgeons"

      User.create props, @callback
      return

    teardown: (user) ->
      if user and user.del
        user.del (err) ->

      return

    "it works": (user) ->
      assert.isObject user
      return

    "and it favorites a known object":
      topic: (user) ->
        cb = @callback
        Image = require("../lib/model/image").Image
        obj = undefined
        Step (->
          Image.create
            displayName: "Courage Wolf"
            url: "http://i0.kym-cdn.com/photos/images/newsfeed/000/159/986/Couragewolf1.jpg"
          , this
          return
        ), ((err, image) ->
          throw err  if err
          obj = image
          user.addToFavorites image, this
          return
        ), (err) ->
          if err
            cb err, null
          else
            cb err, obj
          return

        return

      "it works": (err, image) ->
        assert.ifError err
        return

      "and it unfavorites that object":
        topic: (image, user) ->
          user.removeFromFavorites image, @callback
          return

        "it works": (err) ->
          assert.ifError err
          return

    "and it favorites an unknown object":
      topic: (user) ->
        cb = @callback
        user.addToFavorites
          id: "urn:uuid:5be685ef-f50b-458b-bfd3-3ca004eb0e89"
          objectType: "image"
        , @callback
        return

      "it works": (err) ->
        assert.ifError err
        return

      "and it unfavorites that object":
        topic: (user) ->
          user.removeFromFavorites
            id: "urn:uuid:5be685ef-f50b-458b-bfd3-3ca004eb0e89"
            objectType: "image"
          , @callback
          return

        "it works": (err) ->
          assert.ifError err
          return

    "and it unfavorites an object it never favorited":
      topic: (user) ->
        cb = @callback
        Audio = require("../lib/model/audio").Audio
        Step (->
          Audio.create
            displayName: "Spock"
            url: "http://musicbrainz.org/recording/c1038685-49f3-45d7-bb26-1372f1052126"
          , this
          return
        ), ((err, audio) ->
          throw err  if err
          user.removeFromFavorites audio, this
          return
        ), (err) ->
          if err
            cb null
          else
            cb new Error("Unexpected success")
          return

        return

      "it fails correctly": (err) ->
        assert.ifError err
        return

  "and we get the stream of favorites for a new user":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "shambler"
        password: "grey|skull1"

      Step (->
        User.create props, this
        return
      ), ((err, user) ->
        throw err  if err
        user.favoritesStream this
        return
      ), (err, stream) ->
        if err
          cb err, null
        else
          cb null, stream
        return

      return

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream
      return

  "and we get the list of favorites for a new user":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "carroway"
        password: "feld,spar"

      Step (->
        User.create props, this
        return
      ), ((err, user) ->
        throw err  if err
        user.getFavorites 0, 20, this
        return
      ), (err, faves) ->
        if err
          cb err, null
        else
          cb null, faves
        return

      return

    "it works": (err, faves) ->
      assert.ifError err
      return

    "it looks right": (err, faves) ->
      assert.ifError err
      assert.isArray faves
      assert.lengthOf faves, 0
      return

  "and we get the count of favorites for a new user":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "cookie"
        password: "cookies!"

      Step (->
        User.create props, this
        return
      ), ((err, user) ->
        throw err  if err
        user.favoritesCount this
        return
      ), (err, count) ->
        if err
          cb err, null
        else
          cb null, count
        return

      return

    "it works": (err, count) ->
      assert.ifError err
      return

    "it looks right": (err, count) ->
      assert.ifError err
      assert.equal count, 0
      return

  "and a new user favors an object":
    topic: (User) ->
      cb = @callback
      user = undefined
      image = undefined
      Step (->
        User.create
          nickname: "ernie"
          password: "rubber duckie"
        , this
        return
      ), ((err, results) ->
        Image = require("../lib/model/image").Image
        throw err  if err
        user = results
        Image.create
          displayName: "Evan's avatar"
          url: "https://c778552.ssl.cf2.rackcdn.com/evan/1-96-20120103014637.jpeg"
        , this
        return
      ), ((err, results) ->
        throw err  if err
        image = results
        user.addToFavorites image, this
        return
      ), (err) ->
        if err
          cb err, null, null
        else
          cb null, user, image
        return

      return

    "it works": (err, user, image) ->
      assert.ifError err
      assert.isObject user
      assert.isObject image
      return

    "and we check the user favorites list":
      topic: (user, image) ->
        cb = @callback
        user.getFavorites 0, 20, (err, faves) ->
          cb err, faves, image
          return

        return

      "it works": (err, faves, image) ->
        assert.ifError err
        return

      "it is the right size": (err, faves, image) ->
        assert.ifError err
        assert.lengthOf faves, 1
        return

      "it has the right data": (err, faves, image) ->
        assert.ifError err
        assert.equal faves[0].id, image.id
        return

    "and we check the user favorites count":
      topic: (user, image) ->
        cb = @callback
        user.favoritesCount cb
        return

      "it works": (err, count) ->
        assert.ifError err
        return

      "it is correct": (err, count) ->
        assert.ifError err
        assert.equal count, 1
        return

  "and a new user favors a lot of objects":
    topic: (User) ->
      cb = @callback
      user = undefined
      images = undefined
      Step (->
        User.create
          nickname: "count"
          password: "one,two,three,four"
        , this
        return
      ), ((err, results) ->
        Image = require("../lib/model/image").Image
        i = 0
        group = @group()
        throw err  if err
        user = results
        i = 0
        while i < 5000
          Image.create
            displayName: "Image for #" + i
            increment: i
            url: "http://" + i + ".jpg.to"
          , group()
          i++
        return
      ), ((err, results) ->
        i = 0
        group = @group()
        throw err  if err
        images = results
        i = 0
        while i < images.length
          user.addToFavorites images[i], group()
          i++
        return
      ), (err) ->
        if err
          cb err, null, null
        else
          cb null, user, images
        return

      return

    "it works": (err, user, images) ->
      assert.ifError err
      assert.isObject user
      assert.isArray images
      assert.lengthOf images, 5000
      i = 0

      while i < images.length
        assert.isObject images[i]
        i++
      return

    "and we check the user favorites list":
      topic: (user, images) ->
        cb = @callback
        user.getFavorites 0, 5001, (err, faves) ->
          cb err, faves, images
          return

        return

      "it works": (err, faves, images) ->
        assert.ifError err
        return

      "it is the right size": (err, faves, images) ->
        assert.ifError err
        assert.lengthOf faves, 5000
        return

      "it has the right data": (err, faves, images) ->
        fm = undefined
        im = undefined
        id = undefined
        assert.ifError err
        fm = a2m(faves, "id")
        im = a2m(images, "id")
        for id of im
          assert.include fm, id
        for id of fm
          assert.include im, id
        return

    "and we check the user favorites count":
      topic: (user, image) ->
        cb = @callback
        user.favoritesCount cb
        return

      "it works": (err, count) ->
        assert.ifError err
        return

      "it is correct": (err, count) ->
        assert.ifError err
        assert.equal count, 5000
        return

suite["export"] module
