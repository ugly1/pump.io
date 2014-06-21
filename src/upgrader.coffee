# upgrader.js
#
# Do in-place upgrades of activity objects as needed
#
# Copyright 2011, 2013 E14N https://e14n.com/
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
fs = require("fs")
os = require("os")
path = require("path")
urlparse = require("url").parse
Step = require("step")
_ = require("underscore")
thumbnail = require("./thumbnail")
URLMaker = require("./urlmaker").URLMaker
Activity = require("./model/activity").Activity
ActivityObject = require("./model/activityobject").ActivityObject
Image = require("./model/image").Image
Person = require("./model/person").Person
Stream = require("./model/stream").Stream
mover = require("./mover")
Upgrader = new (->
  upg = this
  autorotateImage = (img, callback) ->
    fname = path.join(Image.uploadDir, img._slug)
    tmpdir = (if (_.isFunction(os.tmpdir)) then os.tmpdir() else (if (_.isFunction(os.tmpDir)) then os.tmpDir() else "/tmp"))
    tmpname = path.join(tmpdir, img._uuid)
    Step (->
      thumbnail.autorotate fname, tmpname, this
      return
    ), ((err) ->
      throw err  if err
      mover.safeMove tmpname, fname, this
      return
    ), callback
    return

  upgradePersonAvatar = (person, callback) ->
    img = undefined
    urlToSlug = (person, url) ->
      start = url.indexOf("/" + person.preferredUsername + "/")
      url.substr start + 1

    slug = undefined
    reupgrade = (slug, callback) ->
      Step (->
        Image.search
          _fslug: slug
        , this
        return
      ), (err, images) ->
        img = undefined
        throw err  if err
        if not images or images.length is 0
          throw new Error("No image record found for slug: " + slug)
        else
          img = images[0]
          img.image = url: img.fullImage.url
          img.fullImage = url: img.fullImage.url
          img._slug = slug
          delete img._fslug

          callback null, img
        return

      return

    
    # Automated update from v0.2.x, which had no thumbnailing of images
    # This checks for local persons with no "width" in their image
    # and tries to update the user data.
    if person._user and _.isObject(person.image) and not _.has(person.image, "width") and _.isString(person.image.url)
      if Upgrader.log
        Upgrader.log.debug
          person: person
        , "Upgrading person avatar"
      slug = urlToSlug(person, person.image.url)
      Step (->
        fs.stat path.join(Image.uploadDir, slug), this
        return
      ), ((err, stat) ->
        if err and err.code is "ENOENT"
          
          # If we don't have this file, just skip
          callback null
        else if err
          throw err
        else
          this null
        return
      ), ((err) ->
        throw err  if err
        Image.search
          _slug: slug
        , this
        return
      ), ((err, images) ->
        cb = this
        throw err  if err
        if not images or images.length is 0
          reupgrade slug, this
        else
          this null, images[0]
        return
      ), ((err, results) ->
        throw err  if err
        img = results
        upgradeAsAvatar img, this
        return
      ), ((err) ->
        throw err  if err
        
        # Save person first, to avoid a loop
        person.image = img.image
        person.pump_io = {}  unless person.pump_io
        person.pump_io.fullImage = img.fullImage
        person.save this
        return
      ), ((err) ->
        throw err  if err
        
        # Save image next, to avoid a loop
        img.save this
        return
      ), ((err, saved) ->
        iu = undefined
        pu = undefined
        throw err  if err
        
        # Send out an activity so everyone knows
        iu = new Activity(
          actor: person
          verb: "update"
          object: img
        )
        iu.fire @parallel()
        pu = new Activity(
          actor: person
          verb: "update"
          object: person
        )
        pu.fire @parallel()
        return
      ), callback
    else
      callback null
    return

  isRemoteURL = (url) ->
    urlparse(url).hostname isnt URLMaker.hostname

  isMismatchURL = (person, url) ->
    fromPerson = ActivityObject.domainOf(person.id)
    fromUrl = urlparse(url).hostname
    unless fromPerson is fromUrl
      if Upgrader.log
        Upgrader.log.debug
          url: url
          person: person.id
          fromPerson: fromPerson
          fromUrl: fromUrl
        , "URL hostname mismatch"
      true
    else
      false

  needsUpgradeUserFeeds = (person) ->
    person._user and (_.some([
      "replies"
      "likes"
      "shares"
    ], (feed) ->
      person[feed] and isRemoteURL(person[feed].url)
    ) or _.some([
      "followers"
      "following"
      "lists"
      "favorites"
    ], (feed) ->
      not _.has(person, feed) or isRemoteURL(person[feed].url)
    ) or _.some([
      "self"
      "activity-inbox"
      "activity-outbox"
    ], (rel) ->
      not _.has(person.links, rel) or isRemoteURL(person.links[rel].href)
    ))

  needsUpgradeRemotePersonFeeds = (person) ->
    not person._user and (ActivityObject.domainOf(person.id) isnt URLMaker.hostname) and not person._upgrade_remote_person_feeds and (not person._upgrade_remote_person_feeds_failed or (new Date()).getTime() > person._upgrade_remote_person_feeds_failed + person._upgrade_remote_person_feeds_failed_wait) and (_.some([
      "replies"
      "likes"
      "shares"
    ], (feed) ->
      person[feed] and isMismatchURL(person, person[feed].url)
    ) or _.some([
      "followers"
      "following"
      "lists"
      "favorites"
    ], (feed) ->
      not _.has(person, feed) or isMismatchURL(person, person[feed].url)
    ) or _.some([
      "self"
      "activity-inbox"
      "activity-outbox"
    ], (rel) ->
      not _.has(person.links, rel) or isMismatchURL(person, person.links[rel].href)
    ))

  upgradePersonFeeds = (person, callback) ->
    if needsUpgradeUserFeeds(person)
      upgradeUserFeeds person, callback
    else if needsUpgradeRemotePersonFeeds(person)
      upgradeRemotePersonFeeds person, callback
    else
      callback null
    return

  upgradeRemotePersonFeeds = (person, callback) ->
    discovered = undefined
    if Upgrader.log
      Upgrader.log.debug
        person: person
      , "Upgrading remote person feeds"
    Step (->
      ActivityObject.discover person, this
      return
    ), ((err, results) ->
      throw err  if err
      discovered = results
      
      # These get added accidentally; remove them if they look wrong
      _.each [
        "replies"
        "likes"
        "shares"
      ], (feed) ->
        if Upgrader.log
          Upgrader.log.debug
            person: person
            feed: feed
            personFeed: person[feed]
          , "Checking for bad value"
        if person[feed] and isMismatchURL(person, person[feed].url)
          delete person[feed]

          if Upgrader.log
            Upgrader.log.debug
              person: person
              feed: feed
            , "Deleted bad value"
        return

      person._upgrade_remote_person_feeds = true
      
      # We have to use save() to delete stuff
      person.save this
      return
    ), ((err) ->
      throw err  if err
      person.update discovered, this
      return
    ), (err) ->
      if err
        if Upgrader.log
          Upgrader.log.error
            person: person
            err: err
          , "Error upgrading person"
        person._upgrade_remote_person_feeds_failed = (new Date()).getTime()
        person._upgrade_remote_person_feeds_failed_wait = nextInterval(person._upgrade_remote_person_feeds_failed_wait)
        person.save (err) ->
          callback null
          return

      else
        if Upgrader.log
          Upgrader.log.debug
            person: person
            stillNeedsUpgrade: needsUpgradeRemotePersonFeeds(person)
          , "Finished upgrading remote person"
        callback null
      return

    return

  upgradeUserFeeds = (person, callback) ->
    if Upgrader.log
      Upgrader.log.debug
        person: person
      , "Upgrading user feeds"
    person.links = {}  unless _.has(person, "links")
    person.links["activity-inbox"] = href: URLMaker.makeURL("api/user/" + person.preferredUsername + "/inbox")
    person.links["activity-outbox"] = href: URLMaker.makeURL("api/user/" + person.preferredUsername + "/feed")
    person.links["self"] = href: URLMaker.makeURL("api/user/" + person.preferredUsername + "/profile")
    Person.ensureFeeds person, person.preferredUsername
    _.each [
      "likes"
      "replies"
      "shares"
    ], (feed) ->
      person[feed] = url: URLMaker.makeURL("api/person/" + person._uuid + "/" + feed)
      return

    Step (->
      person.save this
      return
    ), ((err) ->
      pu = undefined
      throw err  if err
      if Upgrader.log
        Upgrader.log.debug
          person: person
          stillNeedsUpgrade: needsUpgradeUserFeeds(person)
        , "Finished upgrading user"
      pu = new Activity(
        actor: person
        verb: "update"
        object: person
      )
      pu.fire this
      return
    ), callback
    return

  upgradeAsImage = (img, callback) ->
    Step (->
      autorotateImage img, this
      return
    ), ((err) ->
      throw err  if err
      thumbnail.addImageMetadata img, Image.uploadDir, this
      return
    ), callback
    return

  upgradeAsAvatar = (img, callback) ->
    Step (->
      autorotateImage img, this
      return
    ), ((err) ->
      throw err  if err
      thumbnail.addAvatarMetadata img, Image.uploadDir, this
      return
    ), callback
    return

  nextInterval = (lastInterval) ->
    intervals = [ # 1M
      60000
      300000 # 5M
      1800000 # .5H
      7200000 # 2H
      21600000 # 6H
      86400000 # 1D
      172800000 # 2D
      691200000 # 8D
    ]
    i = undefined
    return intervals[0]  unless lastInterval
    i = 0
    while i < intervals.length - 1
      return intervals[i + 1]  if lastInterval >= intervals[i] and lastInterval < intervals[i + 1]
      i++
    intervals[intervals.length - 1]

  upgradePersonUser = (person, callback) ->
    if person._user and not person._user_confirmed
      if Upgrader.log
        Upgrader.log.debug
          person: person
        , "Confirming _user flag"
      Step (->
        User = require("./model/user").User
        User.fromPerson person.id, this
        return
      ), ((err, user) ->
        throw err  if err
        if user
          if Upgrader.log
            Upgrader.log.debug
              person: person
            , "_user flag confirmed"
          person._user_confirmed = true
          person.save this
        else
          if Upgrader.log
            Upgrader.log.debug
              person: person
            , "Bad _user flag; removing"
          delete person._user

          person.save this
        return
      ), (err, person) ->
        callback err
        return

    else
      callback null
    return

  upg.upgradeImage = (img, callback) ->
    if img._slug and _.isObject(img.image) and not _.has(img.image, "width")
      if Upgrader.log
        Upgrader.log.debug
          image: img
        , "Upgrading image"
      Step (->
        fs.stat path.join(Image.uploadDir, img._slug), this
        return
      ), ((err, stat) ->
        if err and err.code is "ENOENT"
          
          # If we don't have this file, just skip
          callback null
        else if err
          throw err
        else
          this null
        return
      ), ((err) ->
        throw err  if err
        Person.search
          "image.url": img.image.url
        , this
        return
      ), ((err, people) ->
        throw err  if err
        if not people or people.length is 0
          upgradeAsImage img, this
        else
          upgradeAsAvatar img, this
        return
      ), ((err) ->
        throw err  if err
        img.save this
        return
      ), ((err, saved) ->
        act = undefined
        throw err  if err
        
        # Send out an activity so everyone knows
        act = new Activity(
          actor: img.author
          verb: "update"
          object: img
        )
        act.fire this
        return
      ), callback
    else
      callback null
    return

  upg.upgradePerson = (person, callback) ->
    Step (->
      upgradePersonUser person, this
      return
    ), ((err) ->
      throw err  if err
      upgradePersonAvatar person, this
      return
    ), ((err) ->
      throw err  if err
      upgradePersonFeeds person, this
      return
    ), callback
    return

  upg.upgradeGroup = (group, callback) ->
    if (group.members and group.documents) or not group.author
      callback null
      return
    if Upgrader.log
      Upgrader.log.debug
        group: group
      , "Upgrading group"
    Step (->
      group.isLocal this
      return
    ), ((err, isLocal) ->
      throw err  if err
      unless isLocal
        callback null
      else
        group.members = url: URLMaker.makeURL("api/group/" + group._uuid + "/members")  unless group.members
        group.documents = url: URLMaker.makeURL("api/group/" + group._uuid + "/documents")  unless group.documents
        group.save this
      return
    ), (err) ->
      callback err
      return

    return

  upg.upgradeActivity = (act, callback) ->
    ActivityObject = require("./model/activityobject").ActivityObject
    oprops = [
      "generator"
      "provider"
      "target"
      "context"
      "location"
      "source"
    ]
    isOK = (act, prop) ->
      not act[prop] or (_.isObject(act[prop]) and _.isString(act[prop].id))

    fixupProperty = (act, prop, defaultType, callback) ->
      val = undefined
      if isOK(act, prop)
        callback null
        return
      val = act[prop]
      Step (->
        val.objectType = defaultType  unless val.objectType
        ActivityObject.ensureObject val, this
        return
      ), ((err, ensured) ->
        throw err  if err
        act[prop] = ensured
        this null
        return
      ), callback
      return

    
    # If all the object properties look OK, continue
    if _.every(oprops, (prop) ->
      isOK act, prop
    )
      callback null
      return
    if Upgrader.log
      Upgrader.log.debug
        activity: act
      , "Upgrading activity"
    
    # Otherwise, fix them up
    Step (->
      fixupProperty act, "location", ActivityObject.PLACE, @parallel()
      fixupProperty act, "provider", ActivityObject.SERVICE, @parallel()
      fixupProperty act, "generator", ActivityObject.APPLICATION, @parallel()
      fixupProperty act, "target", ActivityObject.COLLECTION, @parallel()
      fixupProperty act, "source", ActivityObject.COLLECTION, @parallel()
      fixupProperty act, "context", ActivityObject.ISSUE, @parallel()
      return
    ), ((err) ->
      throw err  if err
      act.save this
      return
    ), (err) ->
      callback err
      return

    return

  return
)()
module.exports = Upgrader
