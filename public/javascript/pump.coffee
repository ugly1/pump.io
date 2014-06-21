# pump.js
#
# Entrypoint for the pump.io client UI
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

# Make sure this exists
window.Pump = {}  unless window.Pump
((_, $, Backbone, Pump) ->
  
  # This is overwritten by inline script in layout.utml
  Pump.config = {}
  
  # Main entry point
  $(document).ready ->
    
    # Set up router
    Pump.router = new Pump.Router()
    
    # Set up initial view
    Pump.body = new Pump.BodyView(el: $("body"))
    Pump.body.nav = new Pump.AnonymousNav(el: ".navbar-inner .container")
    
    # XXX: Make this more complete
    Pump.initialContentView()
    $("abbr.easydate").easydate()
    Backbone.history.start
      pushState: true
      silent: true

    Pump.setupWysiHTML5()
    
    # Refresh the streams automatically every 60 seconds
    # This is a fallback in case something gets lost in the
    # SockJS conversation
    Pump.refreshStreamsID = setInterval(Pump.refreshStreams, 60000)
    
    # Connect to current server
    Pump.setupSocket()  if Pump.config.sockjs
    Pump.setupInfiniteScroll()
    if Pump.principalUser
      Pump.principalUser = Pump.User.unique(Pump.principalUser)
      Pump.principal = Pump.Person.unique(Pump.principal)
      Pump.body.nav = new Pump.UserNav(
        el: Pump.body.$(".navbar-inner .container")
        model: Pump.principalUser
        data:
          messages: Pump.principalUser.majorDirectInbox
          notifications: Pump.principalUser.minorDirectInbox
      )
      
      # If we're on a login page, go to the main page or whatever
      switch window.location.pathname
        when "/main/login", "/main/register", "/main/remote"
          Pump.router.navigate Pump.getContinueTo(), true
        else
    else if Pump.principal
      Pump.principal = Pump.Person.unique(Pump.principal)
      Pump.body.nav = new Pump.RemoteNav(
        el: Pump.body.$(".navbar-inner .container")
        model: Pump.principal
      )
      
      # If we're on a login page, go to the main page or whatever
      switch window.location.pathname
        when "/main/login", "/main/register", "/main/remote"
          Pump.router.navigate Pump.getContinueTo(), true
        else
    else
      
      # Check if we have stored OAuth credentials
      Pump.ensureCred (err, cred) ->
        nickname = undefined
        pair = undefined
        if err
          Pump.error err
          return
        pair = Pump.getUserCred()
        if pair
          
          # We need to renew the session, for images and objects and so on.
          Pump.renewSession (err, data) ->
            user = undefined
            major = undefined
            minor = undefined
            if err
              Pump.error err
              Pump.clearUserCred()
              return
            user = Pump.principalUser = Pump.User.unique(data)
            Pump.principal = Pump.principalUser.profile
            major = user.majorDirectInbox
            minor = user.minorDirectInbox
            Pump.fetchObjects [
              major
              minor
            ], (err, objs) ->
              sp = undefined
              continueTo = undefined
              if err
                Pump.clearUserCred()
                Pump.error err
                return
              Pump.principalUser = user
              Pump.body.nav = new Pump.UserNav(
                el: ".navbar-inner .container"
                model: user
                data:
                  messages: major
                  notifications: minor
              )
              Pump.body.nav.render()
              
              # If we're on the login page, and there's a current
              # user, redirect to the actual page
              switch window.location.pathname
                when "/main/login"
                  Pump.body.content = new Pump.LoginContent()
                  continueTo = Pump.getContinueTo()
                  Pump.router.navigate continueTo, true
                when "/"
                  Pump.router.home()

            return

        return

    
    # If there's anything queued up in our onReady array, run it
    if Pump.onReady
      _.each Pump.onReady, (f) ->
        f()
        return

    return

  
  # Renew the cookie session
  Pump.renewSession = (callback) ->
    options =
      dataType: "json"
      type: "POST"
      url: "/main/renew"
      success: (data, textStatus, jqXHR) ->
        callback null, data
        return

      error: (jqXHR, textStatus, errorThrown) ->
        callback new Error("Failed to renew"), null
        return

    Pump.ajax options
    return

  
  # When errors happen, and you don't know what to do with them,
  # send them here and I'll figure it out.
  Pump.error = (err) ->
    msg = undefined
    if _.isString(err)
      msg = err
    else if _.isObject(err)
      msg = err.message
      console.log err.stack  if err.stack
    else
      msg = "An error occurred."
    console.log msg
    if Pump.body and Pump.body.nav
      $nav = Pump.body.nav.$el
      $alert = $("#error-popup")
      if $alert.length is 0
        $alert = $("<div id=\"error-popup\" class=\"alert-error\" style=\"display: none; margin-top: 0px; text-align: center\">" + "<button type=\"button\" class=\"close\" data-dismiss=\"alert\">&times;</button>" + "<span class=\"error-message\">" + msg + "</span>" + "</div>")
        $nav.after $alert
        $alert.slideDown "fast"
      else
        $(".error-message", $alert).text msg
    return

  
  # For debugging output
  Pump.debug = (msg) ->
    console.log msg  if Pump.config.debugClient and window.console
    return

  
  # Given a relative URL like /main/register, make a fully-qualified
  # URL on the current server
  Pump.fullURL = (url) ->
    here = window.location
    if url.indexOf(":") is -1
      if url.substr(0, 1) is "/"
        url = here.protocol + "//" + here.host + url
      else
        url = here.href.substr(0, here.href.lastIndexOf("/") + 1) + url
    url

  
  # Add some OAuth magic to the arguments for a $.ajax() call
  Pump.oauthify = (options) ->
    options.url = Pump.fullURL(options.url)
    message =
      action: options.url
      method: options.type
      parameters: [
        [
          "oauth_version"
          "1.0"
        ]
        [
          "oauth_consumer_key"
          options.consumerKey
        ]
      ]

    if options.token
      message.parameters.push [
        "oauth_token"
        options.token
      ]
    OAuth.setTimestampAndNonce message
    OAuth.SignatureMethod.sign message,
      consumerSecret: options.consumerSecret
      tokenSecret: options.tokenSecret

    header = OAuth.getAuthorizationHeader("OAuth", message.parameters)
    options.headers = Authorization: header
    options

  Pump.fetchObjects = (orig, callback) ->
    fetched = 0
    objs = (if (orig.length) > 0 then orig.slice(0) else []) # make a dupe in case arg is changed
    count = objs.length
    done = false
    onSuccess = ->
      unless done
        fetched++
        if fetched >= count
          done = true
          callback null, objs
      return

    onError = (xhr, status, thrown) ->
      unless done
        done = true
        if thrown
          callback thrown, null
        else
          callback new Error(status), null
      return

    _.each objs, (obj) ->
      try
        if _.isFunction(obj.prevLink) and obj.prevLink()
          obj.getPrev (err) ->
            if err
              onError null, null, err
            else
              if obj.items.length < 20 and _.isFunction(obj.nextLink) and obj.nextLink()
                obj.getNext (err) ->
                  if err
                    onError null, null, err
                  else
                    onSuccess()
                  return

              else
                onSuccess()
            return

        else
          obj.fetch
            update: true
            success: onSuccess
            error: onError

      catch e
        onError null, null, e
      return

    return

  
  # Not the most lovely, but it works
  # XXX: change this to use UTML templating instead
  Pump.wysihtml5Tmpl = emphasis: (locale) ->
    "<li>" + "<div class='btn-group'>" + "<a class='btn' data-wysihtml5-command='bold' title='" + locale.emphasis.bold + "'><i class='icon-bold'></i></a>" + "<a class='btn' data-wysihtml5-command='italic' title='" + locale.emphasis.italic + "'><i class='icon-italic'></i></a>" + "<a class='btn' data-wysihtml5-command='underline' title='" + locale.emphasis.underline + "'>_</a>" + "</div>" + "</li>"

  
  # Most long-form descriptions and notes use this lib for editing
  Pump.setupWysiHTML5 = ->
    
    # Set wysiwyg defaults
    $.fn.wysihtml5.defaultOptions["font-styles"] = false
    $.fn.wysihtml5.defaultOptions["image"] = false
    $.fn.wysihtml5.defaultOptions["customTemplates"] = Pump.wysihtml5Tmpl
    return

  
  # Turn the querystring into an object
  Pump.searchParams = (str) ->
    params = {}
    pl = /\+/g
    decode = (s) ->
      decodeURIComponent s.replace(pl, " ")

    pairs = undefined
    str = window.location.search  unless str
    pairs = str.substr(1).split("&")
    _.each pairs, (pairStr) ->
      pair = pairStr.split("=", 2)
      key = decode(pair[0])
      value = (if (pair.length > 1) then decode(pair[1]) else null)
      params[key] = value
      return

    params

  Pump.continueTo = null
  
  # Get the "continue" param
  Pump.getContinueTo = ->
    sp = Pump.searchParams()
    continueTo = (if (_.has(sp, "continue")) then sp["continue"] else null)
    if continueTo and continueTo.length > 0 and continueTo[0] is "/"
      continueTo
    else if Pump.continueTo
      continueTo = Pump.continueTo
      continueTo
    else
      ""

  Pump.saveContinueTo = ->
    Pump.continueTo = window.location.pathname + window.location.search
    return

  Pump.clearContinueTo = ->
    Pump.continueTo = null
    return

  
  # We clear out cached stuff when login state changes
  Pump.clearCaches = ->
    Pump.Model.clearCache()
    Pump.User.clearCache()
    return

  Pump.ajax = (options) ->
    jqxhr = undefined
    
    # For remote users, we use session auth
    if Pump.principal and not Pump.principalUser and options.type is "GET"
      jqxhr = $.ajax(options)
      options.started jqxhr  if _.isFunction(options.started)
    else
      Pump.ensureCred (err, cred) ->
        pair = undefined
        if err
          Pump.error "Couldn't get OAuth credentials. :("
        else
          options.consumerKey = cred.clientID
          options.consumerSecret = cred.clientSecret
          pair = Pump.getUserCred()
          if pair
            options.token = pair.token
            options.tokenSecret = pair.secret
          options = Pump.oauthify(options)
          jqxhr = $.ajax(options)
          options.started jqxhr  if _.isFunction(options.started)
        return

    return

  Pump.setupInfiniteScroll = ->
    didScroll = false
    
    # scroll fires too fast, so just use the handler
    # to set a flag, and check that flag with an interval
    
    # From http://ejohn.org/blog/learning-from-twitter/
    $(window).scroll ->
      didScroll = true
      return

    setInterval (->
      streams = undefined
      if didScroll
        didScroll = false
        if $(window).scrollTop() >= $(document).height() - $(window).height() - 10
          streams = Pump.getStreams()
          if streams.major and streams.major.nextLink()
            Pump.body.startLoad()
            streams.major.getNext (err) ->
              Pump.body.endLoad()
              return

      return
    ), 250
    return

  
  # XXX: this is cheeseball.
  Pump.rel = (url) ->
    a = document.createElement("a")
    pathname = undefined
    a.href = url
    pathname = a.pathname
    pathname

  Pump.htmlEncode = (value) ->
    $("<div/>").text(value).html()

  Pump.htmlDecode = (value) ->
    $("<div/>").html(value).text()

  
  # Sets up the initial view and sub-views
  Pump.initialContentView = ->
    $content = $("#content")
    selectorToView =
      "#main":
        View: Pump.MainContent

      "#loginpage":
        View: Pump.LoginContent

      "#registerpage":
        View: Pump.RegisterContent

      "#recoverpage":
        View: Pump.RecoverContent

      "#recoversentpage":
        View: Pump.RecoverSentContent

      "#recover-code":
        View: Pump.RecoverCodeContent

      "#inbox":
        View: Pump.InboxContent
        models:
          major: Pump.ActivityStream
          minor: Pump.ActivityStream

      ".object-page":
        View: Pump.ObjectContent
        models:
          object: Pump.ActivityObject

      ".major-activity-page":
        View: Pump.ActivityContent
        models:
          activity: Pump.Activity

      ".user-activities":
        View: Pump.UserPageContent
        models:
          profile: Pump.Person
          major: Pump.ActivityStream
          minor: Pump.ActivityStream

      ".user-favorites":
        View: Pump.FavoritesContent
        models:
          profile: Pump.Person
          favorites: Pump.ActivityObjectStream

      ".user-followers":
        View: Pump.FollowersContent
        models:
          profile: Pump.Person
          followers: Pump.PeopleStream

      ".user-following":
        View: Pump.FollowingContent
        models:
          profile: Pump.Person
          following: Pump.PeopleStream

      ".user-lists":
        View: Pump.ListsContent
        models:
          profile: Pump.Person
          lists: Pump.ActivityObjectStream

      ".user-list":
        View: Pump.ListContent
        models:
          profile: Pump.Person
          lists: Pump.ActivityObjectStream
          members: Pump.PeopleStream
          list: Pump.ActivityObject

    selector = undefined
    $el = undefined
    model = undefined
    options = undefined
    def = undefined
    data = undefined
    View = undefined
    
    # When I say "view" the crowd say "selector"
    for selector of selectorToView
      if _.has(selectorToView, selector)
        $el = $content.find(selector)
        if $el.length > 0
          def = selectorToView[selector]
          View = def.View
          options =
            el: $el
            data: {}

          data = Pump.initialData
          _.each data, (value, name) ->
            if name is View::modelName
              options.model = def.models[name].unique(value)
            else if def.models[name]
              options.data[name] = def.models[name].unique(value)
            else
              options.data[name] = value
            return

          Pump.body.content = new View(options)
          Pump.initialData = null
          break
    return

  
  # XXX: set up initial data
  Pump.newMinorActivity = (act, callback) ->
    if Pump.principalUser
      Pump.addToStream Pump.principalUser.minorStream, act, callback
    else
      Pump.proxyActivity act, callback
    return

  Pump.newMajorActivity = (act, callback) ->
    if Pump.principalUser
      Pump.addToStream Pump.principalUser.majorStream, act, callback
    else
      Pump.proxyActivity act, callback
    return

  Pump.addToStream = (stream, act, callback) ->
    stream.items.create act,
      wait: true
      success: (act) ->
        callback null, act
        return

      error: (model, xhr, options) ->
        type = undefined
        response = undefined
        type = xhr.getResponseHeader("Content-Type")
        if type and type.indexOf("application/json") isnt -1
          response = JSON.parse(xhr.responseText)
          callback new Error(response.error), null
        else
          callback new Error("Error saving activity: " + model.id), null
        return

    return

  
  # XXX: This POSTs with session auth; subject to XSS.
  Pump.proxyActivity = (act, callback) ->
    $.ajax
      contentType: "application/json"
      data: JSON.stringify(act)
      dataType: "json"
      type: "POST"
      url: "/main/proxy"
      success: (act) ->
        callback null, act
        return

      error: (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        type = jqXHR.getResponseHeader("Content-Type")
        if type and type.indexOf("application/json") isnt -1
          response = JSON.parse(jqXHR.responseText)
          callback new Error(response.error), null
        else
          callback new Error(errorThrown), null
        return

    return

  Pump.setTitle = (title) ->
    
    # We don't accept HTML in title or site name; just text
    $("title").text title + " - " + Pump.config.site
    return

  Pump.ajaxError = (jqXHR, textStatus, errorThrown) ->
    Pump.error Pump.jqxhrError(jqXHR)
    return

  Pump.jqxhrError = (jqxhr) ->
    type = jqxhr.getResponseHeader("Content-Type")
    response = undefined
    if type and type.indexOf("application/json") isnt -1
      try
        response = JSON.parse(jqxhr.responseText)
        Pump.error new Error(response.error)
      catch err
        Pump.error new Error(jqxhr.status + ": " + jqxhr.statusText)
    else
      Pump.error new Error(jqxhr.status + ": " + jqxhr.statusText)
    return

  return
) window._, window.$, window.Backbone, window.Pump
