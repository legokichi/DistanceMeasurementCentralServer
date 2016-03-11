bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)
fs = require("fs")
logs = []
log = ->
  logs.push(Array::slice.call(arguments).join("\t"))
  console.log.apply(console, arguments)

logging = (str)->
  console.log("______LOG______", str)
  fs.appendFile './datalog.log', str+"\n",'utf8', (err) -> if err then console.log "______LOG______", err

app.use(bodyParser.urlencoded({ extended: true }))
app.use(bodyParser.json())
app.use('/', express.static(__dirname + '/../demo'))

app.get '/start', (req, res)->
  res.statusCode = 204
  res.send()
  start()



io.of('/node').on 'connection', (socket)->
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on "reload", -> io.of("/node").emit "reload"
  socket.on "colors", (data)-> console.log(io.of("/node")); requestParallel(io.of('/node'), "color").then (datas)-> io.of('/ui').emit("colors", datas)

io.of('/calc').on 'connection', (socket)->
  socket.on "log", (data)-> logging("CALC"+":"+JSON.stringify(data))
  socket.on 'disconnect', console.info.bind(console, "disconnect")

io.of('/ui').on 'connection', (socket)->
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on "volume", (data)-> console.log("ui:volume->node:volume");            io.of('/node').emit("volume", data)
  socket.on "start",        -> console.log("ui:start->server:start");            start()
  socket.on "play",   (data)-> console.log("ui:play->node:play");                io.of('/node').emit("play", data)
  socket.on "colors", (data)-> console.log("ui:colors->node:colors->ui:colors"); requestParallel(io.of('/node'), "color").then (datas)-> socket.emit("colors", datas)
  socket.on "log", (data)-> logging("UI"+":"+JSON.stringify(data))


server.listen(8083)

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
# length: 10, seed: n("0010000001")
# length: 10, seed: n("0011111111")
# length: 10, seed: n("0101010111")
# length:  9, seed: n("000100001")
# length:  6, seed: n("0010001")


n = (a)-> a.split("").map(Number)
start = ->
  logging("START:"+new Date()+"")
  console.log "started"
  Promise.resolve()
  .then -> requestParallel io.of('/node'), "ready", {length: 10, seedA: n("0010000001"), seedB: n("0011111111"), carrier_freq: 4410}
  .then -> log "node:sockets", io.of('/node').sockets.map (socket)-> socket.id
  .then -> log "ui:sockets", io.of('/ui').sockets.map (socket)-> socket.id
  .then -> log "calc:sockets", io.of('/calc').sockets.map (socket)-> socket.id
  .then -> requestParallel io.of('/node'), "startRec"
  .then ->
    prms = io.of('/node').sockets.map (socket)-> ->
      Promise.resolve()
      .then -> requestParallel io.of('/node'), "startPulse", socket.id
      .then -> request(socket, "beepPulse")
      .then -> log("beepPulse", socket.id)
      .then -> requestParallel io.of('/node'), "stopPulse", socket.id
    prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
  .then -> requestParallel io.of('/node'), "stopRec"
  .then -> requestParallel io.of('/node'), "sendRec"
  .then (datas)-> requestParallel io.of('/calc'), "calc", datas
  .then (datas)-> requestParallel io.of('/ui'), "repos", datas[0]
  .then -> console.info "end"
  .then -> setTimeout start
  .catch (err)-> console.error err, err.stack


request = (socket, eventName, data)->
  new Promise (resolve, reject)->
    socket.on eventName, (data)->
      socket.removeAllListeners eventName
      resolve(data)
    socket.emit(eventName, data)

requestParallel = (room, eventName, data)->
  console.log(eventName, data)
  prms = room.sockets.map (socket)-> request(socket, eventName, data)
  Promise.all(prms)

requestLinear = (room, eventName)->
  prms = room.sockets.map (socket)-> -> request(socket, eventName, data)
  prms.reduce(((a, b)-> a.then -> b()), Promise.resolve())
