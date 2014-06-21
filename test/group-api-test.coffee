# group-api-test.js
#
# Test group API
#
# Copyright 2013, E14N https://e14n.com/
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
Step = require("step")
_ = require("underscore")
http = require("http")
urlparse = require("url").parse
httputil = require("./lib/http")
oauthutil = require("./lib/oauth")
actutil = require("./lib/activity")
pj = httputil.postJSON
gj = httputil.getJSON
validActivity = actutil.validActivity
validActivityObject = actutil.validActivityObject
validFeed = actutil.validFeed
setupApp = oauthutil.setupApp
newCredentials = oauthutil.newCredentials
newClient = oauthutil.newClient
newPair = oauthutil.newPair
suite = vows.describe("Group API test")
makeCred = (cl, pair) ->
  consumer_key: cl.client_id
  consumer_secret: cl.client_secret
  token: pair.token
  token_secret: pair.token_secret
  user: pair.user


# A batch for manipulating groups API
suite.addBatch "When we set up the app":
  topic: ->
    setupApp @callback
    return

  teardown: (app) ->
    app.close()  if app and app.close
    return

  "it works": (err, app) ->
    assert.ifError err
    return

  "and we make a new user":
    topic: ->
      newCredentials "fafhrd", "lankhmar+1", @callback
      return

    "it works": (err, cred) ->
      assert.ifError err
      assert.isObject cred
      return

    "and they create a group":
      topic: (cred) ->
        callback = @callback
        url = "http://localhost:4815/api/user/fafhrd/feed"
        act =
          verb: "create"
          object:
            objectType: "group"
            displayName: "Barbarians"
            summary: "A safe place for barbarians to share their feelings"

        pj url, cred, act, (err, data, resp) ->
          callback err, data
          return

        return

      "it works": (err, data) ->
        assert.ifError err
        validActivity data
        return

      "and we retrieve that group with the REST API":
        topic: (act, cred) ->
          callback = @callback
          url = act.object.links.self.href
          gj url, cred, (err, data, resp) ->
            callback err, data
            return

          return

        "it works": (err, group) ->
          assert.ifError err
          assert.isObject group
          return

        "it looks right": (err, group) ->
          assert.ifError err
          validActivityObject group
          return

        "it has a members feed": (err, group) ->
          assert.ifError err
          assert.isObject group
          assert.include group, "members"
          validFeed group.members
          return

        "it has a documents feed": (err, group) ->
          assert.ifError err
          assert.isObject group
          assert.include group, "documents"
          validFeed group.documents
          return

        "it has an inbox feed": (err, group) ->
          assert.ifError err
          assert.isObject group
          assert.include group, "links"
          assert.isObject group.links
          assert.include group.links, "activity-inbox"
          assert.isObject group.links["activity-inbox"]
          assert.include group.links["activity-inbox"], "href"
          assert.isString group.links["activity-inbox"].href
          return

        "and we get the members feed":
          topic: (group, act, cred) ->
            callback = @callback
            url = group.members.url
            gj url, cred, (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it's empty": (err, feed) ->
            assert.ifError err
            assert.equal feed.totalItems, 0
            assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
            return

        "and we get the documents feed":
          topic: (group, act, cred) ->
            callback = @callback
            url = group.documents.url
            gj url, cred, (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it's empty": (err, feed) ->
            assert.ifError err
            assert.equal feed.totalItems, 0
            assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
            return

        "and we get the group inbox feed":
          topic: (group, act, cred) ->
            callback = @callback
            url = group.links["activity-inbox"].href
            gj url, cred, (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it's empty": (err, feed) ->
            assert.ifError err
            assert.equal feed.totalItems, 0
            assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
            return

  "and we make another group":
    topic: ->
      callback = @callback
      url = "http://localhost:4815/api/user/graymouser/feed"
      act =
        verb: "create"
        to: [
          id: "http://activityschema.org/collection/public"
          objectType: "collection"
        ]
        object:
          objectType: "group"
          displayName: "Magicians"
          summary: "Let's talk sorcery!"

      cred = undefined
      Step (->
        newCredentials "graymouser", "swords+_+_", this
        return
      ), ((err, results) ->
        throw err  if err
        cred = results
        pj url, cred, act, this
        return
      ), (err, data, resp) ->
        if err
          callback err, null, null
        else
          callback null, data, cred
        return

      return

    "it works": (err, data, cred) ->
      assert.ifError err
      validActivity data
      return

    "and another user tries to join it":
      topic: (created, cred) ->
        callback = @callback
        url = "http://localhost:4815/api/user/ningauble/feed"
        act =
          verb: "join"
          object:
            id: created.object.id
            objectType: created.object.objectType

        newCred = undefined
        Step (->
          newCredentials "ningauble", "*iiiiiii*", this
          return
        ), ((err, results) ->
          throw err  if err
          newCred = results
          pj url, newCred, act, this
          return
        ), (err, data, resp) ->
          if err
            callback err, null, null
          else
            callback null, data, newCred
          return

        return

      "it works": (err, data, cred) ->
        assert.ifError err
        validActivity data
        return

      "and the creator checks the member feed":
        topic: (joinAct, memberCred, createAct, creatorCred) ->
          callback = @callback
          url = joinAct.object.members.url
          cred = creatorCred
          gj url, cred, (err, data, resp) ->
            callback err, data, joinAct.actor
            return

          return

        "it works": (err, feed, joiner) ->
          assert.ifError err
          validFeed feed
          return

        "it's got our joined person": (err, feed, joiner) ->
          assert.ifError err
          assert.equal feed.totalItems, 1
          assert.equal feed.items.length, 1
          validActivityObject feed.items[0]
          assert.equal feed.items[0].id, joiner.id
          return

        "and the member leaves the group":
          topic: (feed, joiner, joinAct, memberCred, createAct, creatorCred) ->
            callback = @callback
            url = "http://localhost:4815/api/user/ningauble/feed"
            cred = memberCred
            group = createAct.object
            act =
              verb: "leave"
              object:
                id: group.id
                objectType: group.objectType

            Step (->
              pj url, cred, act, this
              return
            ), (err, data, resp) ->
              if err
                callback err, null
              else
                callback null, data
              return

            return

          "it works": (err, data) ->
            assert.ifError err
            validActivity data
            return

          "and the creator checks the member feed":
            topic: (leaveAct, feed, joiner, joinAct, memberCred, createAct, creatorCred) ->
              callback = @callback
              url = createAct.object.members.url
              cred = creatorCred
              gj url, cred, (err, data, resp) ->
                callback err, data
                return

              return

            "it works": (err, feed) ->
              assert.ifError err
              validFeed feed
              return

            "it's empty": (err, feed) ->
              assert.ifError err
              assert.equal feed.totalItems, 0
              assert.isTrue not _.has(feed, "items") or (_.isArray(feed.items) and feed.items.length is 0)
              return

  "and two users join a group":
    topic: ->
      callback = @callback
      creds = undefined
      group = undefined
      Step (->
        newCredentials "krovas", "grand*master", @parallel()
        newCredentials "fissif", "thief*no1", @parallel()
        newCredentials "slevyas", "thief*no2", @parallel()
        return
      ), ((err, cred1, cred2, cred3) ->
        url = undefined
        act = undefined
        throw err  if err
        creds =
          krovas: cred1
          fissif: cred2
          slevyas: cred3

        url = "http://localhost:4815/api/user/krovas/feed"
        act =
          verb: "create"
          to: [
            id: "http://activityschema.org/collection/public"
            objectType: "collection"
          ]
          object:
            objectType: "group"
            displayName: "Thieves' Guild"
            summary: "For thieves to hang out and help each other steal stuff"

        pj url, creds.krovas, act, this
        return
      ), ((err, created) ->
        url = undefined
        act = undefined
        throw err  if err
        group = created.object
        url = "http://localhost:4815/api/user/fissif/feed"
        act =
          verb: "join"
          object: group

        pj url, creds.fissif, act, @parallel()
        url = "http://localhost:4815/api/user/slevyas/feed"
        act =
          verb: "join"
          object: group

        pj url, creds.slevyas, act, @parallel()
        return
      ), (err) ->
        if err
          callback err, null, null
        else
          callback null, group, creds
        return

      return

    "it works": (err, group, creds) ->
      assert.ifError err
      validActivityObject group
      assert.isObject creds
      return

    "and one member posts to the group":
      topic: (group, creds) ->
        callback = @callback
        url = "http://localhost:4815/api/user/fissif/feed"
        act =
          verb: "post"
          to: [group]
          object:
            objectType: "note"
            content: "When is the next big caper, guys?"

        pj url, creds.fissif, act, (err, data, resp) ->
          callback err, data
          return

        return

      "it works": (err, act) ->
        assert.ifError err
        validActivity act
        return

      "and we wait a second for delivery":
        topic: (act, group, creds) ->
          callback = @callback
          setTimeout (->
            callback null
            return
          ), 1000
          return

        "it works": (err) ->
          assert.ifError err
          return

        "and the other member checks the group's inbox feed":
          topic: (act, group, creds) ->
            callback = @callback
            url = group.links["activity-inbox"].href
            gj url, creds.slevyas, (err, data, resp) ->
              callback err, data, act
              return

            return

          "it works": (err, feed, act) ->
            assert.ifError err
            validFeed feed
            return

          "it includes the posted activity": (err, feed, act) ->
            item = undefined
            assert.ifError err
            assert.isObject feed
            assert.isNumber feed.totalItems
            assert.greater feed.totalItems, 0
            assert.isArray feed.items
            assert.greater feed.items.length, 0
            item = _.find(feed.items, (item) ->
              item.id is act.id
            )
            assert.isObject item
            return

        "and the other member checks their own inbox feed":
          topic: (act, group, creds) ->
            callback = @callback
            url = "http://localhost:4815/api/user/slevyas/inbox"
            gj url, creds.slevyas, (err, data, resp) ->
              callback err, data, act
              return

            return

          "it works": (err, feed, act) ->
            assert.ifError err
            validFeed feed
            return

          "it includes the posted activity": (err, feed, act) ->
            item = undefined
            assert.ifError err
            assert.isObject feed
            assert.isNumber feed.totalItems
            assert.greater feed.totalItems, 0
            assert.isArray feed.items
            assert.greater feed.items.length, 0
            item = _.find(feed.items, (item) ->
              item.id is act.id
            )
            assert.isObject item
            return

  "and a user joins an unknown group":
    topic: ->
      callback = @callback
      Step (->
        newCredentials "ivrian", "dukes*daughter", this
        return
      ), ((err, cred) ->
        url = undefined
        act = undefined
        throw err  if err
        url = "http://localhost:4815/api/user/ivrian/feed"
        act =
          verb: "join"
          to: [
            id: "http://activityschema.org/collection/public"
            objectType: "collection"
          ]
          object:
            id: "urn:uuid:bde3d2b4-b0f6-11e2-954a-2c8158efb9e9"
            objectType: "group"
            displayName: "Girlfriends"
            summary: "For girlfriends of dumb adventurers"

        pj url, cred, act, this
        return
      ), (err, joinact, resp) ->
        callback err
        return

      return

    "it works": (err) ->
      assert.ifError err
      return

  "and a user joins a group they don't have access to":
    topic: ->
      callback = @callback
      creds = undefined
      Step (->
        newCredentials "vlana", "culture*actor", @parallel()
        newCredentials "vellix", "another*guy", @parallel()
        return
      ), ((err, vlana, vellix) ->
        url = undefined
        act = undefined
        throw err  if err
        creds =
          vlana: vlana
          vellix: vellix

        url = "http://localhost:4815/api/user/vlana/feed"
        act =
          verb: "create"
          object:
            objectType: "group"
            displayName: "Partners"
            summary: "Partners of Vlana"

        pj url, creds.vlana, act, this
        return
      ), ((err, createact, resp) ->
        url = undefined
        act = undefined
        throw err  if err
        url = "http://localhost:4815/api/user/vellix/feed"
        act =
          verb: "join"
          object: createact.object

        pj url, creds.vellix, act, this
        return
      ), (err, joinact, resp) ->
        if err
          callback null
        else
          callback new Error("Unexpected success")
        return

      return

    "it fails correctly": (err) ->
      assert.ifError err
      return

  "and we make some users":
    topic: ->
      callback = @callback
      cl = undefined
      Step (->
        newClient this
        return
      ), ((err, results) ->
        group = @group()
        i = undefined
        cl = results
        i = 0
        while i < 7
          newPair cl, "priest" + i, "dark*watcher*" + i, group()
          i++
        return
      ), (err, pairs) ->
        if err
          callback err, null
        else
          callback null, _.map(pairs, (pair) ->
            makeCred cl, pair
          )
        return

      return

    "it works": (err, creds) ->
      assert.ifError err
      assert.isArray creds
      return

    "and they all join a group":
      topic: (creds) ->
        callback = @callback
        priests = _.map(creds, (cred) ->
          cred.user.profile
        )
        group = undefined
        Step (->
          url = "http://localhost:4815/api/user/priest0/feed"
          act =
            verb: "create"
            to: priests
            object:
              objectType: "group"
              displayName: "Black Priests"
              summary: "Defenders of truth and justice"

          pj url, creds[0], act, this
          return
        ), ((err, act) ->
          gr = @group()
          throw err  if err
          group = act.object
          _.times 7, (i) ->
            url = "http://localhost:4815/api/user/priest" + i + "/feed"
            act =
              verb: "join"
              object: group

            pj url, creds[i], act, gr()
            return

          return
        ), (err, joins) ->
          if err
            callback err, null
          else
            callback err, group
          return

        return

      "it works": (err, group) ->
        assert.ifError err
        validActivityObject group
        return

      "and the creator adds a document":
        topic: (group, creds) ->
          callback = @callback
          url = "http://localhost:4815/api/user/priest0/feed"
          act =
            verb: "post"
            object:
              id: "http://photo.example/priest0/photos/the-whole-gang"
              objectType: "image"
              displayName: "Group photo"
              url: "http://photo.example/priest0/photos/the-whole-gang.jpg"

            target: group

          Step (->
            pj url, creds[0], act, this
            return
          ), (err, body) ->
            callback err
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and the creator reads the document feed":
          topic: (group, creds) ->
            callback = @callback
            url = group.documents.url
            gj url, creds[0], (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it has the added object": (err, feed) ->
            assert.ifError err
            assert.isTrue feed.totalItems > 0
            assert.isArray feed.items
            assert.isTrue feed.items.length > 0
            assert.isObject _.find(feed.items, (item) ->
              item.url is "http://photo.example/priest0/photos/the-whole-gang.jpg"
            )
            return

        "and another member reads the document feed":
          topic: (group, creds) ->
            callback = @callback
            url = group.documents.url
            gj url, creds[6], (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it has the added object": (err, feed) ->
            assert.ifError err
            assert.isTrue feed.totalItems > 0
            assert.isArray feed.items
            assert.isTrue feed.items.length > 0
            assert.isObject _.find(feed.items, (item) ->
              item.url is "http://photo.example/priest0/photos/the-whole-gang.jpg"
            )
            return

      "and another member adds a document":
        topic: (group, creds) ->
          callback = @callback
          url = "http://localhost:4815/api/user/priest1/feed"
          act =
            verb: "post"
            object:
              id: "http://docs.example/priest1/files/action-plan"
              objectType: "file"
              displayName: "Action Plan"
              url: "http://docs.example/priest1/files/action-plan.docx"

            target: group

          Step (->
            pj url, creds[1], act, this
            return
          ), (err, body) ->
            callback err
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and the creator reads the document feed":
          topic: (group, creds) ->
            callback = @callback
            url = group.documents.url
            gj url, creds[1], (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it has the added object": (err, feed) ->
            assert.ifError err
            assert.isTrue feed.totalItems > 0
            assert.isArray feed.items
            assert.isTrue feed.items.length > 0
            assert.isObject _.find(feed.items, (item) ->
              item.url is "http://docs.example/priest1/files/action-plan.docx"
            )
            return

        "and another member reads the document feed":
          topic: (group, creds) ->
            callback = @callback
            url = group.documents.url
            gj url, creds[5], (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it has the added object": (err, feed) ->
            assert.ifError err
            assert.isTrue feed.totalItems > 0
            assert.isArray feed.items
            assert.isTrue feed.items.length > 0
            assert.isObject _.find(feed.items, (item) ->
              item.url is "http://docs.example/priest1/files/action-plan.docx"
            )
            return

      "and a non-member tries to read the document feed":
        topic: (group, creds) ->
          callback = @callback
          url = group.documents.url
          Step (->
            newCredentials "theduke", "total*sadist", this
            return
          ), ((err, cred) ->
            throw err  if err
            gj url, cred, this
            return
          ), (err, body, response) ->
            if err and err.statusCode is 403
              callback null
            else if err
              callback err
            else
              callback new Error("Unexpected success!")
            return

          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and a non-member tries to add a document":
        topic: (group, creds) ->
          callback = @callback
          url = group.documents.url
          Step (->
            newCredentials "ohmphal", "a*thief's*skull", this
            return
          ), ((err, cred) ->
            url = undefined
            act = undefined
            throw err  if err
            url = "http://localhost:4815/api/user/ohmphal/feed"
            act =
              verb: "post"
              object:
                id: "urn:uuid:5245d4e2-60b1-42b8-b24d-032e92a86ac7"
                objectType: "audio"
                displayName: "Scary moan"
                url: "http://sound.example/ohmphal/scary-moan.flac"

              target: group

            pj url, cred, act, this
            return
          ), (err, body, response) ->
            if err and err.statusCode is 400
              callback null
            else if err
              callback err
            else
              callback new Error("Unexpected success!")
            return

          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and a non-member tries to read the members feed":
        topic: (group, creds) ->
          callback = @callback
          url = group.members.url
          Step (->
            newCredentials "atya", "scraw*scraw", this
            return
          ), ((err, cred) ->
            throw err  if err
            gj url, cred, this
            return
          ), (err, body, response) ->
            if err and err.statusCode is 403
              callback null
            else if err
              callback err
            else
              callback new Error("Unexpected success!")
            return

          return

        "it fails correctly": (err) ->
          assert.ifError err
          return

      "and a member adds and removes a document":
        topic: (group, creds) ->
          callback = @callback
          url = "http://localhost:4815/api/user/priest2/feed"
          Step (->
            act =
              verb: "post"
              object:
                id: "http://photo.example/priest2/photos/my-vacation-2006"
                objectType: "image"
                displayName: "Vacation photo"
                url: "http://photo.example/priest2/photos/my-vacation-2006.jpg"

              target: group

            pj url, creds[2], act, this
            return
          ), ((err, posted) ->
            throw err  if err
            act =
              verb: "remove"
              object:
                id: "http://photo.example/priest2/photos/my-vacation-2006"
                objectType: "image"

              target: group

            pj url, creds[2], act, this
            return
          ), (err, body) ->
            callback err
            return

          return

        "it works": (err) ->
          assert.ifError err
          return

        "and the poster checks the documents feed":
          topic: (group, creds) ->
            callback = @callback
            url = group.documents.url
            gj url, creds[2], (err, data, resp) ->
              callback err, data
              return

            return

          "it works": (err, feed) ->
            assert.ifError err
            validFeed feed
            return

          "it does not have the object": (err, feed) ->
            assert.ifError err
            assert.isArray feed.items
            assert.isUndefined _.find(feed.items, (item) ->
              item.id is "http://photo.example/priest2/photos/my-vacation-2006"
            )
            return

suite["export"] module
