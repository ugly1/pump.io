# routes/webfinger.js
#
# Endpoints for discovery using RFC 6415 and Webfinger
#
# Copyright 2011-2012, E14N https://e14n.com/
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
urlparse = require("url").parse
databank = require("databank")
_ = require("underscore")
Step = require("step")
validator = require("validator")
check = validator.check
sanitize = validator.sanitize
HTTPError = require("../httperror").HTTPError
URLMaker = require("../urlmaker").URLMaker
User = require("../model/user").User
ActivityObject = require("../model/activityobject").ActivityObject

# Initialize the app controller
addRoutes = (app) ->
  app.get "/.well-known/host-meta", hostMeta
  app.get "/.well-known/host-meta.json", hostMetaJSON
  app.get "/api/lrdd", lrddUser, lrdd
  app.get "/.well-known/webfinger", lrddUser, webfinger
  return

xmlEscape = (text) ->
  text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;").replace /'/g, "&amp;"

Link = (attrs) ->
  "<Link " + _(attrs).map((value, key) ->
    key + "=\"" + xmlEscape(value) + "\""
  ).join(" ") + " />"

hostMetaLinks = ->
  [
    {
      rel: "lrdd"
      type: "application/xrd+xml"
      template: URLMaker.makeURL("/api/lrdd") + "?resource={uri}"
    }
    {
      rel: "lrdd"
      type: "application/json"
      template: URLMaker.makeURL("/.well-known/webfinger") + "?resource={uri}"
    }
    {
      rel: "registration_endpoint"
      href: URLMaker.makeURL("/api/client/register")
    }
    {
      rel: "http://apinamespace.org/oauth/request_token"
      href: URLMaker.makeURL("/oauth/request_token")
    }
    {
      rel: "http://apinamespace.org/oauth/authorize"
      href: URLMaker.makeURL("/oauth/authorize")
    }
    {
      rel: "http://apinamespace.org/oauth/access_token"
      href: URLMaker.makeURL("/oauth/access_token")
    }
    {
      rel: "dialback"
      href: URLMaker.makeURL("/api/dialback")
    }
    {
      rel: "http://apinamespace.org/activitypub/whoami"
      href: URLMaker.makeURL("/api/whoami")
    }
  ]

hostMeta = (req, res, next) ->
  i = undefined
  links = undefined
  
  # Return JSON if accepted
  if _(req.headers).has("accept") and req.accepts("application/json")
    hostMetaJSON req, res, next
    return
  
  # otherwise, xrd
  links = hostMetaLinks()
  res.writeHead 200,
    "Content-Type": "application/xrd+xml"

  res.write "<?xml version='1.0' encoding='UTF-8'?>\n" + "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>\n"
  i = 0
  while i < links.length
    res.write Link(links[i]) + "\n"
    i++
  res.end "</XRD>\n"
  return

hostMetaJSON = (req, res, next) ->
  res.json links: hostMetaLinks()
  return

lrddUser = (req, res, next) ->
  resource = undefined
  parts = undefined
  if not _(req).has("query") or not _(req.query).has("resource")
    next new HTTPError("No resource parameter", 400)
    return
  resource = req.query.resource
  
  # Prefix it with acct: if it looks like a bare webfinger
  resource = "acct:" + resource  if resource.indexOf("@") isnt -1  if resource.indexOf(":") is -1
  
  # This works for acct: URIs, http URIs, and https URIs
  parts = urlparse(resource)
  unless parts
    next new HTTPError("Unrecognized resource parameter", 404)
    return
  unless parts.hostname is URLMaker.hostname
    next new HTTPError("Unrecognized host", 404)
    return
  switch parts.protocol
    when "acct:"
      Step (->
        User.get parts.auth, this
        return
      ), ((err, user) ->
        throw err  if err
        req.user = user
        user.expand this
        return
      ), (err) ->
        if err and err.name is "NoSuchThingError"
          next new HTTPError(err.message, 404)
        else if err
          next err
        else
          next()
        return

    when "http:", "https:"
      
      # XXX: this is kind of flaky; we should have a better way to turn
      # an ID into an activity object
      match = parts.pathname.match("/api/([^/]*)/")
      unless match
        next new HTTPError("Unknown object type", 404)
        return
      type = match[1]
      ActivityObject.getObject type, resource, (err, obj) ->
        if err and err.name is "NoSuchThingError"
          next new HTTPError(err.message, 404)
        else if err
          next err
        else
          req.obj = obj
          next()
        return


userLinks = (user) ->
  links = [
    {
      rel: "http://webfinger.net/rel/profile-page"
      type: "text/html"
      href: URLMaker.makeURL("/" + user.nickname)
    }
    {
      rel: "dialback"
      href: URLMaker.makeURL("/api/dialback")
    }
  ]
  links.concat objectLinks(user.profile)

objectLinks = (obj) ->
  links = []
  feeds = [
    "replies"
    "likes"
    "shares"
    "members"
    "followers"
    "following"
    "favorites"
    "lists"
  ]
  if obj.links
    _.each obj.links, (value, key) ->
      link = _.clone(value)
      link.rel = key
      links.push link
      return

  _.each feeds, (feed) ->
    link = undefined
    if obj[feed] and obj[feed].url
      link =
        rel: feed
        href: obj[feed].url

      links.push link
    return

  links

lrdd = (req, res, next) ->
  i = undefined
  links = undefined
  if _(req.headers).has("accept") and req.accepts("application/json")
    webfinger req, res, next
    return
  if req.user
    links = userLinks(req.user)
  else
    links = objectLinks(req.obj)
  res.writeHead 200,
    "Content-Type": "application/xrd+xml"

  res.write "<?xml version='1.0' encoding='UTF-8'?>\n" + "<XRD xmlns='http://docs.oasis-open.org/ns/xri/xrd-1.0'>\n"
  i = 0
  while i < links.length
    res.write Link(links[i]) + "\n"
    i++
  res.end "</XRD>\n"
  return

webfinger = (req, res, next) ->
  links = undefined
  if req.user
    links = userLinks(req.user)
  else
    links = objectLinks(req.obj)
  res.json links: links
  return

exports.addRoutes = addRoutes
