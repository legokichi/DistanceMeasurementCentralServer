bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)

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
  socket.on "play", (data)->
    console.log "play", data
    io.of('/node').emit("play", data)


server.listen(8000)

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
