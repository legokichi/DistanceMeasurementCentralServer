bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)
fs = require("fs")

api_router = express.Router();

api_router.get '/sockets', (req, res)->
  res.json io.sockets.sockets.map (a)-> a.id

api_router.get '/start', (req, res)->
  res.statusCode = 204
  res.send()
  start()

api_router.post "/push", (req, res)->
  form = new formidable.IncomingForm()
  form.encoding = "utf-8";
  form.uploadDir = "./uploads"
  form.parse req, (err, fields, files)->
    console.log err, fields, files
    oldPath = './' + files.file._writeStream.path
    newPath = './uploads/' + Date.now() + "_" + files.file.name
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
  console.log("connection", socket.client.id)
  socket.on 'echo', (data)-> socket.emit("echo", data)
  socket.on 'event', console.info.bind(console, "event")
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on 'start', start


server.listen(8000)


start = ->
  Promise.resolve()
  .then -> requestParallel "ready"
  .then -> requestParallel "startRec"
  .then ->
    prms = io.sockets.sockets.map (socket)-> ->
      Promise.resolve()
      .then -> requestParallel "startPulse", socket.id
      .then -> console.log("beepPulse", socket.id)
      .then -> request(socket, "beepPulse")
      .then -> requestParallel "stopPulse", socket.id
    a = prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
    a.catch (err)-> console.error err, err.stack
  .then -> requestParallel "stopRec"
  .then -> requestParallel "sendRec"
  .then (datas)-> console.log datas
  .then -> console.log "end"
  .catch (err)-> console.error err, err.stack

request = (socket, eventName, data)->
  new Promise (resolve, reject)->
    socket.on eventName, (data)->
      socket.removeAllListeners eventName
      resolve(data)
    socket.emit(eventName, data)

requestParallel = (eventName, data)->
  console.log "requestParallel", eventName
  prms = io.sockets.sockets.map (socket)-> request(socket, eventName, data)
  Promise.all(prms)

requestLinear = (eventName)->
  console.log "requestLinear", eventName
  prms = io.sockets.sockets.map (socket)-> -> request(socket, eventName, data)
  prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
