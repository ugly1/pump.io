# filteredstream-test.js
#
# Test the filteredstream module
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
_ = require("underscore")
databank = require("databank")
Step = require("step")
fs = require("fs")
path = require("path")
Queue = require("jankyqueue")
schema = require("../lib/schema").schema
URLMaker = require("../lib/urlmaker").URLMaker
Stream = require("../lib/model/stream").Stream
Activity = require("../lib/model/activity").Activity
Databank = databank.Databank
DatabankObject = databank.DatabankObject
tc = JSON.parse(fs.readFileSync(path.join(__dirname, "config.json")))
suite = vows.describe("filtered stream interface")
suite.addBatch "When we set up the environment":
  topic: ->
    cb = @callback
    
    # Need this to make IDs
    URLMaker.hostname = "example.net"
    
    # Dummy databank
    tc.params.schema = schema
    db = Databank.get(tc.driver, tc.params)
    db.connect {}, (err) ->
      if err
        cb err
      else
        DatabankObject.bank = db
        cb null
      return

    return

  "it works": (err) ->
    assert.ifError err
    return

  "and we load the filteredstream module":
    topic: ->
      require "../lib/filteredstream"

    "it works": (mod) ->
      assert.isObject mod
      return

    "and we get the FilteredStream class":
      topic: (mod) ->
        mod.FilteredStream

      "it works": (FilteredStream) ->
        assert.isFunction FilteredStream
        return

      "and we create a stream with lots of activities":
        topic: (FilteredStream) ->
          callback = @callback
          str = undefined
          places = [
            {
              displayName: "Montreal"
              id: "http://www.geonames.org/6077243/montreal.html"
            }
            {
              displayName: "San Francisco"
              id: "http://www.geonames.org/5391959/san-francisco.html"
            }
          ]
          sentences = [
            "Hello, world!"
            "Testing 1, 2, 3."
            "Now is the time for all good men to come to the aid of the party."
          ]
          actorIds = [
            "8d75183c-e74c-11e1-8115-70f1a154e1aa"
            "8d7589a2-e74c-11e1-b7e1-70f1a154e1aa"
            "8d75f4fa-e74c-11e1-8cbe-70f1a154e1aa"
            "8d764306-e74c-11e1-848f-70f1a154e1aa"
            "8d76ad0a-e74c-11e1-b1bc-70f1a154e1aa"
          ]
          moods = [
            "happy"
            "sad"
            "frightened"
            "mad"
            "excited"
            "glad"
            "bored"
          ]
          tags = [
            "ggi"
            "winning"
            "justsayin"
            "ows"
            "sep17"
            "jan25"
            "egypt"
            "fail"
            "tigerblood"
            "bitcoin"
            "fsw"
          ]
          total = undefined
          createAndDeliver = (act, callback) ->
            Step (->
              Activity.create act, this
              return
            ), ((err, act) ->
              throw err  if err
              str.deliver act.id, this
              return
            ), (err) ->
              callback err
              return

            return

          total = places.length * sentences.length * actorIds.length * moods.length * tags.length
          Step (->
            Stream.create
              name: "test"
            , this
            return
          ), ((err, result) ->
            i = undefined
            act = undefined
            q = undefined
            group = @group()
            throw err  if err
            str = result
            q = new Queue(25)
            i = 0
            while i < total
              act =
                actor:
                  objectType: "person"
                  displayName: "Anonymous"
                  id: actorIds[i % actorIds.length]

                verb: "post"
                object:
                  objectType: "note"
                  content: sentences[i % sentences.length] + " #" + tags[i % tags.length]
                  tags: [
                    objectType: "http://activityschema.org/object/hashtag"
                    displayName: tags[i % tags.length]
                  ]

                location: places[i % places.length]
                mood:
                  displayName: moods[i % moods.length]

              q.enqueue createAndDeliver, [act], group()
              i++
            return
          ), (err) ->
            if err
              callback err, null
            else
              callback null, str
            return

          return

        "it works": (err, str) ->
          assert.ifError err
          assert.isObject str
          assert.instanceOf str, Stream
          return

        "and we add a filter by mood":
          topic: (str, FilteredStream) ->
            byMood = (mood) ->
              (id, callback) ->
                Step (->
                  Activity.get id, this
                  return
                ), (err, act) ->
                  if err
                    callback err, null
                  else if act.mood.displayName is mood
                    callback null, true
                  else
                    callback null, false
                  return

                return

            new FilteredStream(str, byMood("happy"))

          "it works": (fs) ->
            assert.isObject fs
            return

          "it has a getIDs() method": (fs) ->
            assert.isFunction fs.getIDs
            return

          "it has a getIDsGreaterThan() method": (fs) ->
            assert.isFunction fs.getIDsGreaterThan
            return

          "it has a getIDsLessThan() method": (fs) ->
            assert.isFunction fs.getIDsLessThan
            return

          "it has a count() method": (fs) ->
            assert.isFunction fs.count
            return

          "and we get the filtered stream's count":
            topic: (fs) ->
              fs.count @callback
              return

            "it works": (err, cnt) ->
              assert.ifError err
              return

            "it has the value of the full stream": (err, cnt) ->
              assert.ifError err
              assert.equal cnt, 2310
              return

          "and we get the full stream by 20-item chunks":
            topic: (fs) ->
              Step (->
                i = undefined
                group = @group()
                i = 0
                while i < 17
                  fs.getIDs i * 20, (i + 1) * 20, group()
                  i++
                return
              ), @callback
              return

            "it works": (err, chunks) ->
              assert.ifError err
              assert.isArray chunks
              return

            "data looks correct": (err, chunks) ->
              i = undefined
              j = undefined
              seen = {}
              assert.ifError err
              assert.isArray chunks
              assert.lengthOf chunks, 17
              i = 0
              while i < chunks.length
                assert.isArray chunks[i]
                if i is 16
                  
                  # total == 330, last is only 10
                  assert.lengthOf chunks[i], 10
                else
                  assert.lengthOf chunks[i], 20
                j = 0
                while j < chunks[i].length
                  assert.isString chunks[i][j]
                  assert.isUndefined seen[chunks[i][j]]
                  seen[chunks[i][j]] = 1
                  j++
                i++
              return

          "and we get the IDs less than some middle value":
            topic: (fs) ->
              orig = undefined
              cb = @callback
              Step (->
                fs.getIDs 100, 150, this
                return
              ), ((err, ids) ->
                throw err  if err
                orig = ids.slice(10, 30)
                fs.getIDsLessThan ids[30], 20, this
                return
              ), (err, ids) ->
                if err
                  cb err, ids
                else
                  cb null, orig, ids
                return

              return

            "it works": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              return

            "data looks correct": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              assert.deepEqual orig, ids
              return

          "and we get the IDs less than some value close to the start":
            topic: (fs) ->
              orig = undefined
              cb = @callback
              Step (->
                fs.getIDs 0, 20, this
                return
              ), ((err, ids) ->
                throw err  if err
                orig = ids.slice(0, 5)
                fs.getIDsLessThan ids[5], 20, this
                return
              ), (err, ids) ->
                if err
                  cb err, ids
                else
                  cb null, orig, ids
                return

              return

            "it works": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              return

            "data looks correct": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              assert.deepEqual orig, ids
              return

          "and we get the IDs greater than some middle value":
            topic: (fs) ->
              orig = undefined
              cb = @callback
              Step (->
                fs.getIDs 200, 250, this
                return
              ), ((err, ids) ->
                throw err  if err
                orig = ids.slice(20, 40)
                fs.getIDsGreaterThan ids[19], 20, this
                return
              ), (err, ids) ->
                if err
                  cb err, ids
                else
                  cb null, orig, ids
                return

              return

            "it works": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              return

            "data looks correct": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              assert.deepEqual orig, ids
              return

          "and we get the IDs greater than some value close to the end":
            topic: (fs) ->
              orig = undefined
              cb = @callback
              Step (->
                fs.getIDs 319, 330, this
                return
              ), ((err, ids) ->
                throw err  if err
                orig = ids.slice(1, 11)
                fs.getIDsGreaterThan ids[0], 20, this
                return
              ), (err, ids) ->
                if err
                  cb err, ids
                else
                  cb null, orig, ids
                return

              return

            "it works": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              return

            "data looks correct": (err, orig, ids) ->
              assert.ifError err
              assert.isArray orig
              assert.isArray ids
              assert.deepEqual orig, ids
              return

      "and we create a stream with a lot of objects":
        topic: (FilteredStream) ->
          callback = @callback
          Person = require("../lib/model/person").Person
          names =
            "Norma Lakin": "f"
            "Jason Pegram": "m"
            "Albert Carner": "m"
            "Manuel Chronister": "m"
            "Michelle Deleon": "f"
            "Jeffery Skaggs": "m"
            "Tanya Lawlor": "f"
            "Blanche Martins": "f"
            "Ruby Slack": "f"
            "Kayla Taber": "f"
            "Arthur Barrier": "m"
            "Becky Repp": "f"
            "Sheri Shouse": "f"
            "Randy Sealey": "m"
            "Aaron Schenk": "m"
            "Jeffery Coffey": "m"
            "Carole Arce": "f"
            "Henry Lockard": "m"
            "Steve Stewart": "m"
            "Kristine Alaniz": "f"
            "Eleanor Edmiston": "f"
            "Esther Bruns": "f"
            "Amanda Thibodeaux": "f"
            "Myrtle Chidester": "f"
            "Daniel Eidson": "m"
            "Ellen Jacks": "f"
            "Ryan Ainsworth": "m"
            "Amanda Cameron": "f"
            "Jenny Mccaleb": "f"

          addPerson = (str, name, gender, cb) ->
            person = undefined
            Step (->
              Person.create
                displayName: name
                gender: gender
              , this
              return
            ), ((err, result) ->
              throw err  if err
              person = result
              str.deliverObject
                id: person.id
                objectType: person.objectType
              , this
              return
            ), (err) ->
              if err
                cb err
              else
                cb null
              return

            return

          str = undefined
          Step (->
            Stream.create
              name: "test-2"
            , this
            return
          ), ((err, result) ->
            group = @group()
            throw err  if err
            str = result
            _.each names, (gender, name) ->
              addPerson str, name, gender, group()
              return

            return
          ), (err) ->
            if err
              callback err, null
            else
              callback null, str
            return

          return

        "it works": (err, str) ->
          assert.ifError err
          assert.isObject str
          return

        "and we create a filtered stream of those objects":
          topic: (str, FilteredStream) ->
            Person = require("../lib/model/person").Person
            isFemale = (item, callback) ->
              ref = undefined
              try
                ref = JSON.parse(item)
              catch err
                callback err, null
                return
              Step (->
                Person.get ref.id, this
                return
              ), (err, person) ->
                if err
                  callback err, null
                else
                  callback null, person.gender is "f"
                return

              return

            new FilteredStream(str, isFemale)

          "it works": (filtered) ->
            assert.isObject filtered
            return

          "and we try to get 10 items":
            topic: (filtered) ->
              callback = @callback
              Person = require("../lib/model/person").Person
              Step (->
                filtered.getObjects 0, 10, this
                return
              ), ((err, refs) ->
                ids = undefined
                throw err  if err
                Person.readArray _.pluck(refs, "id"), this
                return
              ), callback
              return

            "it works": (err, people) ->
              assert.ifError err
              return

            "it looks correct": (err, people) ->
              i = undefined
              assert.ifError err
              assert.isArray people
              assert.lengthOf people, 10
              i = 0
              while i < 10
                assert.equal people[i].gender, "f"
                i++
              return

suite["export"] module
