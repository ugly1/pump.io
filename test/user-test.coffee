# user-test.js
#
# Test the user module
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
Activity = require("../lib/model/activity").Activity
modelBatch = require("./lib/model").modelBatch
Databank = databank.Databank
DatabankObject = databank.DatabankObject
suite = vows.describe("user module interface")
testSchema =
  pkey: "nickname"
  fields: [
    "_passwordHash"
    "email"
    "published"
    "updated"
    "profile"
  ]
  indices: [
    "profile.id"
    "email"
  ]

testData =
  create:
    nickname: "evan"
    password: "Quie3ien"
    profile:
      displayName: "Evan Prodromou"

  update:
    nickname: "evan"
    password: "correct horse battery staple" # the most secure password! see http://xkcd.com/936/


# XXX: hack hack hack
# modelBatch hard-codes ActivityObject-style
mb = modelBatch("user", "User", testSchema, testData)
mb["When we require the user module"]["and we get its User class export"]["and we create an user instance"]["auto-generated fields are there"] = (err, created) ->
  assert.isString created._passwordHash
  assert.isString created.published
  assert.isString created.updated
  return

mb["When we require the user module"]["and we get its User class export"]["and we create an user instance"]["passed-in fields are there"] = (err, created) ->
  _.each testData.create, (value, key) ->
    if key is "profile"
      _.each testData.create.profile, (value, key) ->
        assert.deepEqual created.profile[key], value
        return

    else
      assert.deepEqual created[key], value
    return

  return

suite.addBatch mb
suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it exists": (User) ->
    assert.isFunction User
    return

  "it has a fromPerson() method": (User) ->
    assert.isFunction User.fromPerson
    return

  "it has a checkCredentials() method": (User) ->
    assert.isFunction User.checkCredentials
    return

  "and we check the credentials for a non-existent user":
    topic: (User) ->
      cb = @callback
      User.checkCredentials "nosuchuser", "passw0rd", @callback
      return

    "it returns null": (err, found) ->
      assert.ifError err
      assert.isNull found
      return

  "and we create a user":
    topic: (User) ->
      props =
        nickname: "tom"
        password: "Xae3aiju"

      User.create props, @callback
      return

    teardown: (user) ->
      if user and user.del
        user.del (err) ->

      return

    "it works": (user) ->
      assert.isObject user
      return

    "it has the sanitize() method": (user) ->
      assert.isFunction user.sanitize
      return

    "it has the getProfile() method": (user) ->
      assert.isFunction user.getProfile
      return

    "it has the getOutboxStream() method": (user) ->
      assert.isFunction user.getOutboxStream
      return

    "it has the getInboxStream() method": (user) ->
      assert.isFunction user.getInboxStream
      return

    "it has the getMajorOutboxStream() method": (user) ->
      assert.isFunction user.getMajorOutboxStream
      return

    "it has the getMajorInboxStream() method": (user) ->
      assert.isFunction user.getMajorInboxStream
      return

    "it has the getMinorOutboxStream() method": (user) ->
      assert.isFunction user.getMinorOutboxStream
      return

    "it has the getMinorInboxStream() method": (user) ->
      assert.isFunction user.getMinorInboxStream
      return

    "it has the getDirectInboxStream() method": (user) ->
      assert.isFunction user.getDirectInboxStream
      return

    "it has the getMinorDirectInboxStream() method": (user) ->
      assert.isFunction user.getMinorDirectInboxStream
      return

    "it has the getMajorDirectInboxStream() method": (user) ->
      assert.isFunction user.getMajorDirectInboxStream
      return

    "it has the getDirectMinorInboxStream() method": (user) ->
      assert.isFunction user.getDirectMinorInboxStream
      return

    "it has the getDirectMajorInboxStream() method": (user) ->
      assert.isFunction user.getDirectMajorInboxStream
      return

    "it has the getLists() method": (user) ->
      assert.isFunction user.getLists
      return

    "it has the expand() method": (user) ->
      assert.isFunction user.expand
      return

    "it has the addToOutbox() method": (user) ->
      assert.isFunction user.addToOutbox
      return

    "it has the addToInbox() method": (user) ->
      assert.isFunction user.addToInbox
      return

    "it has the getFollowers() method": (user) ->
      assert.isFunction user.getFollowers
      return

    "it has the getFollowing() method": (user) ->
      assert.isFunction user.getFollowing
      return

    "it has the followerCount() method": (user) ->
      assert.isFunction user.followerCount
      return

    "it has the followingCount() method": (user) ->
      assert.isFunction user.followingCount
      return

    "it has the follow() method": (user) ->
      assert.isFunction user.follow
      return

    "it has the stopFollowing() method": (user) ->
      assert.isFunction user.stopFollowing
      return

    "it has the addFollower() method": (user) ->
      assert.isFunction user.addFollower
      return

    "it has the addFollowing() method": (user) ->
      assert.isFunction user.addFollowing
      return

    "it has the removeFollower() method": (user) ->
      assert.isFunction user.removeFollower
      return

    "it has the removeFollowing() method": (user) ->
      assert.isFunction user.removeFollowing
      return

    "it has the addToFavorites() method": (user) ->
      assert.isFunction user.addToFavorites
      return

    "it has the removeFromFavorites() method": (user) ->
      assert.isFunction user.removeFromFavorites
      return

    "it has the favoritesStream() method": (user) ->
      assert.isFunction user.favoritesStream
      return

    "it has the uploadsStream() method": (user) ->
      assert.isFunction user.uploadsStream
      return

    "it has the followingStream() method": (user) ->
      assert.isFunction user.followingStream
      return

    "it has the followersStream() method": (user) ->
      assert.isFunction user.followersStream
      return

    "it has a profile attribute": (user) ->
      assert.isObject user.profile
      assert.instanceOf user.profile, require("../lib/model/person").Person
      assert.isString user.profile.id
      return

    "and we check the credentials with the right password":
      topic: (user, User) ->
        User.checkCredentials "tom", "Xae3aiju", @callback
        return

      "it works": (err, user) ->
        assert.ifError err
        assert.isObject user
        return

    "and we check the credentials with the wrong password":
      topic: (user, User) ->
        cb = @callback
        User.checkCredentials "tom", "654321", @callback
        return

      "it returns null": (err, found) ->
        assert.ifError err
        assert.isNull found
        return

    "and we try to retrieve it from the person id":
      topic: (user, User) ->
        User.fromPerson user.profile.id, @callback
        return

      "it works": (err, found) ->
        assert.ifError err
        assert.isObject found
        assert.equal found.nickname, "tom"
        return

    "and we try to get its profile":
      topic: (user) ->
        user.getProfile @callback
        return

      "it works": (err, profile) ->
        assert.ifError err
        assert.isObject profile
        assert.instanceOf profile, require("../lib/model/person").Person
        return

  "and we create a user and sanitize it":
    topic: (User) ->
      cb = @callback
      props =
        nickname: "dick"
        password: "Aaf7Ieki"

      User.create props, (err, user) ->
        if err
          cb err, null
        else
          user.sanitize()
          cb null, user
        return

      return

    teardown: (user) ->
      if user
        user.del (err) ->

      return

    "it works": (err, user) ->
      assert.ifError err
      assert.isObject user
      return

    "it is sanitized": (err, user) ->
      assert.isFalse _(user).has("password")
      assert.isFalse _(user).has("_passwordHash")
      return

  "and we create a new user and get its stream":
    topic: (User) ->
      cb = @callback
      user = null
      props =
        nickname: "harry"
        password: "Ai9AhSha"

      Step (->
        User.create props, this
        return
      ), ((err, results) ->
        throw err  if err
        user = results
        user.getOutboxStream this
        return
      ), ((err, outbox) ->
        throw err  if err
        outbox.getIDs 0, 20, this
        return
      ), ((err, ids) ->
        throw err  if err
        Activity.readArray ids, this
        return
      ), (err, activities) ->
        if err
          cb err, null
        else
          cb err,
            user: user
            activities: activities

        return

      return

    teardown: (results) ->
      if results
        results.user.del (err) ->

      return

    "it works": (err, results) ->
      assert.ifError err
      assert.isObject results.user
      assert.isArray results.activities
      return

    "it is empty": (err, results) ->
      assert.lengthOf results.activities, 0
      return

    "and we add an activity to its stream":
      topic: (results) ->
        cb = @callback
        user = results.user
        props =
          verb: "checkin"
          object:
            objectType: "place"
            displayName: "Les Folies"
            url: "http://nominatim.openstreetmap.org/details.php?place_id=5001033"
            position: "+45.5253965-73.5818537/"
            address:
              streetAddress: "701 Mont-Royal Est"
              locality: "Montreal"
              region: "Quebec"
              postalCode: "H2J 2T5"

        Activity = require("../lib/model/activity").Activity
        act = new Activity(props)
        Step (->
          act.apply user.profile, this
          return
        ), ((err) ->
          throw err  if err
          act.save this
          return
        ), ((err) ->
          throw err  if err
          user.addToOutbox act, this
          return
        ), (err) ->
          if err
            cb err, null
          else
            cb null,
              user: user
              activity: act

          return

        return

      "it works": (err, results) ->
        assert.ifError err
        return

      "and we get the user stream":
        topic: (results) ->
          cb = @callback
          user = results.user
          activity = results.activity
          Step (->
            user.getOutboxStream this
            return
          ), ((err, outbox) ->
            throw err  if err
            outbox.getIDs 0, 20, this
            return
          ), ((err, ids) ->
            throw err  if err
            Activity.readArray ids, this
            return
          ), (err, activities) ->
            if err
              cb err, null
            else
              cb null,
                user: user
                activity: activity
                activities: activities

            return

          return

        "it works": (err, results) ->
          assert.ifError err
          assert.isArray results.activities
          return

        "it includes the added activity": (err, results) ->
          assert.lengthOf results.activities, 1
          assert.equal results.activities[0].id, results.activity.id
          return

  "and we create a new user and get its lists stream":
    topic: (User) ->
      props =
        nickname: "gary"
        password: "eiFoT2Va"

      Step (->
        User.create props, this
        return
      ), ((err, user) ->
        throw err  if err
        user.getLists "person", this
        return
      ), @callback
      return

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream
      return

    "and we get the count of lists":
      topic: (stream) ->
        stream.count @callback
        return

      "it is zero": (err, count) ->
        assert.ifError err
        assert.equal count, 0
        return

    "and we get the first few lists":
      topic: (stream) ->
        stream.getItems 0, 20, @callback
        return

      "it is an empty list": (err, ids) ->
        assert.ifError err
        assert.isArray ids
        assert.lengthOf ids, 0
        return

  "and we create a new user and get its galleries stream":
    topic: (User) ->
      props =
        nickname: "chumwick"
        password: "eiFoT2Va"

      Step (->
        User.create props, this
        return
      ), ((err, user) ->
        throw err  if err
        user.getLists "image", this
        return
      ), @callback
      return

    "it works": (err, stream) ->
      assert.ifError err
      assert.isObject stream
      return

    "and we get the count of lists":
      topic: (stream) ->
        stream.count @callback
        return

      "it is five": (err, count) ->
        assert.ifError err
        assert.equal count, 1
        return

    "and we get the first few lists":
      topic: (stream) ->
        stream.getItems 0, 20, @callback
        return

      "it is a single-element list": (err, ids) ->
        assert.ifError err
        assert.isArray ids
        assert.lengthOf ids, 1
        return

  "and we create a new user and get its inbox":
    topic: (User) ->
      cb = @callback
      user = null
      props =
        nickname: "maurice"
        password: "cappadoccia1"

      Step (->
        User.create props, this
        return
      ), ((err, results) ->
        throw err  if err
        user = results
        user.getInboxStream this
        return
      ), ((err, inbox) ->
        throw err  if err
        inbox.getIDs 0, 20, this
        return
      ), ((err, ids) ->
        throw err  if err
        Activity.readArray ids, this
        return
      ), (err, activities) ->
        if err
          cb err, null
        else
          cb err,
            user: user
            activities: activities

        return

      return

    teardown: (results) ->
      if results
        results.user.del (err) ->

      return

    "it works": (err, results) ->
      assert.ifError err
      assert.isObject results.user
      assert.isArray results.activities
      return

    "it is empty": (err, results) ->
      assert.lengthOf results.activities, 0
      return

    "and we add an activity to its inbox":
      topic: (results) ->
        cb = @callback
        user = results.user
        props =
          actor:
            id: "urn:uuid:8f7be1de-3f48-4a54-bf3f-b4fc18f3ae77"
            objectType: "person"
            displayName: "Abraham Lincoln"

          verb: "post"
          object:
            objectType: "note"
            content: "Remember to get eggs, bread, and milk."

        Activity = require("../lib/model/activity").Activity
        act = new Activity(props)
        Step (->
          act.apply user.profile, this
          return
        ), ((err) ->
          throw err  if err
          act.save this
          return
        ), ((err) ->
          throw err  if err
          user.addToInbox act, this
          return
        ), (err) ->
          if err
            cb err, null
          else
            cb null,
              user: user
              activity: act

          return

        return

      "it works": (err, results) ->
        assert.ifError err
        return

      "and we get the user inbox":
        topic: (results) ->
          cb = @callback
          user = results.user
          activity = results.activity
          Step (->
            user.getInboxStream this
            return
          ), ((err, inbox) ->
            throw err  if err
            inbox.getIDs 0, 20, this
            return
          ), ((err, ids) ->
            throw err  if err
            Activity.readArray ids, this
            return
          ), (err, activities) ->
            if err
              cb err, null
            else
              cb null,
                user: user
                activity: activity
                activities: activities

            return

          return

        "it works": (err, results) ->
          assert.ifError err
          assert.isArray results.activities
          return

        "it includes the added activity": (err, results) ->
          assert.lengthOf results.activities, 1
          assert.equal results.activities[0].id, results.activity.id
          return

  "and we create a pair of users":
    topic: (User) ->
      cb = @callback
      Step (->
        User.create
          nickname: "shields"
          password: "1walk1nTheWind"
        , @parallel()
        User.create
          nickname: "yarnell"
          password: "1Mpull1ngArope"
        , @parallel()
        return
      ), (err, shields, yarnell) ->
        if err
          cb err, null
        else
          cb null,
            shields: shields
            yarnell: yarnell

        return

      return

    "it works": (err, users) ->
      assert.ifError err
      return

    "and we make one follow the other":
      topic: (users) ->
        users.shields.follow users.yarnell, @callback
        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we check the first user's following list":
        topic: (users) ->
          cb = @callback
          users.shields.getFollowing 0, 20, (err, following) ->
            cb err, following, users.yarnell
            return

          return

        "it works": (err, following, other) ->
          assert.ifError err
          assert.isArray following
          return

        "it is the right size": (err, following, other) ->
          assert.ifError err
          assert.lengthOf following, 1
          return

        "it has the right data": (err, following, other) ->
          assert.ifError err
          assert.equal following[0].id, other.profile.id
          return

      "and we check the first user's following count":
        topic: (users) ->
          users.shields.followingCount @callback
          return

        "it works": (err, fc) ->
          assert.ifError err
          return

        "it is correct": (err, fc) ->
          assert.ifError err
          assert.equal fc, 1
          return

      "and we check the second user's followers list":
        topic: (users) ->
          cb = @callback
          users.yarnell.getFollowers 0, 20, (err, following) ->
            cb err, following, users.shields
            return

          return

        "it works": (err, followers, other) ->
          assert.ifError err
          assert.isArray followers
          return

        "it is the right size": (err, followers, other) ->
          assert.ifError err
          assert.lengthOf followers, 1
          return

        "it has the right data": (err, followers, other) ->
          assert.ifError err
          assert.equal followers[0].id, other.profile.id
          return

      "and we check the second user's followers count":
        topic: (users) ->
          users.yarnell.followerCount @callback
          return

        "it works": (err, fc) ->
          assert.ifError err
          return

        "it is correct": (err, fc) ->
          assert.ifError err
          assert.equal fc, 1
          return

  "and we create another pair of users following":
    topic: (User) ->
      cb = @callback
      users = {}
      Step (->
        User.create
          nickname: "captain"
          password: "b34chboyW/AHat"
        , @parallel()
        User.create
          nickname: "tenille"
          password: "Muskr4t|Sus13"
        , @parallel()
        return
      ), ((err, captain, tenille) ->
        throw err  if err
        users.captain = captain
        users.tenille = tenille
        captain.follow tenille, this
        return
      ), ((err) ->
        throw err  if err
        users.captain.stopFollowing users.tenille, this
        return
      ), (err) ->
        if err
          cb err, null
        else
          cb null, users
        return

      return

    "it works": (err, users) ->
      assert.ifError err
      return

    "and we check the first user's following list":
      topic: (users) ->
        cb = @callback
        users.captain.getFollowing 0, 20, @callback
        return

      "it works": (err, following, other) ->
        assert.ifError err
        assert.isArray following
        return

      "it is the right size": (err, following, other) ->
        assert.ifError err
        assert.lengthOf following, 0
        return

    "and we check the first user's following count":
      topic: (users) ->
        users.captain.followingCount @callback
        return

      "it works": (err, fc) ->
        assert.ifError err
        return

      "it is correct": (err, fc) ->
        assert.ifError err
        assert.equal fc, 0
        return

    "and we check the second user's followers list":
      topic: (users) ->
        users.tenille.getFollowers 0, 20, @callback
        return

      "it works": (err, followers, other) ->
        assert.ifError err
        assert.isArray followers
        return

      "it is the right size": (err, followers, other) ->
        assert.ifError err
        assert.lengthOf followers, 0
        return

    "and we check the second user's followers count":
      topic: (users) ->
        users.tenille.followerCount @callback
        return

      "it works": (err, fc) ->
        assert.ifError err
        return

      "it is correct": (err, fc) ->
        assert.ifError err
        assert.equal fc, 0
        return

  "and one user follows another twice":
    topic: (User) ->
      cb = @callback
      users = {}
      Step (->
        User.create
          nickname: "boris"
          password: "squirrel"
        , @parallel()
        User.create
          nickname: "natasha"
          password: "moose"
        , @parallel()
        return
      ), ((err, boris, natasha) ->
        throw err  if err
        users.boris = boris
        users.natasha = natasha
        users.boris.follow users.natasha, this
        return
      ), ((err) ->
        throw err  if err
        users.boris.follow users.natasha, this
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

  "and one user stops following a user they never followed":
    topic: (User) ->
      cb = @callback
      users = {}
      Step (->
        User.create
          nickname: "rocky"
          password: "flying"
        , @parallel()
        User.create
          nickname: "bullwinkle"
          password: "rabbit"
        , @parallel()
        return
      ), ((err, rocky, bullwinkle) ->
        throw err  if err
        users.rocky = rocky
        users.bullwinkle = bullwinkle
        users.rocky.stopFollowing users.bullwinkle, this
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

  "and we create a bunch of users":
    topic: (User) ->
      cb = @callback
      MAX_USERS = 50
      Step (->
        i = undefined
        group = @group()
        i = 0
        while i < MAX_USERS
          User.create
            nickname: "clown" + i
            password: "Ha6quo6I" + i
          , group()
          i++
        return
      ), (err, users) ->
        if err
          cb err, null
        else
          cb null, users
        return

      return

    "it works": (err, users) ->
      assert.ifError err
      assert.isArray users
      assert.lengthOf users, 50
      return

    "and they all follow someone":
      topic: (users) ->
        cb = @callback
        MAX_USERS = 50
        Step (->
          i = undefined
          group = @group()
          i = 1
          while i < users.length
            users[i].follow users[0], group()
            i++
          return
        ), (err) ->
          cb err
          return

        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we check the followed user's followers list":
        topic: (users) ->
          users[0].getFollowers 0, users.length + 1, @callback
          return

        "it works": (err, followers) ->
          assert.ifError err
          assert.isArray followers
          assert.lengthOf followers, 49
          return

      "and we check the followed user's followers count":
        topic: (users) ->
          users[0].followerCount @callback
          return

        "it works": (err, fc) ->
          assert.ifError err
          return

        "it is correct": (err, fc) ->
          assert.ifError err
          assert.equal fc, 49
          return

      "and we check the following users' following lists":
        topic: (users) ->
          cb = @callback
          MAX_USERS = 50
          Step (->
            i = undefined
            group = @group()
            i = 1
            while i < users.length
              users[i].getFollowing 0, 20, group()
              i++
            return
          ), cb
          return

        "it works": (err, lists) ->
          i = undefined
          assert.ifError err
          assert.isArray lists
          assert.lengthOf lists, 49
          i = 0
          while i < lists.length
            assert.isArray lists[i]
            assert.lengthOf lists[i], 1
            i++
          return

      "and we check the following users' following counts":
        topic: (users) ->
          cb = @callback
          MAX_USERS = 50
          Step (->
            i = undefined
            group = @group()
            i = 1
            while i < users.length
              users[i].followingCount group()
              i++
            return
          ), cb
          return

        "it works": (err, counts) ->
          i = undefined
          assert.ifError err
          assert.isArray counts
          assert.lengthOf counts, 49
          i = 0
          while i < counts.length
            assert.equal counts[i], 1
            i++
          return

emptyStreamContext = (streamgetter) ->
  topic: (user) ->
    callback = @callback
    Step (->
      streamgetter user, this
      return
    ), ((err, str) ->
      throw err  if err
      str.getIDs 0, 20, this
      return
    ), callback
    return

  "it's empty": (err, activities) ->
    assert.ifError err
    assert.isEmpty activities
    return

streamCountContext = (streamgetter, targetCount) ->
  ctx = topic: (act, user) ->
    callback = @callback
    Step (->
      streamgetter user, this
      return
    ), ((err, str) ->
      throw err  if err
      str.getIDs 0, 20, this
      return
    ), (err, activities) ->
      callback err, act, activities
      return

    return

  label = (if (targetCount > 0) then "it's in there" else "it's not in there")
  ctx[label] = (err, act, activities) ->
    matches = undefined
    assert.ifError err
    assert.isObject act
    assert.isArray activities
    matches = activities.filter((item) ->
      item is act.id
    )
    assert.lengthOf matches, targetCount
    return

  ctx

inStreamContext = (streamgetter) ->
  streamCountContext streamgetter, 1

notInStreamContext = (streamgetter) ->
  streamCountContext streamgetter, 0


# Tests for major, minor streams
suite.addBatch
  "When we create a new user":
    topic: ->
      User = require("../lib/model/user").User
      props =
        nickname: "archie"
        password: "B0Y|the/way|Glenn+Miller|played"

      User.create props, @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we check their minor inbox": emptyStreamContext((user, callback) ->
      user.getMinorInboxStream callback
      return
    )
    "and we check their minor outbox": emptyStreamContext((user, callback) ->
      user.getMinorOutboxStream callback
      return
    )
    "and we check their major inbox": emptyStreamContext((user, callback) ->
      user.getMajorInboxStream callback
      return
    )
    "and we check their major inbox": emptyStreamContext((user, callback) ->
      user.getMajorOutboxStream callback
      return
    )

  "When we create another user":
    topic: ->
      User = require("../lib/model/user").User
      props =
        nickname: "edith"
        password: "s0ngz|that|made|Th3|h1t|P4r4de"

      User.create props, @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we add a major activity":
      topic: (user) ->
        act = undefined
        props =
          actor: user.profile
          verb: "post"
          object:
            objectType: "note"
            content: "Cling peaches"

        callback = @callback
        Step (->
          Activity.create props, this
          return
        ), ((err, result) ->
          throw err  if err
          act = result
          user.addToInbox act, @parallel()
          user.addToOutbox act, @parallel()
          return
        ), (err) ->
          if err
            callback err, null, null
          else
            callback null, act, user
          return

        return

      "it works": (err, activity, user) ->
        assert.ifError err
        return

      "and we check their minor inbox": notInStreamContext((user, callback) ->
        user.getMinorInboxStream callback
        return
      )
      "and we check their minor outbox": notInStreamContext((user, callback) ->
        user.getMinorOutboxStream callback
        return
      )
      "and we check their major inbox": inStreamContext((user, callback) ->
        user.getMajorInboxStream callback
        return
      )
      "and we check their major outbox": inStreamContext((user, callback) ->
        user.getMajorOutboxStream callback
        return
      )

  "When we create yet another user":
    topic: ->
      User = require("../lib/model/user").User
      props =
        nickname: "gloria"
        password: "0h,d4DDY!"

      User.create props, @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we add a minor activity":
      topic: (user) ->
        act = undefined
        props =
          actor: user.profile
          verb: "favorite"
          object:
            objectType: "image"
            id: "3740ed6e-fa2b-11e1-9287-70f1a154e1aa"

        callback = @callback
        Step (->
          Activity.create props, this
          return
        ), ((err, result) ->
          throw err  if err
          act = result
          user.addToInbox act, @parallel()
          user.addToOutbox act, @parallel()
          return
        ), (err) ->
          if err
            callback err, null, null
          else
            callback null, act, user
          return

        return

      "it works": (err, activity, user) ->
        assert.ifError err
        return

      "and we check their minor inbox": inStreamContext((user, callback) ->
        user.getMinorInboxStream callback
        return
      )
      "and we check their minor outbox": inStreamContext((user, callback) ->
        user.getMinorOutboxStream callback
        return
      )
      "and we check their major inbox": notInStreamContext((user, callback) ->
        user.getMajorInboxStream callback
        return
      )
      "and we check their major outbox": notInStreamContext((user, callback) ->
        user.getMajorOutboxStream callback
        return
      )


# Test user nickname rules
goodNickname = (nickname) ->
  topic: ->
    User = require("../lib/model/user").User
    props =
      nickname: nickname
      password: "Kei1goos"

    User.create props, @callback
    return

  "it works": (err, user) ->
    assert.ifError err
    assert.isObject user
    return

  "the nickname is correct": (err, user) ->
    assert.ifError err
    assert.isObject user
    assert.equal nickname, user.nickname
    return

badNickname = (nickname) ->
  topic: ->
    User = require("../lib/model/user").User
    props =
      nickname: nickname
      password: "AQuah5co"

    callback = @callback
    User.create props, (err, user) ->
      if err and err instanceof User.BadNicknameError
        callback null
      else
        callback new Error("Unexpected success")
      return

    return

  "it fails correctly": (err) ->
    assert.ifError err
    return

suite.addBatch
  "When we create a new user with a long nickname less than 64 chars": goodNickname("james_james_morrison_morrison_weatherby_george_dupree")
  "When we create a user with a nickname with a -": goodNickname("captain-caveman")
  "When we create a user with a nickname with a _": goodNickname("captain_caveman")
  "When we create a user with a nickname with a .": goodNickname("captain.caveman")
  "When we create a user with a nickname with capital letters": goodNickname("CaptainCaveman")
  "When we create a user with a nickname with one char": goodNickname("c")
  "When we create a new user with a nickname longer than 64 chars": badNickname("adolphblainecharlesdavidearlfrederickgeraldhubertirvimjohn" + "kennethloydmartinnerooliverpaulquincyrandolphshermanthomasuncas" + "victorwillianxerxesyancyzeus")
  "When we create a new user with a nickname with a forbidden character": badNickname("arnold/palmer")
  "When we create a new user with a nickname with a blank": badNickname("Captain Caveman")
  "When we create a new user with an empty nickname": badNickname("")
  "When we create a new user with nickname 'api'": badNickname("api")
  "When we create a new user with nickname 'oauth'": badNickname("oauth")

activityMakerContext = (maker, rest) ->
  ctx =
    topic: (toUser, fromUser) ->
      Activity = require("../lib/model/activity").Activity
      callback = @callback
      theAct = undefined
      Step (->
        act = maker(toUser, fromUser)
        Activity.create act, this
        return
      ), ((err, act) ->
        throw err  if err
        theAct = act
        toUser.addToInbox act, this
        return
      ), (err) ->
        callback err, theAct
        return

      return

    "it works": (err, act) ->
      assert.ifError err
      assert.isObject act
      return

  _.extend ctx, rest
  ctx


# Tests for direct, direct-major, and direct-minor streams
suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it works": (User) ->
    assert.isFunction User
    return

  "and we create a new user":
    topic: (User) ->
      props =
        nickname: "george"
        password: "moving-on-up"

      User.create props, @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we check their direct inbox": emptyStreamContext((user, callback) ->
      user.getDirectInboxStream callback
      return
    )
    "and we check their direct minor inbox": emptyStreamContext((user, callback) ->
      user.getMinorDirectInboxStream callback
      return
    )
    "and we check their direct major inbox": emptyStreamContext((user, callback) ->
      user.getMajorDirectInboxStream callback
      return
    )

  "and we create a pair of users":
    topic: (User) ->
      props1 =
        nickname: "louise"
        password: "moving-on-up2"

      props2 =
        nickname: "florence"
        password: "maid/up1"

      Step (->
        User.create props2, @parallel()
        User.create props1, @parallel()
        return
      ), @callback
      return

    "it works": (err, toUser, fromUser) ->
      assert.ifError err
      assert.isObject fromUser
      assert.isObject toUser
      return

    "and one user sends a major activity to the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      to: [toUser.profile]
      verb: "post"
      object:
        objectType: "note"
        content: "Please get the door"
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the recipient's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the recipient's direct major inbox": inStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )
    "and one user sends a minor activity to the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      to: [toUser.profile]
      verb: "favorite"
      object:
        id: "urn:uuid:c6591278-0418-11e2-ade3-70f1a154e1aa"
        objectType: "audio"
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the recipient's direct minor inbox": inStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the recipient's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )
    "and one user sends a major activity bto the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      bto: [toUser.profile]
      verb: "post"
      object:
        objectType: "note"
        content: "Please wash George's underwear."
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the recipient's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the recipient's direct major inbox": inStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )
    "and one user sends a minor activity bto the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      bto: [toUser.profile]
      verb: "favorite"
      object:
        id: "urn:uuid:5982b964-0414-11e2-8ced-70f1a154e1aa"
        objectType: "service"
    ,
      "and we check the recipient's direct inbox": inStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the recipient's direct minor inbox": inStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the recipient's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )
    "and one user sends a minor activity to the public": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      to: [
        id: "http://activityschema.org/collection/public"
        objectType: "collection"
      ]
      verb: "favorite"
      object:
        id: "urn:uuid:0e6b0f90-0413-11e2-84fb-70f1a154e1aa"
        objectType: "video"
    ,
      "and we check the other user's direct inbox": notInStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the other user's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the other user's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )
    "and one user sends a major activity and cc's the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      cc: [toUser.profile]
      verb: "post"
      object:
        id: "I'm tired."
        objectType: "note"
    ,
      "and we check the other user's direct inbox": notInStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the other user's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the other user's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )
    "and one user sends a major activity and bcc's the other": activityMakerContext((toUser, fromUser) ->
      actor: fromUser.profile
      bcc: [toUser.profile]
      verb: "post"
      object:
        id: "It's hot."
        objectType: "note"
    ,
      "and we check the other user's direct inbox": notInStreamContext((user, callback) ->
        user.getDirectInboxStream callback
        return
      )
      "and we check the other user's direct minor inbox": notInStreamContext((user, callback) ->
        user.getDirectMinorInboxStream callback
        return
      )
      "and we check the other user's direct major inbox": notInStreamContext((user, callback) ->
        user.getDirectMajorInboxStream callback
        return
      )
    )

suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it works": (User) ->
    assert.isFunction User
    return

  "and we create a new user":
    topic: (User) ->
      props =
        nickname: "whatever"
        password: "no-energy"

      User.create props, @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we check their direct inbox": emptyStreamContext((user, callback) ->
      user.uploadsStream callback
      return
    )


# Test followersStream, followingStream
suite.addBatch "When we get the User class":
  topic: ->
    require("../lib/model/user").User

  "it works": (User) ->
    assert.isFunction User
    return

  "and we create a new user":
    topic: (User) ->
      props =
        nickname: "booboo"
        password: "my-daughters-furbie"

      User.create props, @callback
      return

    "it works": (err, user) ->
      assert.ifError err
      return

    "and we check their following stream": emptyStreamContext((user, callback) ->
      user.followingStream callback
      return
    )
    "and we check their followers stream": emptyStreamContext((user, callback) ->
      user.followersStream callback
      return
    )

suite["export"] module
