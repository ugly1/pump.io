# routes/confirm.js
#
# Endpoint for confirming an email address
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
_ = require("underscore")
Step = require("step")
authc = require("../lib/authc")
HTTPError = require("../lib/httperror").HTTPError
URLMaker = require("../lib/urlmaker").URLMaker
Confirmation = require("../model/confirmation").Confirmation
User = require("../model/user").User
setPrincipal = authc.setPrincipal
principal = authc.principal
addRoutes = (app) ->
  app.get "/main/confirm/:code", app.session, principal, confirm
  return

confirm = (req, res, next) ->
  code = req.params.code
  principal = req.principal
  user = undefined
  confirm = undefined
  Step (->
    Confirmation.search
      code: code
    , this
    return
  ), ((err, confirms) ->
    throw err  if err
    throw new HTTPError("Invalid state for confirmation.", 500)  if not _.isArray(confirms) or confirms.length isnt 1
    confirm = confirms[0]
    
    # XXX: Maybe just log and redirect to / ?
    throw new HTTPError("Already confirmed.", 400)  if confirm.confirmed
    User.get confirm.nickname, this
    return
  ), ((err, results) ->
    throw err  if err
    user = results
    throw new HTTPError("This is someone else's confirmation.", 400)  if principal and principal.id isnt user.profile.id
    user.email = confirm.email
    user.save @parallel()
    confirm.confirmed = true
    confirm.save @parallel()
    return
  ), ((err, res1, res2) ->
    throw err  if err
    setPrincipal req.session, user.profile, this
    return
  ), (err) ->
    if err
      next err
    else
      res.render "confirmed",
        page:
          title: "Email address confirmed"
          url: req.originalUrl

        principalUser: user
        principal: user.profile

    return

  return

exports.addRoutes = addRoutes
