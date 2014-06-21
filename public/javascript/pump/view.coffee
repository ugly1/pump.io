# pump/view.js
#
# Views for the pump.io client UI
#
# Copyright 2011-2013, E14N https://e14n.com/
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

# XXX: this needs to be broken up into 3-4 smaller modules
((_, $, Backbone, Pump) ->
  Pump.templates = {}
  Pump.TemplateError = (template, data, err) ->
    Error.captureStackTrace this, Pump.TemplateError  if Error.captureStackTrace
    @name = "TemplateError"
    @template = template
    @data = data
    @wrapped = err
    @message = ((if (_.has(template, "templateName")) then template.templateName else "unknown-template")) + ": " + err.message
    return

  Pump.TemplateError:: = new Error()
  Pump.TemplateError::constructor = Pump.TemplateError
  Pump.TemplateView = Backbone.View.extend(
    initialize: (options) ->
      view = this
      if _.has(view, "model") and _.isObject(view.model)
        view.listenTo view.model, "change", (model, options) ->
          Pump.debug "Re-rendering " + view.templateName + " #" + view.cid + " based on change to " + view.model.id
          
          # When a change has happened, re-render
          view.render()
          return

        view.listenTo view.model, "destroy", (options) ->
          Pump.debug "Re-rendering " + view.templateName + " based on destroyed " + view.model.id
          
          # When a change has happened, re-render
          view.remove()
          return

        if _.has(view.model, "items") and _.isObject(view.model.items)
          view.listenTo view.model.items, "add", (model, collection, options) ->
            Pump.debug "Re-rendering " + view.templateName + " based on addition to " + view.model.id
            view.showAdded model
            return

          view.listenTo view.model.items, "remove", (model, collection, options) ->
            Pump.debug "Re-rendering " + view.templateName + " based on removal from " + view.model.id
            view.showRemoved model
            return

          view.listenTo view.model.items, "reset", (collection, options) ->
            Pump.debug "Re-rendering " + view.templateName + " based on reset of " + view.model.id
            
            # When a change has happened, re-render
            view.render()
            return

          view.listenTo view.model.items, "sort", (collection, options) ->
            Pump.debug "Re-rendering " + view.templateName + " based on resort of " + view.model.id
            
            # When a change has happened, re-render
            view.render()
            return

      return

    setElement: (element, delegate) ->
      Backbone.View::setElement.apply this, arguments_
      if element
        @ready()
        @trigger "ready"
      return

    templateName: null
    parts: null
    subs: {}
    ready: ->
      
      # setup subViews
      @setupSubs()
      return

    setupSubs: ->
      view = this
      data = view.options.data
      subs = view.subs
      return  unless subs
      _.each subs, (def, selector) ->
        $el = view.$(selector)
        options = undefined
        sub = undefined
        id = undefined
        if def.attr and view[def.attr]
          view[def.attr].setElement $el
          return
        if def.idAttr and view.model and view.model.items
          view[def.map] = {}  unless view[def.map]  if def.map
          $el.each (i, el) ->
            id = $(el).attr(def.idAttr)
            options = el: el
            return  unless id
            options.model = view.model.items.get(id)
            return  unless options.model
            if def.subOptions
              if def.subOptions.data
                options.data = {}
                _.each def.subOptions.data, (item) ->
                  if item is view.modelName
                    options.data[item] = view.model.items or view.model
                  else
                    options.data[item] = data[item]
                  return

            sub = new Pump[def.subView](options)
            view[def.map][id] = sub  if def.map
            return

          return
        options = el: $el
        if def.subOptions
          options.model = data[def.subOptions.model]  if def.subOptions.model
          if def.subOptions.data
            options.data = {}
            _.each def.subOptions.data, (item) ->
              options.data[item] = data[item]
              return

        sub = new Pump[def.subView](options)
        view[def.attr] = sub  if def.attr
        return

      return

    render: ->
      view = this
      getTemplate = (name, cb) ->
        url = undefined
        if _.has(Pump.templates, name)
          cb null, Pump.templates[name]
        else
          $.get "/template/" + name + ".utml", (data) ->
            f = undefined
            try
              f = _.template(data)
              f.templateName = name
              Pump.templates[name] = f
            catch err
              cb err, null
              return
            cb null, f
            return

        return

      getTemplateSync = (name) ->
        f = undefined
        data = undefined
        res = undefined
        if _.has(Pump.templates, name)
          Pump.templates[name]
        else
          res = $.ajax(
            url: "/template/" + name + ".utml"
            async: false
          )
          if res.readyState is 4 and ((res.status >= 200 and res.status < 300) or res.status is 304)
            data = res.responseText
            f = _.template(data)
            f.templateName = name
            Pump.templates[name] = f
          f

      runTemplate = (template, data, cb) ->
        html = undefined
        try
          html = template(data)
        catch err
          if err instanceof Pump.TemplateError
            cb err, null
          else
            cb new Pump.TemplateError(template, data, err), null
          return
        cb null, html
        return

      setOutput = (err, html) ->
        if err
          Pump.error err
        else
          
          # Triggers "ready"
          view.setHTML html
          
          # Update relative to the new code view
          view.$("abbr.easydate").easydate()
        return

      main =
        config: Pump.config
        template: {}
        page:
          url: window.location.pathname + window.location.search
          title: window.document.title

      pc = undefined
      modelName = view.modelName or view.options.modelName or "model"
      partials = {}
      cnt = undefined
      main[modelName] = (if (not view.model) then {} else ((if (view.model.toJSON) then view.model.toJSON() else view.model)))  if view.model
      if _.has(view.options, "data")
        _.each view.options.data, (obj, name) ->
          if _.isObject(obj) and obj.toJSON
            main[name] = obj.toJSON()
          else
            main[name] = obj
          return

      main.principalUser = (if (Pump.principalUser) then Pump.principalUser.toJSON() else null)
      main.principal = (if (Pump.principal) then Pump.principal.toJSON() else null)
      main.partial = (name, locals) ->
        template = undefined
        scoped = undefined
        html = undefined
        if locals
          scoped = _.clone(locals)
          _.extend scoped, main
        else
          scoped = main
        unless _.has(partials, name)
          Pump.debug "Didn't preload template " + name + " for " + view.templateName + " so fetching sync"
          
          # XXX: Put partials in the parts array of the
          # view to avoid this shameful sync call
          partials[name] = getTemplateSync(name)
        template = partials[name]
        throw new Error("No template for " + name)  unless template
        try
          html = template(scoped)
          return html
        catch e
          if e instanceof Pump.TemplateError
            throw e
          else
            throw new Pump.TemplateError(template, scoped, e)
        return

      
      # XXX: set main.page.title
      
      # If there are sub-parts, we do them in parallel then
      # do the main one. Note: only one level.
      if view.parts
        pc = 0
        cnt = _.keys(view.parts).length
        _.each view.parts, (templateName) ->
          getTemplate templateName, (err, template) ->
            if err
              Pump.error err
            else
              pc++
              partials[templateName] = template
              if pc >= cnt
                getTemplate view.templateName, (err, template) ->
                  if err
                    Pump.error err
                    return
                  runTemplate template, main, setOutput
                  return

            return

          return

      else
        getTemplate view.templateName, (err, template) ->
          if err
            Pump.error err
            return
          runTemplate template, main, setOutput
          return

      this

    stopSpin: ->
      @$(":submit").prop("disabled", false).spin false
      return

    startSpin: ->
      @$(":submit").prop("disabled", true).spin true
      return

    showAlert: (msg, type) ->
      view = this
      view.$(".alert").remove()  if view.$(".alert").length > 0
      type = type or "error"
      view.$("legend").after "<div class=\"alert alert-" + type + "\">" + "<a class=\"close\" data-dismiss=\"alert\" href=\"#\">&times;</a>" + "<p class=\"alert-message\">" + msg + "</p>" + "</div>"
      view.$(".alert").alert()
      return

    showError: (msg) ->
      view = this
      if view.$(".alert").length > 0
        view.showAlert msg, "error"
      else
        Pump.error msg
      return

    showSuccess: (msg) ->
      @showAlert msg, "success"
      return

    setHTML: (html) ->
      view = this
      $old = view.$el
      $new = $(html).first()
      $old.replaceWith $new
      view.setElement $new
      $old = null
      return

    showAdded: (model) ->
      view = this
      id = model.get("id")
      subs = view.subs
      data = view.options.data
      options = undefined
      aview = undefined
      def = undefined
      selector = undefined
      
      # Strange!
      return  unless subs
      return  if not view.model or not view.model.items
      
      # Find the first def and selector with a map
      _.each subs, (subDef, subSelector) ->
        if subDef.map
          def = subDef
          selector = subSelector
        return

      return  unless def
      view[def.map] = {}  unless view[def.map]
      
      # If we already have it, skip
      return  if _.has(view[def.map], id)
      options = model: model
      if def.subOptions
        if def.subOptions.data
          options.data = {}
          _.each def.subOptions.data, (item) ->
            options.data[item] = data[item]
            return

      
      # Show the new item
      aview = new Pump[def.subView](options)
      
      # Stash the view
      view[def.map][model.id] = aview
      
      # When it's rendered, stick it where it goes
      aview.on "ready", ->
        idx = undefined
        $el = view.$(selector)
        aview.$el.hide()
        view.placeSub aview, $el
        aview.$el.fadeIn "slow"
        return

      aview.render()
      return

    placeSub: (aview, $el) ->
      view = this
      model = aview.model
      idx = view.model.items.indexOf(model)
      if idx <= 0
        view.$el.prepend aview.$el
      else if idx >= $el.length
        view.$el.append aview.$el
      else
        aview.$el.insertBefore $el[idx]
      return

    showRemoved: (model) ->
      view = this
      id = model.get("id")
      aview = undefined
      def = undefined
      selector = undefined
      subs = view.subs
      
      # Possible but not likely
      return  unless subs
      return  if not view.model or not view.model.items
      
      # Find the first def and selector with a map
      _.each subs, (subDef, subSelector) ->
        if subDef.map
          def = subDef
          selector = subSelector
        return

      return  unless def
      view[def.map] = {}  unless view[def.map]
      return  unless _.has(view[def.map], id)
      
      # Remove it from the DOM
      view[def.map][id].remove()
      
      # delete that view from our map
      delete view[def.map][id]

      return
  )
  Pump.NavView = Pump.TemplateView.extend(getStreams: ->
    {}
  )
  Pump.AnonymousNav = Pump.NavView.extend(
    tagName: "div"
    className: "container"
    templateName: "nav-anonymous"
  )
  Pump.UserNav = Pump.NavView.extend(
    tagName: "div"
    className: "container"
    modelName: "user"
    templateName: "nav-loggedin"
    parts: [
      "messages"
      "notifications"
    ]
    subs:
      "#messages":
        attr: "majorStreamView"
        subView: "MessagesView"
        subOptions:
          model: "messages"

      "#notifications":
        attr: "minorStreamView"
        subView: "NotificationsView"
        subOptions:
          model: "notifications"

    events:
      "click #logout": "logout"
      "click #post-note-button": "postNoteModal"
      "click #post-picture-button": "postPictureModal"

    postNoteModal: ->
      view = this
      view.showPostingModal "#post-note-button", Pump.PostNoteModal
      return

    postPictureModal: ->
      view = this
      view.showPostingModal "#post-picture-button", Pump.PostPictureModal
      return

    showPostingModal: (btn, Cls) ->
      view = this
      profile = Pump.principal
      lists = profile.lists
      startSpin = ->
        view.$(btn).prop("disabled", true).spin true
        return

      stopSpin = ->
        view.$(btn).prop("disabled", false).spin false
        return

      startSpin()
      Pump.fetchObjects [lists], (err, objs) ->
        if err
          view.showError err
          stopSpin()
        else
          Pump.showModal Cls,
            data:
              user: Pump.principalUser
              lists: lists

            ready: ->
              stopSpin()
              return

        return

      false

    logout: ->
      view = this
      options = undefined
      onSuccess = (data, textStatus, jqXHR) ->
        an = undefined
        Pump.principalUser = null
        Pump.principal = null
        Pump.clearNickname()
        Pump.clearUserCred()
        Pump.clearCaches()
        an = new Pump.AnonymousNav(el: ".navbar-inner .container")
        an.render()
        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        if window.location.pathname is "/"
          
          # If already home, reload to show main page
          Pump.router.home()
        else
          
          # Go home
          Pump.router.navigate "/", true
        return

      options =
        contentType: "application/json"
        data: ""
        dataType: "json"
        type: "POST"
        url: "/main/logout"
        success: onSuccess
        error: Pump.ajaxError

      Pump.ajax options
      return

    getStreams: ->
      view = this
      streams = {}
      streams.messages = view.majorStreamView.model  if view.majorStreamView and view.majorStreamView.model
      streams.notifications = view.minorStreamView.model  if view.minorStreamView and view.minorStreamView.model
      streams
  )
  Pump.RemoteNav = Pump.NavView.extend(
    tagName: "div"
    className: "container"
    templateName: "nav-remote"
    events:
      "click #logout": "logout"

    logout: ->
      view = this
      options = undefined
      onSuccess = (data, textStatus, jqXHR) ->
        an = undefined
        Pump.principal = null
        Pump.clearCaches()
        an = new Pump.AnonymousNav(el: ".navbar-inner .container")
        an.render()
        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        if window.location.pathname is "/"
          
          # If already home, reload to show main page
          Pump.router.home()
        else
          
          # Go home
          Pump.router.navigate "/", true
        return

      options =
        contentType: "application/json"
        data: ""
        dataType: "json"
        type: "POST"
        url: "/main/logout"
        success: onSuccess
        error: Pump.ajaxError

      
      # Don't use Pump.ajax; it uses client auth
      $.ajax options
      return
  )
  Pump.MessagesView = Pump.TemplateView.extend(
    templateName: "messages"
    modelName: "messages"
  )
  Pump.NotificationsView = Pump.TemplateView.extend(
    templateName: "notifications"
    modelName: "notifications"
  )
  Pump.ContentView = Pump.TemplateView.extend(
    addMajorActivity: (act) ->

    
    # By default, do nothing
    addMinorActivity: (act) ->

    
    # By default, do nothing
    getStreams: ->
      {}
  )
  Pump.MainContent = Pump.ContentView.extend(templateName: "main")
  Pump.LoginContent = Pump.ContentView.extend(
    templateName: "login"
    events:
      "submit #login": "doLogin"
      "keyup #password": "onKey"
      "keyup #nickname": "onKey"

    ready: ->
      view = this
      
      # setup subViews
      view.setupSubs()
      
      # Initialize state of login button
      view.onKey()
      return

    onKey: (event) ->
      view = this
      nickname = view.$("#nickname").val()
      password = view.$("#password").val()
      if not nickname or not password or nickname.length is 0 or password.length < 8
        view.$(":submit").attr "disabled", "disabled"
      else
        view.$(":submit").removeAttr "disabled"
      return

    doLogin: ->
      view = this
      params =
        nickname: view.$("#login input[name=\"nickname\"]").val()
        password: view.$("#login input[name=\"password\"]").val()

      options = undefined
      continueTo = Pump.getContinueTo()
      NICKNAME_RE = /^[a-zA-Z0-9\-_.]{1,64}$/
      retries = 0
      onSuccess = (data, textStatus, jqXHR) ->
        objs = undefined
        Pump.setNickname data.nickname
        Pump.setUserCred data.token, data.secret
        Pump.clearCaches()
        Pump.principalUser = Pump.User.unique(data)
        Pump.principal = Pump.principalUser.profile
        objs = [
          Pump.principalUser
          Pump.principalUser.majorDirectInbox
          Pump.principalUser.minorDirectInbox
        ]
        Pump.fetchObjects objs, (err, objs) ->
          Pump.body.nav = new Pump.UserNav(
            el: ".navbar-inner .container"
            model: Pump.principalUser
            data:
              messages: Pump.principalUser.majorDirectInbox
              notifications: Pump.principalUser.minorDirectInbox
          )
          Pump.body.nav.render()
          return

        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        
        # XXX: reload current data
        view.stopSpin()
        Pump.router.navigate continueTo, true
        Pump.clearContinueTo()
        return

      onError = (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        
        # This happens when our stored OAuth credentials are
        # invalid; usually because someone re-installed server software
        if jqXHR.status is 401 and retries is 0 and jqXHR.responseText is "Invalid / used nonce"
          Pump.clearCred()
          retries = 1
          Pump.ajax options
        else
          view.stopSpin()
          Pump.ajaxError jqXHR, textStatus, errorThrown
        return

      view.startSpin()
      options =
        contentType: "application/json"
        data: JSON.stringify(params)
        dataType: "json"
        type: "POST"
        url: "/main/login"
        success: onSuccess
        error: onError

      Pump.ajax options
      false
  )
  Pump.RegisterContent = Pump.ContentView.extend(
    templateName: "register"
    events:
      "submit #registration": "register"

    register: ->
      view = this
      params =
        nickname: view.$("#registration input[name=\"nickname\"]").val()
        password: view.$("#registration input[name=\"password\"]").val()

      repeat = view.$("#registration input[name=\"repeat\"]").val()
      email = (if (Pump.config.requireEmail) then view.$("#registration input[name=\"email\"]").val() else null)
      options = undefined
      retries = 0
      NICKNAME_RE = /^[a-zA-Z0-9\-_.]{1,64}$/
      makeRequest = (options) ->
        Pump.ensureCred (err, cred) ->
          if err
            view.stopSpin()
            view.showError "Couldn't get OAuth credentials. :("
          else
            options.consumerKey = cred.clientID
            options.consumerSecret = cred.clientSecret
            options = Pump.oauthify(options)
            $.ajax options
          return

        return

      onSuccess = (data, textStatus, jqXHR) ->
        objs = undefined
        if Pump.config.requireEmail
          Pump.body.setContent
            contentView: Pump.ConfirmEmailInstructionsContent
            title: "Confirm email"

          return
        Pump.setNickname data.nickname
        Pump.setUserCred data.token, data.secret
        Pump.clearCaches()
        Pump.principalUser = Pump.User.unique(data)
        Pump.principal = Pump.principalUser.profile
        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        objs = [
          Pump.principalUser
          Pump.principalUser.majorDirectInbox
          Pump.principalUser.minorDirectInbox
        ]
        Pump.fetchObjects objs, (err, objs) ->
          Pump.body.nav = new Pump.UserNav(
            el: ".navbar-inner .container"
            model: Pump.principalUser
            data:
              messages: Pump.principalUser.majorDirectInbox
              notifications: Pump.principalUser.minorDirectInbox
          )
          Pump.body.nav.render()
          return

        Pump.body.nav.render()
        
        # Leave disabled
        view.stopSpin()
        
        # XXX: one-time on-boarding page
        Pump.router.navigate Pump.getContinueTo(), true
        Pump.clearContinueTo()
        return

      onError = (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        
        # If we get this error, it (usually!) means our client credentials are bad.
        # Get new credentials and retry (once!).
        if jqXHR.status is 401 and retries is 0
          Pump.clearCred()
          makeRequest options
          retries = 1
        else
          view.stopSpin()
          Pump.ajaxError jqXHR, textStatus, errorThrown
        return

      if params.password isnt repeat
        view.showError "Passwords don't match."
      else unless NICKNAME_RE.test(params.nickname)
        view.showError "Nicknames have to be a combination of 1-64 letters or numbers and ., - or _."
      else if params.password.length < 8
        view.showError "Password must be 8 chars or more."
      else if /^[a-z]+$/.test(params.password.toLowerCase()) or /^[0-9]+$/.test(params.password)
        view.showError "Passwords have to have at least one letter and one number."
      else if Pump.config.requireEmail and (not email or email.length is 0)
        view.showError "Email address required."
      else
        params.email = email  if Pump.config.requireEmail
        view.startSpin()
        options =
          contentType: "application/json"
          data: JSON.stringify(params)
          dataType: "json"
          type: "POST"
          url: "/main/register"
          success: onSuccess
          error: onError

        makeRequest options
      false
  )
  Pump.RemoteContent = Pump.ContentView.extend(
    templateName: "remote"
    ready: ->
      view = this
      
      # setup subViews
      view.setupSubs()
      
      # Initialize continueTo
      view.addContinueTo()
      return

    addContinueTo: ->
      view = this
      continueTo = Pump.getContinueTo()
      view.$("form#remote").append $("<input type='hidden' name='continueTo' value='" + Pump.htmlEncode(continueTo) + "'>")  if continueTo and continueTo.length > 0
      return
  )
  Pump.RecoverContent = Pump.ContentView.extend(
    templateName: "recover"
    events:
      "submit #recover": "doRecover"
      "keyup #nickname": "onKey"

    ready: ->
      view = this
      
      # setup subViews
      view.setupSubs()
      
      # Initialize state of recover button
      view.onKey()
      return

    onKey: (event) ->
      view = this
      nickname = view.$("#nickname").val()
      if not nickname or nickname.length is 0
        view.$(":submit").attr "disabled", "disabled"
      else
        view.$(":submit").removeAttr "disabled"
      return

    doRecover: ->
      view = this
      params = nickname: view.$("#recover input[name=\"nickname\"]").val()
      options = undefined
      continueTo = Pump.getContinueTo()
      NICKNAME_RE = /^[a-zA-Z0-9\-_.]{1,64}$/
      retries = 0
      onSuccess = (data, textStatus, jqXHR) ->
        Pump.router.navigate "/main/recover-sent", true
        return

      onError = (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        
        # This happens when our stored OAuth credentials are
        # invalid; usually because someone re-installed server software
        if jqXHR.status is 401 and retries is 0 and jqXHR.responseText is "Invalid / used nonce"
          Pump.clearCred()
          retries = 1
          Pump.ajax options
        else
          view.stopSpin()
          Pump.ajaxError jqXHR, textStatus, errorThrown
        return

      view.startSpin()
      options =
        contentType: "application/json"
        data: JSON.stringify(params)
        dataType: "json"
        type: "POST"
        url: "/main/recover"
        success: onSuccess
        error: onError

      Pump.ajax options
      false
  )
  Pump.RecoverSentContent = Pump.ContentView.extend(templateName: "recover-sent")
  Pump.RecoverCodeContent = Pump.ContentView.extend(
    templateName: "recover-code"
    ready: ->
      view = this
      
      # setup subViews
      view.setupSubs()
      
      # Initialize state of recover button
      view.redeemCode()
      return

    redeemCode: ->
      view = this
      params = code: view.$el.data("code")
      options = undefined
      retries = 0
      onSuccess = (data, textStatus, jqXHR) ->
        objs = undefined
        Pump.setNickname data.nickname
        Pump.setUserCred data.token, data.secret
        Pump.clearCaches()
        Pump.principalUser = Pump.User.unique(data)
        Pump.principal = Pump.principalUser.profile
        objs = [
          Pump.principalUser
          Pump.principalUser.majorDirectInbox
          Pump.principalUser.minorDirectInbox
        ]
        Pump.fetchObjects objs, (err, objs) ->
          Pump.body.nav = new Pump.UserNav(
            el: ".navbar-inner .container"
            model: Pump.principalUser
            data:
              messages: Pump.principalUser.majorDirectInbox
              notifications: Pump.principalUser.minorDirectInbox
          )
          Pump.body.nav.render()
          return

        
        # Request a new challenge
        Pump.setupSocket()  if Pump.config.sockjs
        
        # XXX: reload current data
        view.stopSpin()
        Pump.router.navigate "/main/account", true
        return

      onError = (jqXHR, textStatus, errorThrown) ->
        type = undefined
        response = undefined
        
        # This happens when our stored OAuth credentials are
        # invalid; usually because someone re-installed server software
        if jqXHR.status is 401 and retries is 0 and jqXHR.responseText is "Invalid / used nonce"
          Pump.clearCred()
          retries = 1
          Pump.ajax options
        else
          view.stopSpin()
          Pump.ajaxError jqXHR, textStatus, errorThrown
        return

      view.startSpin()
      console.log params
      options =
        contentType: "application/json"
        data: JSON.stringify(params)
        dataType: "json"
        type: "POST"
        url: "/main/redeem-code"
        success: onSuccess
        error: onError

      Pump.ajax options
      false
  )
  Pump.ConfirmEmailInstructionsContent = Pump.ContentView.extend(templateName: "confirm-email-instructions")
  Pump.UserPageContent = Pump.ContentView.extend(
    templateName: "user"
    parts: [
      "profile-block"
      "profile-nav"
      "user-content-activities"
      "major-stream"
      "minor-stream"
      "major-activity"
      "minor-activity"
      "responses"
      "reply"
      "replies"
      "profile-responses"
      "activity-object-list"
      "activity-object-collection"
    ]
    addMajorActivity: (act) ->
      view = this
      profile = @options.data.profile
      return  if not profile or act.actor.id isnt profile.get("id")
      view.userContent.majorStreamView.showAdded act
      return

    addMinorActivity: (act) ->
      view = this
      profile = @options.data.profile
      return  if not profile or act.actor.id isnt profile.get("id")
      view.userContent.minorStreamView.showAdded act
      return

    getStreams: ->
      view = this
      uc = undefined
      streams = {}
      if view.userContent
        uc = view.userContent
        streams.major = uc.majorStreamView.model  if uc.majorStreamView and uc.majorStreamView.model
        streams.minor = uc.minorStreamView.model  if uc.minorStreamView and uc.minorStreamView.model
      streams

    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-activities":
        attr: "userContent"
        subView: "ActivitiesUserContent"
        subOptions:
          data: [
            "major"
            "minor"
            "headless"
          ]
  )
  Pump.ActivitiesUserContent = Pump.TemplateView.extend(
    templateName: "user-content-activities"
    parts: [
      "major-stream"
      "minor-stream"
      "major-activity"
      "minor-activity"
      "responses"
      "reply"
      "replies"
      "profile-responses"
      "activity-object-list"
      "activity-object-collection"
    ]
    subs:
      "#major-stream":
        attr: "majorStreamView"
        subView: "MajorStreamView"
        subOptions:
          model: "major"
          data: ["headless"]

      "#minor-stream":
        attr: "minorStreamView"
        subView: "MinorStreamView"
        subOptions:
          model: "minor"
          data: ["headless"]
  )
  Pump.MajorStreamView = Pump.TemplateView.extend(
    templateName: "major-stream"
    modelName: "activities"
    parts: [
      "major-activity"
      "responses"
      "reply"
      "replies"
      "activity-object-list"
      "activity-object-collection"
    ]
    subs:
      ".activity.major":
        map: "activities"
        subView: "MajorActivityView"
        idAttr: "data-activity-id"
        subOptions:
          data: ["headless"]
  )
  Pump.MinorStreamView = Pump.TemplateView.extend(
    templateName: "minor-stream"
    modelName: "activities"
    parts: ["minor-activity"]
    subs:
      ".activity.minor":
        map: "activities"
        subView: "MinorActivityView"
        idAttr: "data-activity-id"
        subOptions:
          data: ["headless"]
  )
  Pump.InboxContent = Pump.ContentView.extend(
    templateName: "inbox"
    parts: [
      "major-stream"
      "minor-stream"
      "major-activity"
      "minor-activity"
      "responses"
      "reply"
      "replies"
      "activity-object-list"
      "activity-object-collection"
    ]
    addMajorActivity: (act) ->
      view = this
      view.majorStreamView.showAdded act
      return

    addMinorActivity: (act) ->
      view = this
      aview = undefined
      view.minorStreamView.showAdded act
      return

    getStreams: ->
      view = this
      streams = {}
      streams.major = view.majorStreamView.model  if view.majorStreamView and view.majorStreamView.model
      streams.minor = view.minorStreamView.model  if view.minorStreamView and view.minorStreamView.model
      streams

    subs:
      "#major-stream":
        attr: "majorStreamView"
        subView: "MajorStreamView"
        subOptions:
          model: "major"
          data: ["headless"]

      "#minor-stream":
        attr: "minorStreamView"
        subView: "MinorStreamView"
        subOptions:
          model: "minor"
          data: ["headless"]
  )
  
  # Note: Not the same as the messages indicator on the navbar
  # This is the full-page view
  Pump.MessagesContent = Pump.ContentView.extend(
    templateName: "messages-content"
    parts: [
      "major-stream"
      "minor-stream"
      "major-activity"
      "minor-activity"
      "responses"
      "reply"
      "replies"
      "activity-object-list"
      "activity-object-collection"
    ]
    addMajorActivity: (act) ->
      view = this
      view.majorStreamView.showAdded act
      return

    addMinorActivity: (act) ->
      view = this
      aview = undefined
      view.minorStreamView.showAdded act
      return

    subs:
      "#major-stream":
        attr: "majorStreamView"
        subView: "MajorStreamView"
        subOptions:
          model: "major"
          data: ["headless"]

      "#minor-stream":
        attr: "minorStreamView"
        subView: "MinorStreamView"
        subOptions:
          model: "minor"
          data: ["headless"]
  )
  Pump.MajorActivityView = Pump.TemplateView.extend(
    templateName: "major-activity"
    parts: [
      "activity-object-list"
      "responses"
      "replies"
      "reply"
      "activity-object-collection"
    ]
    modelName: "activity"
    events:
      mouseenter: "maybeShowExtraMenu"
      mouseleave: "maybeHideExtraMenu"
      "click .favorite": "favoriteObject"
      "click .unfavorite": "unfavoriteObject"
      "click .share": "shareObject"
      "click .unshare": "unshareObject"
      "click .comment": "openComment"
      "click .object-image": "openImage"

    setupSubs: ->
      view = this
      model = view.model
      $el = view.$(".replies")
      if view.replyStream
        view.replyStream.setElement $el
        return
      view.replyStream = new Pump.ReplyStreamView(
        el: $el
        model: model.object.replies
      )
      return

    maybeShowExtraMenu: ->
      view = this
      activity = view.model
      principal = Pump.principal
      if principal and activity.actor and principal.id is activity.actor.id
        unless view.extraMenu
          view.extraMenu = new Pump.ExtraMenu(
            model: activity.object
            parent: view
          )
          view.extraMenu.show()
      return

    maybeHideExtraMenu: ->
      view = this
      activity = view.model
      principal = Pump.principal
      if principal and activity.actor and principal.id is activity.actor.id
        if view.extraMenu
          view.extraMenu.hide()
          view.extraMenu = null
      return

    favoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "favorite"
        object: view.model.object.toJSON()
      )
      Pump.newMinorActivity act, (err, act) ->
        view.$(".favorite").removeClass("favorite").addClass("unfavorite").html "Unlike <i class=\"icon-thumbs-down\"></i>"
        Pump.addMinorActivity act
        return

      return

    unfavoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unfavorite"
        object: view.model.object.toJSON()
      )
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".unfavorite").removeClass("unfavorite").addClass("favorite").html "Like <i class=\"icon-thumbs-up\"></i>"
          Pump.addMinorActivity act
        return

      return

    shareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "share"
        object: view.model.object.toJSON()
      )
      view.startSpin()
      Pump.newMajorActivity act, (err, act) ->
        if err
          view.stopSpin()
          view.showError err
        else
          view.$(".share").removeClass("share").addClass("unshare").html "Unshare <i class=\"icon-remove\"></i>"
          Pump.addMajorActivity act
        return

      return

    unshareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unshare"
        object: view.model.object.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.stopSpin()
          view.showError err
        else
          view.$(".unshare").removeClass("unshare").addClass("share").html "Share <i class=\"icon-share-alt\"></i>"
          Pump.addMinorActivity act
        return

      return

    openComment: ->
      view = this
      form = undefined
      if view.$("form.post-comment").length > 0
        view.$("form.post-comment textarea").focus()
      else
        form = new Pump.CommentForm(original: view.model.object)
        form.on "ready", ->
          view.$(".replies").append form.$el
          return

        form.render()
      return

    openImage: ->
      view = this
      model = view.model
      object = view.model.object
      modalView = undefined
      if object and object.get("fullImage")
        modalView = new Pump.LightboxModal(data:
          object: object
        )
        
        # When it's ready, show immediately
        modalView.on "ready", ->
          $(view.el).append modalView.el
          $(modalView.el).on "hidden", ->
            $(modalView.el).remove()
            return

          $("#fullImageLightbox").lightbox()
          return

        
        # render it (will fire "ready")
        modalView.render()
      return
  )
  Pump.ReplyStreamView = Pump.TemplateView.extend(
    templateName: "replies"
    parts: ["reply"]
    modelName: "replies"
    subs:
      ".reply":
        map: "activities"
        subView: "ReplyView"
        idAttr: "data-activity-id"

    events:
      "click .show-all-replies": "showAllReplies"

    showAllReplies: ->
      view = this
      replies = view.model
      full = new Pump.FullReplyStreamView(model: replies)
      Pump.body.startLoad()
      full.on "ready", ->
        full.$el.hide()
        view.$el.replaceWith full.$el
        full.$el.fadeIn "slow"
        Pump.body.endLoad()
        return

      replies.getAll (err, data) ->
        if err
          Pump.error err
        else
          full.render()
        return

      return

    placeSub: (aview, $el) ->
      view = this
      model = aview.model
      idx = view.model.items.indexOf(model)
      
      # Invert direction
      if idx <= 0
        view.$(".reply-objects").append aview.$el
      else if idx >= $el.length
        view.$(".reply-objects").prepend aview.$el
      else
        aview.$el.insertBefore $el[view.model.length - 1 - idx]
      return
  )
  Pump.FullReplyStreamView = Pump.TemplateView.extend(
    templateName: "full-replies"
    parts: ["reply"]
    modelName: "replies"
    subs:
      ".reply":
        map: "activities"
        subView: "ReplyView"
        idAttr: "data-activity-id"

    placeSub: (aview, $el) ->
      view = this
      model = aview.model
      idx = view.model.items.indexOf(model)
      
      # Invert direction
      if idx <= 0
        view.$(".reply-objects").append aview.$el
      else if idx >= $el.length
        view.$(".reply-objects").prepend aview.$el
      else
        aview.$el.insertBefore $el[view.model.length - 1 - idx]
      return
  )
  Pump.CommentForm = Pump.TemplateView.extend(
    templateName: "comment-form"
    tagName: "div"
    className: "row comment-form"
    events:
      "submit .post-comment": "saveComment"

    ready: ->
      view = this
      view.$("textarea[name=\"content\"]").wysihtml5 customTemplates: Pump.wysihtml5Tmpl
      return

    saveComment: ->
      view = this
      html = view.$("textarea[name=\"content\"]").val()
      orig = view.options.original
      act = new Pump.Activity(
        verb: "post"
        object:
          objectType: "comment"
          content: html
      )
      act.object.inReplyTo = orig
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.stopSpin()
          view.showError err
        else
          object = act.object
          repl = undefined
          
          # These get stripped for "posts"; re-add it
          object.author = Pump.principal
          repl = new Pump.ReplyView(model: object)
          repl.on "ready", ->
            view.stopSpin()
            view.$el.replaceWith repl.$el
            return

          repl.render()
          Pump.addMinorActivity act
        return

      false
  )
  Pump.MajorObjectView = Pump.TemplateView.extend(
    templateName: "major-object"
    parts: [
      "responses"
      "reply"
    ]
    events:
      "click .favorite": "favoriteObject"
      "click .unfavorite": "unfavoriteObject"
      "click .share": "shareObject"
      "click .unshare": "unshareObject"
      "click .comment": "openComment"

    setupSubs: ->
      view = this
      model = view.model
      $el = view.$(".replies")
      if view.replyStream
        view.replyStream.setElement $el
        return
      view.replyStream = new Pump.ReplyStreamView(
        el: $el
        model: model.replies
      )
      return

    favoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "favorite"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".favorite").removeClass("favorite").addClass("unfavorite").html "Unlike <i class=\"icon-thumbs-down\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    unfavoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unfavorite"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".unfavorite").removeClass("unfavorite").addClass("favorite").html "Like <i class=\"icon-thumbs-up\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    shareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "share"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMajorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".share").removeClass("share").addClass("unshare").html "Unshare <i class=\"icon-remove\"></i>"
          Pump.addMajorActivity act
        view.stopSpin()
        return

      return

    unshareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unshare"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".unshare").removeClass("unshare").addClass("share").html "Share <i class=\"icon-share-alt\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    openComment: ->
      view = this
      form = undefined
      if view.$("form.post-comment").length > 0
        view.$("form.post-comment textarea").focus()
      else
        form = new Pump.CommentForm(original: view.model)
        form.on "ready", ->
          view.$(".replies").append form.$el
          return

        form.render()
      return
  )
  Pump.ReplyView = Pump.TemplateView.extend(
    templateName: "reply"
    modelName: "reply"
    events:
      "click .favorite": "favoriteObject"
      "click .unfavorite": "unfavoriteObject"

    favoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "favorite"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".favorite").removeClass("favorite").addClass("unfavorite").html "Unlike <i class=\"icon-thumbs-down\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      false

    unfavoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unfavorite"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".unfavorite").removeClass("unfavorite").addClass("favorite").html "Like <i class=\"icon-thumbs-up\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      false
  )
  Pump.MinorActivityView = Pump.TemplateView.extend(
    templateName: "minor-activity"
    modelName: "activity"
  )
  Pump.PersonView = Pump.TemplateView.extend(
    events:
      "click .follow": "followProfile"
      "click .stop-following": "stopFollowingProfile"

    followProfile: ->
      view = this
      act =
        verb: "follow"
        object: view.model.toJSON()

      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".follow").removeClass("follow").removeClass("btn-primary").addClass("stop-following").html "Stop following"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    stopFollowingProfile: ->
      view = this
      act =
        verb: "stop-following"
        object: view.model.toJSON()

      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".stop-following").removeClass("stop-following").addClass("btn-primary").addClass("follow").html "Follow"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return
  )
  Pump.MajorPersonView = Pump.PersonView.extend(
    templateName: "major-person"
    modelName: "person"
  )
  Pump.ProfileBlock = Pump.PersonView.extend(
    templateName: "profile-block"
    modelName: "profile"
    parts: ["profile-responses"]
    initialize: (options) ->
      Pump.debug "Initializing profile-block #" + @cid
      Pump.PersonView::initialize.apply this
      return
  )
  Pump.FavoritesContent = Pump.ContentView.extend(
    templateName: "favorites"
    parts: [
      "profile-block"
      "profile-nav"
      "user-content-favorites"
      "object-stream"
      "major-object"
      "responses"
      "reply"
      "profile-responses"
      "activity-object-list"
      "activity-object-collection"
    ]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-favorites":
        attr: "userContent"
        subView: "FavoritesUserContent"
        subOptions:
          model: "favorites"
          data: ["profile"]
  )
  Pump.FavoritesUserContent = Pump.TemplateView.extend(
    templateName: "user-content-favorites"
    modelName: "favorites"
    parts: [
      "object-stream"
      "major-object"
      "responses"
      "reply"
      "profile-responses"
      "activity-object-collection"
    ]
    subs:
      ".object.major":
        map: "favorites"
        subView: "MajorObjectView"
        idAttr: "data-object-id"
  )
  Pump.FollowersContent = Pump.ContentView.extend(
    templateName: "followers"
    parts: [
      "profile-block"
      "profile-nav"
      "user-content-followers"
      "people-stream"
      "major-person"
      "profile-responses"
    ]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-followers":
        attr: "userContent"
        subView: "FollowersUserContent"
        subOptions:
          data: [
            "profile"
            "followers"
          ]

    getStreams: ->
      view = this
      streams = {}
      streams.major = view.userContent.peopleStreamView.model  if view.userContent and view.userContent.peopleStreamView and view.userContent.peopleStreamView.model
      streams
  )
  Pump.FollowersUserContent = Pump.TemplateView.extend(
    templateName: "user-content-followers"
    modelName: "followers"
    parts: [
      "people-stream"
      "major-person"
      "profile-responses"
    ]
    subs:
      "#people-stream":
        attr: "peopleStreamView"
        subView: "PeopleStreamView"
        subOptions:
          model: "followers"
  )
  Pump.PeopleStreamView = Pump.TemplateView.extend(
    templateName: "people-stream"
    modelName: "people"
    subs:
      ".person.major":
        map: "people"
        subView: "MajorPersonView"
        idAttr: "data-person-id"
  )
  Pump.FollowingContent = Pump.ContentView.extend(
    templateName: "following"
    parts: [
      "profile-block"
      "profile-nav"
      "user-content-following"
      "people-stream"
      "major-person"
      "profile-responses"
    ]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-following":
        attr: "userContent"
        subView: "FollowingUserContent"
        subOptions:
          data: [
            "profile"
            "following"
          ]

    getStreams: ->
      view = this
      streams = {}
      streams.major = view.userContent.peopleStreamView.model  if view.userContent and view.userContent.peopleStreamView and view.userContent.peopleStreamView.model
      streams
  )
  Pump.FollowingUserContent = Pump.TemplateView.extend(
    templateName: "user-content-following"
    modelName: "following"
    parts: [
      "people-stream"
      "major-person"
      "profile-responses"
    ]
    subs:
      "#people-stream":
        attr: "peopleStreamView"
        subView: "PeopleStreamView"
        subOptions:
          model: "following"
  )
  Pump.ListsContent = Pump.ContentView.extend(
    templateName: "lists"
    parts: [
      "profile-block"
      "profile-nav"
      "user-content-lists"
      "list-content-lists"
      "list-menu"
      "list-menu-item"
      "profile-responses"
    ]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-lists":
        attr: "userContent"
        subView: "ListsUserContent"
        subOptions:
          data: [
            "profile"
            "lists"
          ]
  )
  Pump.ListsUserContent = Pump.TemplateView.extend(
    templateName: "user-content-lists"
    parts: [
      "list-menu"
      "list-menu-item"
      "list-content-lists"
    ]
    subs:
      "#list-menu-inner":
        attr: "listMenu"
        subView: "ListMenu"
        subOptions:
          model: "lists"
          data: [
            "profile"
            "list"
          ]
  )
  Pump.ListMenu = Pump.TemplateView.extend(
    templateName: "list-menu"
    modelName: "lists"
    parts: ["list-menu-item"]
    el: ".list-menu-block"
    events:
      "click .new-list": "newList"

    newList: ->
      Pump.showModal Pump.NewListModal,
        data:
          user: Pump.principalUser

      return

    subs:
      ".list":
        map: "lists"
        subView: "ListMenuItem"
        idAttr: "data-list-id"
  )
  Pump.ListMenuItem = Pump.TemplateView.extend(
    templateName: "list-menu-item"
    modelName: "listItem"
    tagName: "ul"
    className: "list-menu-wrapper"
  )
  Pump.ListsListContent = Pump.TemplateView.extend(templateName: "list-content-lists")
  Pump.ListContent = Pump.ContentView.extend(
    templateName: "list"
    parts: [
      "profile-block"
      "profile-nav"
      "profile-responses"
      "user-content-list"
      "list-content-list"
      "people-stream"
      "major-person"
      "list-menu"
      "list-menu-item"
    ]
    subs:
      "#profile-block":
        attr: "profileBlock"
        subView: "ProfileBlock"
        subOptions:
          model: "profile"

      "#user-content-list":
        attr: "userContent"
        subView: "ListUserContent"
        subOptions:
          data: [
            "profile"
            "lists"
            "list"
            "members"
          ]

    getStreams: ->
      view = this
      streams = {}
      streams.major = view.userContent.listContent.memberStreamView.model  if view.userContent and view.userContent.listContent and view.userContent.listContent.memberStreamView
      streams
  )
  Pump.ListUserContent = Pump.TemplateView.extend(
    templateName: "user-content-list"
    parts: [
      "people-stream"
      "list-content-list"
      "major-person"
      "list-menu-item"
      "list-menu"
    ]
    subs:
      "#list-menu-inner":
        attr: "listMenu"
        subView: "ListMenu"
        subOptions:
          model: "lists"
          data: ["profile"]

      "#list-content-list":
        attr: "listContent"
        subView: "ListListContent"
        subOptions:
          model: "list"
          data: [
            "profile"
            "members"
            "lists"
            "list"
          ]
  )
  Pump.ListListContent = Pump.TemplateView.extend(
    templateName: "list-content-list"
    modelName: "list"
    parts: [
      "member-stream"
      "member"
    ]
    subs:
      "#member-stream":
        attr: "memberStreamView"
        subView: "MemberStreamView"
        subOptions:
          model: "members"
          data: [
            "profile"
            "lists"
            "list"
          ]

    events:
      "click #add-list-member": "addListMember"
      "click #delete-list": "deleteList"

    addListMember: ->
      view = this
      profile = Pump.principal
      list = view.model
      members = view.options.data.members
      following = profile.following
      following.getAll ->
        Pump.fetchObjects [
          profile
          list
        ], (err, objs) ->
          Pump.showModal Pump.ChooseContactModal,
            data:
              list: list
              members: members
              people: following

          return

        return

      false

    deleteList: ->
      view = this
      list = view.model
      lists = view.options.data.lists
      user = Pump.principalUser
      person = Pump.principal
      Pump.areYouSure "Delete the list '" + list.get("displayName") + "'?", (err, sure) ->
        if err
          view.showError err
        else if sure
          Pump.router.navigate "/" + user.get("nickname") + "/lists", true
          list.destroy success: ->
            lists.remove list.id
            
            # Reload the menu
            Pump.body.content.userContent.listMenu.render()
            return

        return

      return
  )
  Pump.MemberStreamView = Pump.TemplateView.extend(
    templateName: "member-stream"
    modelName: "people"
    subs:
      ".person.major":
        map: "people"
        subView: "MemberView"
        idAttr: "data-person-id"
        subOptions:
          data: ["list"]
  )
  Pump.MemberView = Pump.TemplateView.extend(
    templateName: "member"
    modelName: "person"
    ready: ->
      view = this
      
      # XXX: Bootstrap dependency
      view.$("#remove-person").tooltip()
      return

    events:
      "click #remove-person": "removePerson"

    removePerson: ->
      view = this
      person = view.model
      list = view.options.data.list
      members = view.options.data.people
      user = Pump.principalUser
      act =
        verb: "remove"
        object:
          objectType: "person"
          id: person.id

        target:
          objectType: "collection"
          id: list.id

      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          members.remove person.id
          list.totalItems--
          list.trigger "change"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return
  )
  Pump.SettingsContent = Pump.ContentView.extend(
    templateName: "settings"
    modelName: "profile"
    events:
      "submit #settings": "saveSettings"

    fileCount: 0
    ready: ->
      view = this
      view.setupSubs()
      if view.$("#avatar-fineupload").length > 0
        view.$("#avatar-fineupload").fineUploader(
          request:
            endpoint: "/main/upload-avatar"

          text:
            uploadButton: "<i class=\"icon-upload icon-white\"></i> Avatar file"

          template: "<div class=\"qq-uploader\">" + "<pre class=\"qq-upload-drop-area\"><span>{dragZoneText}</span></pre>" + "<div class=\"qq-drop-processing\"></div>" + "<div class=\"qq-upload-button btn btn-success\">{uploadButtonText}</div>" + "<ul class=\"qq-upload-list\"></ul>" + "</div>"
          classes:
            success: "alert alert-success"
            fail: "alert alert-error"

          autoUpload: false
          multiple: false
          validation:
            allowedExtensions: [
              "jpeg"
              "jpg"
              "png"
              "gif"
              "svg"
              "svgz"
            ]
            acceptFiles: "image/*"
        ).on("submit", (id, fileName) ->
          view.fileCount++
          true
        ).on("cancel", (id, fileName) ->
          view.fileCount--
          true
        ).on("complete", (event, id, fileName, responseJSON) ->
          act = new Pump.Activity(
            verb: "post"
            cc: [
              id: "http://activityschema.org/collection/public"
              objectType: "collection"
            ]
            object: responseJSON.obj
          )
          Pump.newMajorActivity act, (err, act) ->
            if err
              view.showError err
              view.stopSpin()
            else
              view.saveProfile act.object
            return

          return
        ).on "error", (event, id, fileName, reason) ->
          view.showError reason
          view.stopSpin()
          return

      return

    saveProfile: (img) ->
      view = this
      profile = Pump.principal
      props =
        displayName: view.$("#realname").val()
        location:
          objectType: "place"
          displayName: view.$("#location").val()

        summary: view.$("#bio").val()

      if img
        props.image = img.get("image")
        props.pump_io = fullImage: img.get("fullImage")
      profile.save props,
        success: (resp, status, xhr) ->
          view.showSuccess "Saved settings."
          view.stopSpin()
          return

        error: (model, error, options) ->
          view.showError error.message
          view.stopSpin()
          return

      return

    saveSettings: ->
      view = this
      user = Pump.principalUser
      profile = user.profile
      haveNewAvatar = (view.fileCount > 0)
      view.startSpin()
      
      # XXX: Validation?
      if haveNewAvatar
        
        # This will save the profile afterwards
        view.$("#avatar-fineupload").fineUploader "uploadStoredFiles"
      else
        
        # No new image
        view.saveProfile null
      false
  )
  Pump.AccountContent = Pump.ContentView.extend(
    templateName: "account"
    modelName: "user"
    events:
      "submit #account": "saveAccount"

    saveAccount: ->
      view = this
      user = Pump.principalUser
      password = view.$("#password").val()
      repeat = view.$("#repeat").val()
      if password isnt repeat
        view.showError "Passwords don't match."
      else if password.length < 8
        view.showError "Password must be 8 chars or more."
      else if /^[a-z]+$/.test(password.toLowerCase()) or /^[0-9]+$/.test(password)
        view.showError "Passwords have to have at least one letter and one number."
      else
        view.startSpin()
        user.save "password", password,
          success: (resp, status, xhr) ->
            view.showSuccess "Saved."
            view.stopSpin()
            return

          error: (model, error, options) ->
            view.showError error.message
            view.stopSpin()
            return

      false
  )
  Pump.ObjectContent = Pump.ContentView.extend(
    templateName: "object"
    modelName: "object"
    parts: [
      "responses"
      "reply"
      "replies"
      "activity-object-collection"
    ]
    events:
      "click .favorite": "favoriteObject"
      "click .unfavorite": "unfavoriteObject"
      "click .share": "shareObject"
      "click .unshare": "unshareObject"
      "click .comment": "openComment"

    setupSubs: ->
      view = this
      model = view.model
      $el = view.$(".replies")
      if view.replyStream
        view.replyStream.setElement $el
        return
      view.replyStream = new Pump.ReplyStreamView(
        el: $el
        model: model.replies
      )
      return

    favoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "favorite"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".favorite").removeClass("favorite").addClass("unfavorite").html "Unlike <i class=\"icon-thumbs-down\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    unfavoriteObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unfavorite"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".unfavorite").removeClass("unfavorite").addClass("favorite").html "Like <i class=\"icon-thumbs-up\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    shareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "share"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMajorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".share").removeClass("share").addClass("unshare").html "Unshare <i class=\"icon-remove\"></i>"
          Pump.addMajorActivity act
        view.stopSpin()
        return

      return

    unshareObject: ->
      view = this
      act = new Pump.Activity(
        verb: "unshare"
        object: view.model.toJSON()
      )
      view.startSpin()
      Pump.newMinorActivity act, (err, act) ->
        if err
          view.showError err
        else
          view.$(".unshare").removeClass("unshare").addClass("share").html "Share <i class=\"icon-share-alt\"></i>"
          Pump.addMinorActivity act
        view.stopSpin()
        return

      return

    openComment: ->
      view = this
      form = undefined
      if view.$("form.post-comment").length > 0
        view.$("form.post-comment textarea").focus()
      else
        form = new Pump.CommentForm(original: view.model)
        form.on "ready", ->
          view.$(".replies").append form.$el
          return

        form.render()
      return
  )
  Pump.ChooseContactModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "choose-contact"
    ready: ->
      view = this
      view.$(".thumbnail").tooltip()
      view.$("#add-contact").prop "disabled", true
      view.$("#add-contact").attr "disabled", "disabled"
      return

    events:
      "click .thumbnail": "toggleSelection"
      "click #add-contact": "addContact"

    toggled: 0
    toggleSelection: (ev) ->
      view = this
      el = ev.currentTarget
      $el = $(el)
      
      # XXX: Bootstrap-dependency
      if $el.hasClass("alert")
        $el.removeClass("alert").removeClass "alert-info"
        view.toggled--
      else
        $el.addClass("alert").addClass "alert-info"
        view.toggled++
      if view.toggled is 0
        view.$("#add-contact").prop "disabled", true
        view.$("#add-contact").attr "disabled", "disabled"
      else
        view.$("#add-contact").prop "disabled", false
        view.$("#add-contact").removeAttr "disabled"
      return

    addContact: ->
      view = this
      list = view.options.data.list
      members = view.options.data.members
      people = view.options.data.people
      ids = []
      done = undefined
      
      # Extract the IDs from the data- attributes of toggled thumbnails
      view.$(".thumbnail.alert-info").each (i, el) ->
        personID = $(el).attr("data-person-id")
        ids.push personID
        return

      done = 0
      
      # Hide the modal
      view.$el.modal "hide"
      view.remove()
      
      # Add each person
      _.each ids, (id) ->
        
        # We could do this by posting to the minor stream,
        # but this way we automatically update the list view,
        # and the minor stream view gets updated by socksjs, which this
        # does not (yet)
        person = people.get(id)
        act =
          verb: "add"
          object:
            objectType: "person"
            id: id

          target:
            objectType: "collection"
            id: list.id

        Pump.newMinorActivity act, (err, act) ->
          if err
            view.showError err
          else
            members.items.add person,
              at: 0

            list.totalItems++
            list.trigger "change"
            Pump.addMinorActivity act
          return

        return

      return
  )
  Pump.PostNoteModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "post-note"
    parts: ["recipient-selector"]
    ready: ->
      view = this
      view.$("#note-content").wysihtml5 customTemplates: Pump.wysihtml5Tmpl
      view.$("#note-to").select2 Pump.selectOpts()
      view.$("#note-cc").select2 Pump.selectOpts()
      return

    events:
      "click #send-note": "postNote"

    postNote: (ev) ->
      view = this
      text = view.$("#post-note #note-content").val()
      to = view.$("#post-note #note-to").val()
      cc = view.$("#post-note #note-cc").val()
      act = new Pump.Activity(
        verb: "post"
        object:
          objectType: "note"
          content: text
      )
      strToObj = (str) ->
        colon = str.indexOf(":")
        type = str.substr(0, colon)
        id = str.substr(colon + 1)
        new Pump.ActivityObject(
          id: id
          objectType: type
        )

      to = to.split(",")  if _.isString(to)
      cc = cc.split(",")  if _.isString(cc)
      act.to = new Pump.ActivityObjectBag(_.map(to, strToObj))  if to and to.length > 0
      act.cc = new Pump.ActivityObjectBag(_.map(cc, strToObj))  if cc and cc.length > 0
      view.startSpin()
      Pump.newMajorActivity act, (err, act) ->
        if err
          view.showError err
          view.stopSpin()
        else
          view.stopSpin()
          view.$el.modal "hide"
          Pump.resetWysihtml5 view.$("#note-content")
          
          # Reload the current page
          Pump.addMajorActivity act
          view.remove()
        return

      return
  )
  Pump.PostPictureModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "post-picture"
    parts: ["recipient-selector"]
    events:
      "click #send-picture": "postPicture"

    ready: ->
      view = this
      view.$("#picture-to").select2 Pump.selectOpts()
      view.$("#picture-cc").select2 Pump.selectOpts()
      view.$("#picture-description").wysihtml5 customTemplates: Pump.wysihtml5Tmpl
      if view.$("#picture-fineupload").length > 0
        
        # Reload the current content
        view.$("#picture-fineupload").fineUploader(
          request:
            endpoint: "/main/upload"

          text:
            uploadButton: "<i class=\"icon-upload icon-white\"></i> Picture file"

          template: "<div class=\"qq-uploader\">" + "<pre class=\"qq-upload-drop-area\"><span>{dragZoneText}</span></pre>" + "<div class=\"qq-drop-processing\"></div>" + "<div class=\"qq-upload-button btn btn-success\">{uploadButtonText}</div>" + "<ul class=\"qq-upload-list\"></ul>" + "</div>"
          classes:
            success: "alert alert-success"
            fail: "alert alert-error"

          autoUpload: false
          multiple: false
          validation:
            allowedExtensions: [
              "jpeg"
              "jpg"
              "png"
              "gif"
              "svg"
              "svgz"
            ]
            acceptFiles: "image/*"
        ).on("complete", (event, id, fileName, responseJSON) ->
          stream = Pump.principalUser.majorStream
          to = view.$("#post-picture #picture-to").val()
          cc = view.$("#post-picture #picture-cc").val()
          strToObj = (str) ->
            colon = str.indexOf(":")
            type = str.substr(0, colon)
            id = str.substr(colon + 1)
            Pump.ActivityObject.unique
              id: id
              objectType: type


          act = new Pump.Activity(
            verb: "post"
            object: responseJSON.obj
          )
          to = to.split(",")  if _.isString(to)
          cc = cc.split(",")  if _.isString(cc)
          act.to = new Pump.ActivityObjectBag(_.map(to, strToObj))  if to and to.length > 0
          act.cc = new Pump.ActivityObjectBag(_.map(cc, strToObj))  if cc and cc.length > 0
          Pump.newMajorActivity act, (err, act) ->
            if err
              view.showError err
              view.stopSpin()
            else
              view.$el.modal "hide"
              view.stopSpin()
              view.$("#picture-fineupload").fineUploader "reset"
              Pump.resetWysihtml5 view.$("#picture-description")
              view.$("#picture-title").val ""
              Pump.addMajorActivity act
              view.remove()
            return

          return
        ).on "error", (event, id, fileName, reason) ->
          view.showError reason
          return

      return

    postPicture: (ev) ->
      view = this
      description = view.$("#post-picture #picture-description").val()
      title = view.$("#post-picture #picture-title").val()
      params = {}
      params.title = title  if title
      
      # XXX: HTML
      params.description = description  if description
      view.$("#picture-fineupload").fineUploader "setParams", params
      view.startSpin()
      view.$("#picture-fineupload").fineUploader "uploadStoredFiles"
      return
  )
  Pump.NewListModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "new-list"
    ready: ->
      view = this
      view.$("#list-description").wysihtml5 customTemplates: Pump.wysihtml5Tmpl
      return

    events:
      "click #save-new-list": "saveNewList"

    saveNewList: ->
      view = this
      description = view.$("#new-list #list-description").val()
      name = view.$("#new-list #list-name").val()
      act = undefined
      unless name
        view.showError "Your list must have a name."
      else
        
        # XXX: any other validation? Check uniqueness here?
        
        # XXX: to/cc ?
        act = new Pump.Activity(
          verb: "create"
          object: new Pump.ActivityObject(
            objectType: "collection"
            objectTypes: ["person"]
            displayName: name
            content: description
          )
        )
        view.startSpin()
        Pump.newMinorActivity act, (err, act) ->
          aview = undefined
          if err
            view.stopSpin()
            view.showError err
          else
            view.$el.modal "hide"
            view.stopSpin()
            Pump.resetWysihtml5 view.$("#list-description")
            view.$("#list-name").val ""
            view.remove()
            
            # it's minor
            Pump.addMinorActivity act
            if $("#list-menu-inner").length > 0
              aview = new Pump.ListMenuItem(
                model: act.object
                data:
                  list: act.object
              )
              aview.on "ready", ->
                rel = undefined
                aview.$el.hide()
                $("#list-menu-inner").prepend aview.$el
                aview.$el.slideDown "fast"
                
                # Go to the new list page
                rel = Pump.rel(act.object.get("url"))
                Pump.router.navigate rel, true
                return

              aview.render()
          return

      false
  )
  Pump.AreYouSureModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "are-you-sure"
    events:
      "click #yes": "yes"
      "click #no": "no"

    yes: ->
      view = this
      callback = view.options.callback
      view.$el.modal "hide"
      view.remove()
      callback null, true
      return

    no: ->
      view = this
      callback = view.options.callback
      view.$el.modal "hide"
      view.remove()
      callback null, false
      return
  )
  Pump.LightboxModal = Pump.TemplateView.extend(
    tagName: "div"
    className: "modal-holder"
    templateName: "lightbox-modal"
  )
  Pump.BodyView = Backbone.View.extend(
    initialize: (options) ->
      _.bindAll this, "navigateToHref"
      return

    el: "body"
    events:
      "click a": "navigateToHref"

    navigateToHref: (ev) ->
      el = (ev.srcElement or ev.currentTarget)
      here = window.location
      
      # This gets fired for children of <a> elements, too. So we navigate
      # up the DOM tree till we find an element that has a pathname (or
      # we run out of tree)
      el = (ev.srcElement or ev.currentTarget)
      while el
        break  if el.pathname
        el = el.parentNode
      
      # Check for a good value
      if not el or not el.pathname
        Pump.debug "Silently not navigating to non-existent target."
        return false
      
      # Bootstrap components; let these through
      return true  if $(el).hasClass("dropdown-toggle") or $(el).attr("data-toggle") is "collapse"
      
      # Save a spot in case we come back
      if $(el).hasClass("save-continue-to")
        Pump.saveContinueTo()
      else Pump.continueTo = Pump.getContinueTo()  if $(el).hasClass("add-continue")
      
      # For local <a>, use the router
      if not el.host or el.host is here.host
        try
          Pump.debug "Navigating to " + el.pathname
          Pump.router.navigate el.pathname, true
        catch e
          Pump.error e
        
        # Always return false
        false
      else
        Pump.debug "Default anchor handling"
        true

    setContent: (options, callback) ->
      View = options.contentView
      title = options.title
      body = this
      oldContent = body.content
      userContentOptions = undefined
      listContentOptions = undefined
      newView = undefined
      parent = undefined
      profile = undefined
      if options.model
        profile = options.model
      else profile = options.data.profile  if options.data
      Pump.unfollowStreams()
      
      # XXX: double-check this
      Pump.debug "Initializing new " + View::templateName
      body.content = new View(options)
      Pump.debug "Done initializing new " + View::templateName
      
      # We try and only update the parts that have changed
      if oldContent and options.userContentView and oldContent.profileBlock and oldContent.profileBlock.model.get("id") is profile.get("id")
        if body.content.profileBlock
          Pump.debug "Removing profile block #" + body.content.profileBlock.cid + " from " + View::templateName
          body.content.profileBlock.remove()
        Pump.debug "Connecting profile block #" + oldContent.profileBlock.cid + " to " + View::templateName
        body.content.profileBlock = oldContent.profileBlock
        if options.userContentStream
          userContentOptions = _.extend(
            model: options.userContentStream
          , options)
        else
          userContentOptions = options
        body.content.userContent = new options.userContentView(userContentOptions)
        if options.listContentView and oldContent.userContent.listMenu
          if body.content.userContent.listMenu
            Pump.debug "Removing list menu #" + body.content.userContent.listMenu.cid + " from " + View::templateName
            body.content.userContent.listMenu.remove()
          Pump.debug "Connecting list menu #" + oldContent.userContent.listMenu.cid + " to " + View::templateName
          body.content.userContent.listMenu = oldContent.userContent.listMenu
          if options.listContentModel
            listContentOptions = _.extend(
              model: options.listContentModel
            , options)
          else
            listContentOptions = options
          body.content.userContent.listContent = new options.listContentView(listContentOptions)
          parent = "#list-content"
          newView = body.content.userContent.listContent
        else
          parent = "#user-content"
          newView = body.content.userContent
          if oldContent.userContent.listMenu
            Pump.debug "Removing list menu #" + oldContent.userContent.listMenu.cid
            oldContent.userContent.listMenu.remove()
      else
        parent = "#content"
        newView = body.content
        if oldContent and oldContent.profileBlock
          Pump.debug "Removing profile block #" + oldContent.profileBlock.cid
          oldContent.profileBlock.remove()
        if oldContent and oldContent.userContent and oldContent.userContent.listMenu
          Pump.debug "Removing list menu #" + oldContent.userContent.listMenu.cid
          oldContent.userContent.listMenu.remove()
      newView.once "ready", ->
        Pump.setTitle title
        body.$(parent).children().replaceWith newView.$el
        Pump.followStreams()
        window.scrollTo 0, 0
        callback()  if callback
        return

      
      # Stop spinning
      newView.render()
      return

    startLoad: ->
      view = this
      view.$("a.brand").spin color: "white"
      return

    endLoad: ->
      view = this
      view.$("a.brand").spin false
      return
  )
  Pump.showModal = (Cls, options) ->
    modalView = undefined
    
    # If we've got it attached already, just show it
    modalView = new Cls(options)
    
    # When it's ready, show immediately
    modalView.on "ready", ->
      $("body").append modalView.el
      modalView.$el.modal "show"
      options.ready()  if options.ready
      return

    
    # render it (will fire "ready")
    modalView.render()
    return

  Pump.resetWysihtml5 = (el) ->
    fancy = el.data("wysihtml5")
    fancy.editor.clear()  if fancy and fancy.editor and fancy.editor.clear
    $(".wysihtml5-command-active", fancy.toolbar).removeClass "wysihtml5-command-active"
    el

  Pump.addMajorActivity = (act) ->
    Pump.body.content.addMajorActivity act  if Pump.body.content
    return

  Pump.addMinorActivity = (act) ->
    Pump.body.content.addMinorActivity act  if Pump.body.content
    return

  Pump.areYouSure = (question, callback) ->
    Pump.showModal Pump.AreYouSureModal,
      data:
        question: question

      callback: callback

    return

  Pump.selectOpts = ->
    user = Pump.principalUser
    lists = Pump.principal.lists
    followersUrl = Pump.principal.followers.url()
    lastSearch = null
    width: "90%"
    multiple: true
    placeholder: "Search for a user or list"
    minimumInputLength: 2
    initSelection: (element, callback) ->
      val = element.val()
      strToObj = (str) ->
        colon = str.indexOf(":")
        type = str.substr(0, colon)
        id = str.substr(colon + 1)
        new Pump.ActivityObject(
          id: id
          objectType: type
        )

      selection = []
      obj = (if (val and val.length > 0) then strToObj(val) else null)
      if obj
        if obj.id is "http://activityschema.org/collection/public"
          selection.push
            id: "collection:http://activityschema.org/collection/public"
            text: "Public"

        else if obj.id is followersUrl
          selection.push
            id: "collection:" + followersUrl
            text: "Followers"

        else
      
      # XXX: Get the object remotely
      callback selection
      return

    query: (options) ->
      term = options.term.toLowerCase()
      lmatch = lists.items.filter((item) ->
        item.get("displayName").toLowerCase().indexOf(term) isnt -1
      )
      
      # Abort if something's already running
      if lastSearch
        lastSearch.abort()
        lastSearch = null
      Pump.ajax
        type: "GET"
        dataType: "json"
        url: Pump.fullURL("/api/user/" + user.get("nickname") + "/following?q=" + term)
        success: (data) ->
          people = _.map(data.items, (item) ->
            id: item.objectType + ":" + item.id
            text: item.displayName
          )
          results = []
          lastSearch = null
          unless "Public".toLowerCase().indexOf(term) is -1
            results.push
              id: "collection:http://activityschema.org/collection/public"
              text: "Public"

          unless "Followers".toLowerCase().indexOf(term) is -1
            results.push
              id: "collection:" + followersUrl
              text: "Followers"

          if people.length > 0
            results.push
              text: "People"
              children: people

          if lmatch.length > 0
            results.push
              text: "Lists"
              children: _.map(lmatch, (list) ->
                id: list.get("objectType") + ":" + list.id
                text: list.get("displayName")
              )

          options.callback results: results
          return

        error: (jqxhr) ->
          lastSearch = null
          options.callback []
          return

        started: (jqxhr) ->
          lastSearch = jqxhr
          return

      return

  Pump.ExtraMenu = Pump.TemplateView.extend(
    parent: null
    templateName: "extra-menu"
    events:
      "click .delete-object": "deleteObject"

    initialize: (options) ->
      view = this
      view.parent = options.parent  if options.parent
      return

    show: ->
      view = this
      view.render()
      return

    ready: ->
      view = this
      view.parent.$el.prepend view.$el  if view.parent and view.parent.$el
      return

    hide: ->
      view = this
      view.$el.remove()
      return

    deleteObject: ->
      view = this
      model = view.model
      act = new Pump.Activity(
        verb: "delete"
        object: view.model.toJSON()
      )
      prompt = "Delete this " + model.get("objectType") + "?"
      
      # Hide the dropdown, since we were selected
      view.$el.dropdown "toggle"
      Pump.areYouSure prompt, (err, sure) ->
        if sure
          Pump.newMinorActivity act, (err, act) ->
            if err
              view.showError err
            else
              Pump.addMinorActivity act
              
              # Remove the parent from the list
              view.parent.$el.remove()
              
              # Remove the model from the client-side collection
              model.collection.remove model.id
            return

        return

      return
  )
  return
) window._, window.$, window.Backbone, window.Pump
