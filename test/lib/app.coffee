_ = require("underscore")
Step = require("step")
cluster = require("cluster")
mod = require("../../lib/app")
fs = require("fs")
path = require("path")
Dispatch = require("../../lib/dispatch")
makeApp = mod.makeApp
tc = JSON.parse(fs.readFileSync(path.resolve(__dirname, "..", "config.json")))
config =
  driver: tc.driver
  params: tc.params
  firehose: false
  sockjs: false
  noCDN: true
  debugClient: true
  nologger: true

app = null
i = undefined
parts = undefined
worker = undefined
process.env.NODE_ENV = "test"
i = 2
while i < process.argv.length
  parts = process.argv[i].split("=")
  config[parts[0]] = JSON.parse(parts[1])
  i++
config.port = parseInt(config.port, 10)
if cluster.isMaster
  worker = cluster.fork()
  worker.on "message", (msg) ->
    switch msg.cmd
      when "error", "listening", "credkilled", "objectchanged"
        process.send msg
      else

  Dispatch.start()
  process.on "message", (msg) ->
    switch msg.cmd
      when "killcred", "changeobject"
        worker.send msg

else
  Step (->
    makeApp config, this
    return
  ), ((err, res) ->
    throw err  if err
    app = res
    app.run this
    return
  ), (err) ->
    if err
      process.send
        cmd: "error"
        value: err

    else
      process.send cmd: "listening"
    return

  process.on "message", (msg) ->
    switch msg.cmd
      when "killcred"
        
        # This is to simulate losing the credentials of a remote client
        # It's hard to do without destroying the database values directly,
        # so we essentially do that.
        Step (->
          client = require("../../lib/model/client")
          Client = client.Client
          Client.search
            webfinger: msg.webfinger
          , this
          return
        ), ((err, results) ->
          throw err  if err
          throw new Error("Bad results")  if not results or results.length isnt 1
          results[0].del this
          return
        ), (err) ->
          if err
            process.send
              cmd: "credkilled"
              error: err.message
              webfinger: msg.webfinger

          else
            process.send
              cmd: "credkilled"
              webfinger: msg.webfinger

          return

      when "changeobject"
        
        # we break an object
        DatabankObject = require("databank").DatabankObject
        db = DatabankObject.bank
        object = msg.object
        Step (->
          db.update object.objectType, object.id, object, this
          return
        ), (err) ->
          if err
            process.send
              cmd: "objectchanged"
              error: err.message
              id: object.id

          else
            process.send
              cmd: "objectchanged"
              id: object.id

          return


