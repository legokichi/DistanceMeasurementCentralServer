__PORT_NUMBER__ = 8083

bodyParser = require('body-parser')
formidable = require('formidable')
express    = require('express')
http       = require('http')
socket     = require('socket.io')
app        = express()
server     = http.Server(app)
io         = socket(server)

app.use(bodyParser.urlencoded({ extended: true }))
app.use(bodyParser.json())

app.use('/',                 express.static(__dirname + '/demo'))
app.use('/bower_components', express.static(__dirname + '/bower_components'))
app.use('/lib',              express.static(__dirname + '/lib'))
app.use('/dist',             express.static(__dirname + '/dist'))

app.get '/barker', (req, res)->
  res.statusCode = 204; res.send(); start({pulseType: "barker", seed: n("0010000001"), carrierFreq: 4410})

app.get '/chirp', (req, res)->
  res.statusCode = 204; res.send(); start({pulseType: "chirp"})

app.get '/barkerCodedChirp', (req, res)->
  res.statusCode = 204; res.send(); start({pulseType: "barkerCodedChirp"})

app.get '/mseq', (req, res)->
  res.statusCode = 204; res.send(); start({pulseType: "mseq", length: 10, seedA: n("0010000001"), seedB: n("0011111111"), carrierFreq: 4410})

app.get '/reload', (req, res)->
  res.statusCode = 204; res.send(); io.of("/").emit("reload")

app.get '/play', (req, res)->
  res.statusCode = 204; res.send(); io.of("/").emit("play")

io.of("/").on 'connection', (socket)->
  socket.on 'disconnect', console.info.bind(console, "disconnect")
  socket.on "echo",       socket.emit.bind(socket, "echo")
  socket.on "volume",     (data)-> io.of('/').emit("volume", data)

server.listen(__PORT_NUMBER__)

# m-seq seed
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
start = (data)->
  room = io.of("/")
  console.log "started"
  Promise.resolve()
  .then -> requestParallel(room, "ready", data)
  .then -> console.log "sockets", sockets(room).map (socket)-> socket.id
  .then -> requestParallel(room, "startRec")
  .then ->
    foldable = sockets(room).map (socket)-> ->
      Promise.resolve()
      .then -> requestParallel(room, "startPulse", socket.id)
      .then -> request(socket, "beepPulse")
      .then -> console.log "beepPulse", socket.id
      .then -> requestParallel(room, "stopPulse", socket.id)
    return foldable.reduce(((a, b)-> a.then -> b()), Promise.resolve())
  .then -> requestParallel(room, "stopRec")
  .then -> requestParallel(room, "collect")
  .then -> requestParallel(room, "distribute")
  .then -> console.info "end"
  .catch (err)-> console.error err, err.stack

sockets = (room)->
  Object.keys(room.sockets).map (key)-> room.sockets[key]

request = (socket, eventName, data)->
  new Promise (resolve, reject)->
    socket.on eventName, (data)->
      socket.removeAllListeners eventName
      resolve(data)
    socket.emit(eventName, data)

requestParallel = (room, eventName, data)->
  console.log(eventName, data)
  prms = sockets(room).map (socket)-> request(socket, eventName, data)
  Promise.all(prms)

requestSerial = (room, eventName)->
  foldable = sockets(room).map (socket)-> -> request(socket, eventName, data)
  foldable.reduce(((a, b)-> a.then -> b()), Promise.resolve())
