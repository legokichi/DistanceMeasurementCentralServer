bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)
logs = []
log = ->
  logs.push(Array::slice.call(arguments).join("\t"))
  console.log.apply(console, arguments)



app.use(bodyParser.urlencoded({ extended: true }))
app.use(bodyParser.json())
app.use('/', express.static(__dirname + '/../demo'))



io.of('/node').on 'connection', (socket)->
  socket.on 'echo', (data)-> socket.emit("echo", data)
  socket.on 'event', console.info.bind(console, "event")
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on "colors", (data)->
    requestParallel("color").then (datas)->
      io.of('/calc').emit "colors", datas

io.of('/calc').on 'connection', (socket)->
  socket.on 'echo', (data)-> socket.emit("echo", data)
  socket.on 'event', console.info.bind(console, "event")
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on "volume", (data)->
    io.of('/node').sockets.map (socket)-> socket.emit("volume", data)
  socket.on "colors", (data)->
    requestParallel("color").then (datas)-> socket.emit "colors", datas
  socket.on "start", -> start()
  socket.on "play", (data)->
    console.log "play", data
    io.of('/node').emit("play", data)


server.listen(8000)


# length: 15, seed: n("100000000000001")
# length: 14, seed: n("11000000000101")
# length: 13, seed: n("1011000000001")
# length: 12, seed: n("111000011001")
# length: 12, seed: n("101101010111")
# length: 12, seed: n("100101000001")
# length: 12, seed: n("011110111111")
# length: 11, seed: n("10101010101")
# length: 11, seed: n("01001001001")
# length: 11, seed: n("01000000001")
# length: 11, seed: n("00011001111")
# length:  9, seed: n("000100001")
# length:  6, seed: n("0010001")



n = (a)-> a.split("").map(Number)
start = ->
  console.log "started"
  Promise.resolve()
  .then -> requestParallel "ready", {length: 12, seed: n("111000011001"), carrier_freq: 2000}
  .then -> log "sockets", io.of('/node').sockets.map (socket)-> socket.id
  .then -> requestParallel "startRec"
  .then ->
    prms = io.of('/node').sockets.map (socket)-> ->
      Promise.resolve()
      .then -> requestParallel "startPulse", socket.id
      .then -> request(socket, "beepPulse")
      .then -> log("beepPulse", socket.id)
      .then -> requestParallel "stopPulse", socket.id
    a = prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
    a.catch (err)-> error err, err.stack
  .then -> requestParallel "stopRec"
  .then -> requestParallel "sendRec"
  .then (datas)->
    sockets = io.of('/calc').sockets
    socket = sockets[sockets.length - 1]
    console.log "preCalc", datas, socket.id
    request(socket, "calc", datas)
  .then -> console.info "end"
  .catch (err)-> console.error err, err.stack


request = (socket, eventName, data)->
  new Promise (resolve, reject)->
    socket.on eventName, (data)->
      socket.removeAllListeners eventName
      resolve(data)
    socket.emit(eventName, data)

requestParallel = (eventName, data)->
  prms = io.of('/node').sockets.map (socket)-> request(socket, eventName, data)
  Promise.all(prms)

requestLinear = (eventName)->
  prms = io.of('/node').sockets.map (socket)-> -> request(socket, eventName, data)
  prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
