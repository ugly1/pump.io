# mailer-test.js
#
# Test the mailer tool
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
_ = require("underscore")
Logger = require("bunyan")
simplesmtp = require("simplesmtp")
emailutil = require("./lib/email")
Step = require("step")
oneEmail = emailutil.oneEmail
suite = vows.describe("mailer module interface").addBatch("When we set up a dummy server":
  topic: ->
    callback = @callback
    smtp = simplesmtp.createServer(disableDNSValidation: true)
    smtp.setMaxListeners 100  if _.isFunction(smtp.setMaxListeners)
    smtp.listen 1623, (err) ->
      if err
        callback err, null
      else
        callback null, smtp
      return

    return

  "it works": (err, smtp) ->
    assert.ifError err
    assert.isObject smtp
    return

  teardown: (smtp) ->
    if smtp
      smtp.end (err) ->

    return

  "and we require the mailer module":
    topic: ->
      require "../lib/mailer"

    "it works": (Mailer) ->
      assert.isObject Mailer
      return

    "it has a setup() method": (Mailer) ->
      assert.isFunction Mailer.setup
      return

    "it has a sendEmail() method": (Mailer) ->
      assert.isFunction Mailer.sendEmail
      return

    "and we setup the Mailer module to use the dummy":
      topic: (Mailer) ->
        log = new Logger(
          name: "mailer-test"
          streams: [path: "/dev/null"]
        )
        config =
          smtpuser: null
          smtppass: null
          smtpserver: "localhost"
          smtpport: 1623
          smtpusessl: false
          smtpusetls: true
          hostname: "pump.localhost"

        callback = @callback
        try
          Mailer.setup config, log
          callback null
        catch err
          callback err
        return

      "it works": (err) ->
        assert.ifError err
        return

      "and we send an email message":
        topic: (Mailer, smtp) ->
          callback = @callback
          message =
            to: "123@fakestreet.example"
            subject: "Please report for arrest"
            text: "We are coming to your house to arrest you"

          Step (->
            oneEmail smtp, message.to, @parallel()
            Mailer.sendEmail message, @parallel()
            return
          ), callback
          return

        "it works": (err, received, sent) ->
          assert.ifError err
          assert.isObject received
          assert.isObject sent
          return

        "and we send a bunch of email messages":
          topic: (received, sent, Mailer, smtp) ->
            callback = @callback
            Step (->
              i = undefined
              rgroup = @group()
              sgroup = @group()
              to = undefined
              message = undefined
              i = 1
              while i < 51
                to = (123 + i) + "@fakestreet.example"
                message =
                  to: to
                  subject: "Have you seen the perp?"
                  text: "We sent an email and the perp ran."

                oneEmail smtp, to, rgroup()
                Mailer.sendEmail message, sgroup()
                i++
              return
            ), callback
            return

          "it works": (err, receiveds, sents) ->
            assert.ifError err
            assert.isArray receiveds
            assert.isArray sents
            return
)
suite["export"] module
