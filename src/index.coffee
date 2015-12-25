JSZip = require("jszip")
bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)
fs = require("fs")

router = express.Router();

router.get '/sockets', (req, res)->
  res.json io.sockets.sockets.map (a)-> a.id

router.get '/start', (req, res)->
  res.statusCode = 204
  res.send()
  io.sockets.emit("start")

router.post "/push", (req, res)->
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
app.use('/demo', express.static(__dirname + '/../demo'));
app.use('/api', router)



io.on 'connection', (socket)->
  console.log("connection", socket.client.id)
  socket.on 'echo', (data)-> socket.emit("echo", data)
  socket.on 'event', console.info.bind(console, "event")
  socket.on 'disconnect', console.info.bind(console, "disconnect")


server.listen(8000)
