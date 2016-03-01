express = require('express')
http    = require('http')
socket  = require('socket.io')
peer     = require('peer')
app     = express()
server  = http.Server(app)
io      = socket(server)
peerSrv = peer.ExpressPeerServer(server, {debug: true})

app.use('/',                 express.static(__dirname + '/demo'))
app.use('/bower_components', express.static(__dirname + '/bower_components'))
app.use('/lib',              express.static(__dirname + '/lib'))
app.use('/dist',             express.static(__dirname + '/dist'))
app.use('/peerjs',           peerSrv)


io.on 'connection', (socket)->
  socket.on "echo", (data)-> socket.emit("echo", data)
  socket.on 'disconnect', console.info.bind(console, "socket:disconnect")

peerSrv.on "connection", -> console.info("peer:connection")
peerSrv.on "disconnect", -> console.info("peer:disconnect")

server.listen(8083)
