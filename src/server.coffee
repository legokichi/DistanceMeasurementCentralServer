bodyParser = require('body-parser')
formidable = require('formidable')
express = require('express')
app = express()
server = require('http').Server(app)
io = require('socket.io')(server)
fs = require("fs")
serverStartID = Date.now()
experimentID = null
logs = []
log = ->
  logs.push(Array::slice.call(arguments).join("\t"))
  console.log.apply(console, arguments)

console.info("ServerStartID:", serverStartID)

api_router = express.Router();

api_router.get '/sockets', (req, res)->
  res.json io.sockets.sockets.map (a)-> a.id

api_router.get '/start', (req, res)->
  res.statusCode = 204
  res.send()
  start()

api_router.get '/stop', (req, res)->
  res.statusCode = 204
  res.send()
  stop()

api_router.post "/push", (req, res)->
  form = new formidable.IncomingForm()
  form.encoding = "utf-8";
  form.uploadDir = "./uploads"
  form.parse req, (err, fields, files)->
    console.info err, fields, files
    oldPath = './' + files.file._writeStream.path
    newPath = './uploads/' + ServerStartID + "_" + Date.now() + "_" + files.file.name
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
  socket.on 'start', -> start()
  socket.on 'stop', -> stop()

server.listen(8000)

# length: 15, seed: n("100000000000001")
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

isLooping = false
stop = ->
  isLooping = false
  console.log "stoped"
start = ->
  console.log "started"
  if !isLooping
    experimentID = Date.now()
    isLooping = true
    _loop(); return
  else console.log "already started"

_loop = ->
  n = (a)-> a.split("").map(Number)
  Promise.resolve()
  .then -> requestParallel "ready", {length: 9, seed: n("000100001"), carrier_freq: 2000, isChirp: false, powL: 10, PULSE_N: 2}
  .then -> log "sockets", io.sockets.sockets.map (socket)-> socket.id
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
  .then (datas)-> calc(datas); requestParallel "collect", datas
  .then -> console.info "end"
  .then -> if isLooping then setTimeout(_loop)
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

calc = (datas, next)->
  expHead = serverStartID + "_" + experimentID
  datas.forEach (data)->
    dataHead = expHead + "_" + data.id
    #fs.writeFileSync "uploads/" + dataHead + "_rec.dat", data.recF32arr
    #fs.writeFileSync "uploads/" + dataHead + "_mached.dat", data.MATCHEDarr
    #fs.writeFileSync "uploads/" + dataHead + "_rec.py", generateViewerPythonCode({fileName: dataHead+"_rec.dat", sampleRate: data.sampleRate})
    #fs.writeFileSync "uploads/" + dataHead + "_mached.py", generateViewerPythonCode({fileName: dataHead+"_mached.dat", sampleRate: data.sampleRate})
    #fs.writeFileSync "uploads/" + dataHead + "_detect.py", generateDetectionPythonCode({recFileName: dataHead+"_rec.dat", machedFileName: dataHead+"_mached.dat", sampleRate: data.sampleRate})
  #fs.writeFileSync "uploads/" + expHead + ".json", JSON.stringify(datas, null, "  ")
  #fs.writeFileSync "uploads/" + expHead + ".log", logs.join("\n")

  logs = []
  console.log(datas)


PYTHON_IMPORT = """
# coding: utf-8
import matplotlib.pyplot as plt
import matplotlib.mlab as mlab
import numpy as np
import scipy as sp
import sys
import struct
def plot(fnmtx):
    w = len(fnmtx[0])
    h = len(fnmtx)
    k = 1
    for fnarr in fnmtx:
        for fn in fnarr:
            plt.subplot(w,h,k)
            fn(k)
            k += 1
def read_Float32Array_from_file(file_name):
    f32arr = []
    with open(file_name, "rb") as f:
        while True:
            data = f.read(4)
            if not data: break
            f32 = struct.unpack('f', data)
            f32arr.append(f32[0])
        return f32arr
"""
generateViewerPythonCode = ({fileName, sampleRate})->
  """
  #{PYTHON_IMPORT}

  file_name = '#{fileName}'
  sample_rate = #{sampleRate}

  print "open:" + file_name
  f32arr = read_Float32Array_from_file(file_name)
  print len(f32arr)

  def plotPulse(id):
      plt.plot(xrange(len(f32arr)), f32arr)
  def plotSpecgram(id):
      nFFT=256
      window=sp.hamming(nFFT)
      Pxx,freqs, bins, im = plt.specgram(f32arr,
                                         NFFT=nFFT, Fs=sample_rate,
                                         noverlap=nFFT-1, window=mlab.window_hanning)

  plot([
      [plotPulse, plotSpecgram]
  ])
  plt.show()
  """

generateDetectionPythonCode = ({recFileName, machedFileName, sampleRate})->
  """
  #{PYTHON_IMPORT}

  rec_file_name = '#{recFileName}'
  pulse_file_name = '#{machedFileName}'
  sample_rate = #{sampleRate}

  rec_f32arr = read_Float32Array_from_file(rec_file_name)
  pulse_f32arr = read_Float32Array_from_file(pulse_file_name)

  def plotAutoCorrel(id):
    a = np.correlate(pulse_f32arr, rec_f32arr, "full")
    plt.plot(xrange(len(a)), a)

  plot([
      [plotAutoCorrel]
  ])
  plt.show()
  """
