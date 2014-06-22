# app.js
#
# main function for activity pump application
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
urlparse = require("url").parse
auth = require("connect-auth")
Step = require("step")
databank = require("databank")
express = require("express")
_ = require("underscore")
fs = require("fs")
path = require("path")
Logger = require("bunyan")
uuid = require("node-uuid")
validator = require("validator")
DialbackClient = require("dialback-client")
api = require("./routes/api")
web = require("./routes/web")
shared = require("./routes/shared")
webfinger = require("./routes/webfinger")
clientreg = require("./routes/clientreg")
oauth = require("./routes/oauth")
confirm = require("./routes/confirm")
uploads = require("./routes/uploads")
schema = require("./schema").schema
HTTPError = require("./httperror").HTTPError
Provider = require("./provider").Provider
URLMaker = require("./urlmaker").URLMaker
rawBody = require("./rawbody").rawBody
defaults = require("./defaults")
Distributor = require("./distributor")
pumpsocket = require("./pumpsocket")
Firehose = require("./firehose")
Mailer = require("./mailer")
version = require("./version").version
Upgrader = require("./upgrader")
Credentials = require("./model/credentials").Credentials
Nonce = require("./model/nonce").Nonce
Image = require("./model/image").Image
Proxy = require("./model/proxy").Proxy
ActivitySpam = require("./activityspam")
sanitize = validator.sanitize
Databank = databank.Databank
DatabankObject = databank.DatabankObject
DatabankStore = require("connect-databank")(express)
makeApp = (configBase, callback) ->
  params = undefined
  port = undefined
  hostname = undefined
  address = undefined
  log = undefined
  db = undefined
  logParams =
    name: "pump.io"
    serializers:
      req: Logger.stdSerializers.req
      res: Logger.stdSerializers.res
      err: (err) ->
        obj = Logger.stdSerializers.err(err)
        
        # only show properties without an initial underscore
        _.pick obj, _.filter(_.keys(obj), (key) ->
          key[0] isnt "_"
        )

      principal: (principal) ->
        if principal
          id: principal.id
          type: principal.objectType
        else
          id: "<none>"

      client: (client) ->
        if client
          key: client.consumer_key
          title: client.title or "<none>"
        else
          key: "<none>"
          title: "<none>"

  plugins = {}
  config = undefined
  
  # Copy the base config and insert defaults
  config = _.clone(configBase)
  config = _.defaults(config, defaults)
  port = config.port
  hostname = config.hostname
  address = config.address or config.hostname
  if process.getuid
    if port < 1024 and process.getuid() isnt 0
      callback new Error("Can't listen to ports lower than 1024 on POSIX systems unless you're root."), null
      return
  if config.logfile
    logParams.streams = [path: config.logfile]
  else if config.nologger
    logParams.streams = [path: "/dev/null"]
  else
    logParams.streams = [stream: process.stderr]
  logParams.streams[0].level = config.logLevel
  log = new Logger(logParams)
  log.debug "Initializing pump.io"
  
  # Initialize plugins
  _.each config.plugins, (pluginName) ->
    log.debug
      plugin: pluginName
    , "Initializing plugin."
    plugins[pluginName] = require(pluginName)
    plugins[pluginName].initializeLog log  if _.isFunction(plugins[pluginName].initializeLog)
    return

  
  # Initiate the DB
  if config.params
    params = config.params
  else
    params = {}
  if _(params).has("schema")
    _.extend params.schema, schema
  else
    params.schema = schema
  
  # So they can add their own types to the schema
  _.each plugins, (plugin, name) ->
    if _.isFunction(plugin.initializeSchema)
      log.debug
        plugin: name
      , "Initializing schema."
      plugin.initializeSchema params.schema
    return

  db = Databank.get(config.driver, params)
  
  # Connect...
  log.debug "Connecting to databank with driver '" + config.driver + "'"
  db.connect {}, (err) ->
    useHTTPS = config.key
    useBounce = config.bounce
    app = undefined
    io = undefined
    bounce = undefined
    dialbackClient = undefined
    requestLogger = (log) ->
      (req, res, next) ->
        weblog = log.child(
          req_id: uuid.v4()
          component: "web"
        )
        end = res.end
        startTime = Date.now()
        req.log = weblog
        res.end = (chunk, encoding) ->
          rec = undefined
          endTime = undefined
          res.end = end
          res.end chunk, encoding
          endTime = Date.now()
          rec =
            req: req
            res: res
            serverTime: endTime - startTime

          rec.principal = req.principal  if _(req).has("principal")
          rec.client = req.client  if _(req).has("client")
          weblog.info rec
          return

        next()
        return

    if err
      log.error err
      callback err, null
      return
    if useHTTPS
      log.debug "Setting up HTTPS server."
      app = express.createServer(
        key: fs.readFileSync(config.key)
        cert: fs.readFileSync(config.cert)
      )
      if useBounce
        log.debug "Setting up micro-HTTP server to bounce to HTTPS."
        bounce = express.createServer((req, res, next) ->
          host = req.header("Host")
          res.redirect "https://" + host + req.url, 301
          return
        )
    else
      log.debug "Setting up HTTP server."
      app = express.createServer()
    app.config = config
    if config.smtpserver
      
      # harmless flag
      config.haveEmail = true
      Mailer.setup config, log
    workers = config.workers or 1
    
    # Each worker takes a turn cleaning up, so *this* worker does
    # its cleanup once every config.workers cleanup periods
    dbstore = new DatabankStore(db, log, (if (config.cleanupSession) then (config.cleanupSession * workers) else 0))
    unless config.noweb
      app.session = express.session(
        secret: config.secret or "insecure"
        store: dbstore
      )
    
    # Configuration
    app.configure ->
      serverVersion = "pump.io/" + version + " express/" + express.version + " node.js/" + process.version
      versionStamp = (req, res, next) ->
        res.setHeader "Server", serverVersion
        next()
        return

      canonicalHost = (req, res, next) ->
        host = req.header("Host")
        urlHost = undefined
        addressHost = undefined
        if not config.redirectToCanonical or not host
          next()
          return
        urlHost = URLMaker.makeHost()
        if host is urlHost
          next()
          return
        unless config.redirectAddressToCanonical
          addressHost = URLMaker.makeHost(address, port)
          if host is addressHost
            next()
            return
        res.redirect URLMaker.makeURL(req.url), 301
        return

      
      # Templates are in public
      app.set "views", path.resolve(__dirname, "../public/template")
      app.set "view engine", "utml"
      app.use requestLogger(log)
      app.use canonicalHost  if config.redirectToCanonical
      app.use rawBody
      app.use express.bodyParser()
      app.use express.cookieParser()
      app.use express.query()
      app.use express.methodOverride()
      
      # ^ INPUTTY
      # v OUTPUTTY
      app.use express.compress()  if config.compress
      app.use versionStamp
      app.use express["static"](path.resolve(__dirname, "../public"))
      
      # Default is in public/images/favicon.ico
      # Can be overridden by a config setting
      app.use express.favicon(config.favicon)
      app.provider = new Provider(log, config.clients)
      
      # Initialize scripts
      _.each config.plugins, (pluginName) ->
        script = undefined
        if _.isFunction(plugins[pluginName].getScript)
          script = plugins[pluginName].getScript()
          log.debug
            plugin: pluginName
            script: script
          , "Adding script"
          config.scripts.push script
        return

      
      # defangs interpolated data objects
      defang = (obj) ->
        dup = _.clone(obj)
        _.each dup, (value, name) ->
          if name is "displayName" and _.isString(value)
            dup[name] = sanitize(value).escape()
          else if _.isFunction(value)
            delete dup[name]
          else dup[name] = defang(value)  if _.isObject(value)
          return

        dup

      app.use (req, res, next) ->
        res.local "config", config
        res.local "data", {}
        res.local "page",
          url: req.originalUrl

        res.local "template", {}
        
        # Initialize null
        res.local "principalUser", null
        res.local "principal", null
        res.local "user", null
        res.local "client", null
        res.local "nologin", false
        res.local "version", version
        res.local "messages",
          items: []

        res.local "notifications",
          items: []

        res.local "defang", defang
        next()
        return

      app.use auth([
        auth.Oauth(
          name: "client"
          realm: "OAuth"
          oauth_provider: app.provider
          oauth_protocol: (if (useHTTPS) then "https" else "http")
          authenticate_provider: null
          authorize_provider: null
          authorization_finished_provider: null
        )
        auth.Oauth(
          name: "user"
          realm: "OAuth"
          oauth_provider: app.provider
          oauth_protocol: (if (useHTTPS) then "https" else "http")
          authenticate_provider: oauth.authenticate
          authorize_provider: oauth.authorize
          authorization_finished_provider: oauth.authorizationFinished
        )
      ])
      app.use app.router
      return

    app.error (err, req, res, next) ->
      log.error
        err: err
        req: req
      , err.message
      if err instanceof HTTPError
        if req.xhr or req.originalUrl.substr(0, 5) is "/api/"
          res.json
            error: err.message
          , err.code
        else if req.accepts("html")
          res.status err.code
          res.render "error",
            page:
              title: "Error"

            error: err

        else
          res.writeHead err.code,
            "Content-Type": "text/plain"

          res.end err.message
      else
        next err
      return

    
    # Routes
    api.addRoutes app
    webfinger.addRoutes app
    clientreg.addRoutes app
    shared.addRoutes app
    if config.uploaddir
      
      # Simple boolean flag
      config.canUpload = true
      uploads.addRoutes app
      Image.uploadDir = config.uploaddir
    confirm.addRoutes app  if config.requireEmail
    
    # Use "noweb" to disable Web site (API engine only)
    unless config.noweb
      web.addRoutes app
    else
      
      # A route to show the API doc at root
      app.get "/", (req, res, next) ->
        Showdown = require("showdown")
        converter = new Showdown.converter()
        Step (->
          fs.readFile path.join(__dirname, "..", "API.md"), this
          return
        ), (err, data) ->
          html = undefined
          markdown = undefined
          if err
            next err
          else
            markdown = data.toString()
            html = converter.makeHtml(markdown)
            res.render "doc",
              page:
                title: "API"

              html: html

          return

        return

    DatabankObject.bank = db
    URLMaker.hostname = hostname
    URLMaker.port = (if (config.urlPort) then config.urlPort else port)
    URLMaker.path = config.urlPath
    Distributor.log = log.child(component: "distributor")
    Distributor.plugins = _.filter(plugins, (plugin) ->
      _.isFunction(plugin.distributeActivity) or _.isFunction(plugin.distributeToPerson)
    )
    Upgrader.log = log.child(component: "upgrader")
    if config.serverUser
      app.on "listening", ->
        process.setuid config.serverUser
        return

    pumpsocket.connect app, log  if config.sockjs
    if config.firehose
      log.debug
        firehose: config.firehose
      , "Setting up firehose"
      Firehose.setup config.firehose, log
    if config.spamhost
      throw new Error("Need client ID and secret for spam host")  if not config.spamclientid or not config.spamclientsecret
      log.debug
        spamhost: config.spamhost
      , "Configuring spam host"
      ActivitySpam.init
        host: config.spamhost
        clientID: config.spamclientid
        clientSecret: config.spamclientsecret
        log: log

    dialbackClient = new DialbackClient(
      hostname: hostname
      bank: db
      app: app
      url: "/api/dialback"
    )
    Credentials.dialbackClient = dialbackClient
    
    # We set a timer so we start with an offset, instead of having
    # all workers start at almost the same time
    if config.cleanupNonce
      setTimeout (->
        log.debug "Cleaning up old OAuth nonces"
        Nonce.cleanup()
        setInterval (->
          log.debug "Cleaning up old OAuth nonces"
          Nonce.cleanup()
          return
        ), config.cleanupNonce * (config.workers or 1)
        return
      ), Math.floor(Math.random() * config.cleanupNonce * (config.workers or 1))
    Proxy.whitelist = app.config.proxyWhitelist
    app.run = (callback) ->
      self = this
      removeListeners = ->
        self.removeListener "listening", listenSuccessHandler
        self.removeListener "err", listenErrorHandler
        return

      listenErrorHandler = (err) ->
        removeListeners()
        log.error err
        callback err
        return

      listenSuccessHandler = ->
        removeBounceListeners = ->
          bounce.removeListener "listening", bounceSuccess
          bounce.removeListener "err", bounceError
          return

        bounceError = (err) ->
          removeBounceListeners()
          log.error err
          callback err
          return

        bounceSuccess = ->
          log.debug "Finished setting up bounce server."
          removeBounceListeners()
          callback null
          return

        log.debug "Finished setting up main server."
        removeListeners()
        if useBounce
          bounce.on "error", bounceError
          bounce.on "listening", bounceSuccess
          bounce.listen 80, address
        else
          callback null
        return

      @on "error", listenErrorHandler
      @on "listening", listenSuccessHandler
      log.info "Listening on " + port + " for host " + address
      @listen port, address
      return

    
    # So they can add their own routes or other stuff to the app
    _.each plugins, (plugin, name) ->
      if _.isFunction(plugin.initializeApp)
        log.debug
          plugin: name
        , "Initializing app."
        plugin.initializeApp app
      return

    callback null, app
    return

  return

exports.makeApp = makeApp
