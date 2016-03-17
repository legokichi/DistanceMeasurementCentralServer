__PORT_NUMBER__ = 8083

fs         = require("fs")
bodyParser = require('body-parser')
formidable = require('formidable')
express    = require('express')
http       = require('http')
socket     = require('socket.io')
php        = require("node-php")
app        = express()
server     = http.Server(app)
io         = socket(server)


app.use(bodyParser.urlencoded({ extended: true }))
app.use(bodyParser.json())

app.use('/',                 express.static(__dirname + '/demo'))
app.use('/bower_components', express.static(__dirname + '/bower_components'))
app.use('/lib',              express.static(__dirname + '/lib'))
app.use('/dist',             express.static(__dirname + '/dist'))
app.use("/php",                     php.cgi(__dirname + "/php"))

app.post "/push", (req, res)->
  form = new formidable.IncomingForm()
  form.encoding = "utf-8"
  form.uploadDir = "./uploads"
  form.parse req, (err, fields, files)->
    console.info err, fields, files
    oldPath = './' + files.file._writeStream.path
    newPath = './uploads/' + Date.now() + "_" + files.file.name
    fs.rename oldPath, newPath, (err)-> if (err) then throw err
  res.statusCode = 204
  res.send()

res204 =  (fn)-> (req, res)-> res.statusCode = 204; res.send(); fn()

app.get '/all',    res204 -> startAll()

app.get '/barker', res204 -> start({pulseType: "barker", carrierFreq: 4410})
app.get '/chirp',  res204 -> start({pulseType: "chirp", length:1024*8})
app.get '/bchirp', res204 -> start({pulseType: "barkerCodedChirp"})
app.get '/mseq',   res204 -> start({pulseType: "mseq", length: 10, seedA: n("0010000001"), seedB: n("0011111111"), carrierFreq: 4410})

app.get '/reload', res204 -> io.of("/").emit("reload")
app.get '/play',   res204 -> io.of("/").emit("play")

app.get '/sockets', (req, res)->
  res.json sockets(io.of("/")).map (a)-> a.id


io.of("/").on 'connection', (socket)->
  console.log "connection", socket.id
  socket.on 'disconnect', console.info.bind(console, "disconnect", socket.id)
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


# recording program tools

promisify = (fn)->
  new Promise (resolve, reject)->
    fn (err, data)->
      if err? then reject(err) else resolve(data)

start = (data)->
  {pulseType} = data
  console.log "start", pulseType
  experimentID = Date.now()
  room = io.of("/")
  requestParallel(room, "ready", data)
  .then -> promisify (cb)-> fs.writeFile("uploads/#{experimentID}_#{pulseType}.json", JSON.stringify(data), cb)
  .then(record(room))
  .then(collectRec(experimentID, room))
  .then -> requestParallel(room, "collect")
  .then (a)-> requestParallel(room, "distribute", a)
  .then -> console.info "end"
  .catch(catchExperiment(experimentID, room))

collectRec = (experimentID, room)-> ->
  Promise.resolve()
  .then -> requestParallel(room, "collectRec")
  .then (datas)->
    console.log datas
    Promise.all datas.map ({id, color, results: {wave, startStops, sampleRate}})->
      timeStamp = Date.now()
      Promise.all [
        promisify (cb)-> fs.writeFile("uploads/#{experimentID}_#{timeStamp}_#{color}_#{id}.wav", wave, cb)
        promisify (cb)-> fs.writeFile("uploads/#{experimentID}_#{timeStamp}_#{color}_#{id}.json", JSON.stringify({sampleRate, startStops}), cb)
      ]

catchExperiment = (experimentID, room)-> (err)->
  console.error err, err.stack
  timeStamp = Date.now()
  promisify (cb)-> fs.writeFile("uploads/#{experimentID}_#{timeStamp}_error.txt", "#{err.message}\n#{err.stack}\n", cb)

startAll = ->
  console.log "startAll"
  room = io.of("/")
  experimentID = null
  params = [
    {pulseType: "barker", carrierFreq: 4410}
    {pulseType: "chirp", length:1024*8}
    {pulseType: "barkerCodedChirp"}
    {pulseType: "mseq", length: 10, seedA: n("0010000001"), seedB: n("0011111111"), carrierFreq: 4410}
  ]
  applicative = (arr, fn)->
    foldable = arr.map (data, i)-> -> fn(data, i)
    return foldable.reduce(((a, b)-> a.then -> b()), Promise.resolve())
  applicative params, (data, i)->
    experimentID = Date.now()
    {pulseType} = data
    console.log experimentID, pulseType, data, i
    requestParallel(room, "ready", data)
    .then -> promisify (cb)-> fs.writeFile("uploads/#{experimentID}_#{pulseType}.json", JSON.stringify(data), cb)
    .then(record(room))
    .then ->
      step = collectRec(experimentID, room)
      console.log experimentID, "wrote"
      applicative [1..10], (j)->
        console.log i, j
        step()
        .then -> console.info "end"
  .then ->
    console.log "all task finished"
  .catch(catchExperiment(experimentID, room))

record = (room)-> ->
  requestParallel(room, "startRec")
  .then ->
    foldable = sockets(room).map (socket)-> ->
      Promise.resolve()
      .then -> requestParallel(room, "startPulse", socket.id)
      .then -> request(socket, "beepPulse")
      .then -> console.log "beepPulse", socket.id
      .then -> requestParallel(room, "stopPulse", socket.id)
    return foldable.reduce(((a, b)-> a.then -> b()), Promise.resolve())
  .then -> requestParallel(room, "stopRec")


# socket.io tools

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
