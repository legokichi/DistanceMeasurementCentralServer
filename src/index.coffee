bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)
fs = require("fs")
experimentStartID = Date.now()
experimentID = null
logs = []
log = ->
  logs.push(Array::slice.call(arguments).join("\t"))
  console.log.apply(console, arguments)

console.info("experimentStartID:", experimentStartID)

api_router = express.Router();

api_router.get '/sockets', (req, res)->
  res.json io.sockets.sockets.map (a)-> a.id

api_router.get '/start', (req, res)->
  experimentID = Date.now()
  res.statusCode = 204
  res.send()
  start()

api_router.post "/push", (req, res)->
  form = new formidable.IncomingForm()
  form.encoding = "utf-8";
  form.uploadDir = "./uploads"
  form.parse req, (err, fields, files)->
    console.info err, fields, files
    oldPath = './' + files.file._writeStream.path
    newPath = './uploads/' + experimentID + "_" + Date.now() + "_" + files.file.name
    fs.rename oldPath, newPath, (err)-> if (err) then throw err;
  res.statusCode = 204
  res.send()

app.use(bodyParser.urlencoded({ extended: true }))
app.use(bodyParser.json())
app.use('/api', api_router)
app.use('/demo', express.static(__dirname + '/../demo'))

app.get "/", (req, res)->
  res.redirect(301, '/demo' + req.path)

io.on 'connection', (socket)->
  console.info("connection", socket.client.id)
  socket.on 'echo', (data)-> socket.emit("echo", data)
  socket.on 'event', console.info.bind(console, "event")
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on 'start', start


server.listen(8000)


start = ->
  Promise.resolve()
  .then -> requestParallel "ready"
  .then -> log "sockets", io.sockets.sockets.map (a)-> a.id
  .then -> requestParallel "startRec"
  .then ->
    prms = io.sockets.sockets.map (socket)-> ->
      Promise.resolve()
      .then -> requestParallel "startPulse", socket.id
      .then -> request(socket, "beepPulse")
      .then -> log("beepPulse", socket.id)
      .then -> requestParallel "stopPulse", socket.id
    a = prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
    a.catch (err)-> error err, err.stack
  .then -> requestParallel "stopRec"
  .then -> requestParallel "sendRec"
  .then (datas)-> calc(datas)
  .then -> console.info "end"
  .catch (err)-> console.error err, err.stack

request = (socket, eventName, data)->
  new Promise (resolve, reject)->
    socket.on eventName, (data)->
      socket.removeAllListeners eventName
      resolve(data)
    socket.emit(eventName, data)

requestParallel = (eventName, data)->
  log "requestParallel", eventName
  prms = io.sockets.sockets.map (socket)-> request(socket, eventName, data)
  Promise.all(prms)

requestLinear = (eventName)->
  log "requestLinear", eventName
  prms = io.sockets.sockets.map (socket)-> -> request(socket, eventName, data)
  prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())

calc = (datas)->
  datas.forEach (data)->
    fs.writeFileSync "uploads/" + experimentStartID + "_" + experimentID + data.id + ".dat", data.f32arr
    data.f32arr = null
  fs.writeFileSync "uploads/" + experimentStartID + "_" + experimentID + ".json", JSON.stringify(datas, null, "  ")
  fs.writeFileSync "uploads/" + experimentStartID + "_" + experimentID + ".log", logs.join("\n")
  logs = []
  console.log(datas)
