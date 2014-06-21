# mailer.js
#
# mail-sending functionality for pump.io
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
email = require("emailjs")
Mailer = {}
maillog = undefined
from = undefined
smtp = undefined
q = undefined
Mailer.setup = (config, log) ->
  hostname = config.hostname
  mailopts =
    user: config.smtpuser or null
    password: config.smtppass or null
    host: config.smtpserver
    port: config.smtpport or 25
    ssl: config.smtpusessl or false
    tls: config.smtpusetls or true
    timeout: config.smtptimeout or 30000
    domain: hostname

  maillog = log.child(component: "mail")
  from = config.smtpfrom or "no-reply@" + hostname

  maillog.debug _.omit(mailopts, "password"), "Connecting to SMTP server"
  smtp = email.server.connect(mailopts)
  return

Mailer.sendEmail = (props, callback) ->
  message = _.extend(
    from: from
  , props)
  maillog.debug
    to: message.to or null
    subject: message.subject or null
  , "Sending email"
  smtp.send message, (err, results) ->
    if err
      maillog.error err
      maillog.error
        to: message.to or null
        subject: message.subject or null
        message: err.message
      , "Email error"
      callback err, null
    else
      maillog.info
        to: message.to or null
        subject: message.subject or null
      , "Message sent"
      callback null, results
    return

  return

module.exports = Mailer
