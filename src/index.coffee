# setup
window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

# color state
changeColor = ->
  document.body.style.backgroundColor = location.hash.slice(1)
  socket.emit("colors")
window.addEventListener("DOMContentLoaded", changeColor)
window.addEventListener("hashchange", changeColor)

# sockets
window["socket"] = socket = io(location.hostname+":"+location.port+"/node")

# middleware event
socket.on "connect",           console.info.bind(console, "connect")
socket.on "reconnect",         console.info.bind(console, "reconnect")
socket.on "reconnect_attempt", console.info.bind(console, "reconnect_attempt")
socket.on "reconnecting",      console.info.bind(console, "reconnecting")
socket.on "reconnect_error",   console.info.bind(console, "reconnect_error")
socket.on "reconnect_failed",  console.info.bind(console, "reconnect_failed")
socket.on "disconnect",        console.info.bind(console, "disconnect")
socket.on "error",             console.info.bind(console, "error")
socket.on "echo",              console.info.bind(console, "echo")
socket.on "connect",        -> socket.emit("colors")

# error logger
window.onerror = (err)->
  console.error(err, err?.stack)
  document.body.style.backgroundColor = "gray"
  pre = document.createElement("pre")
  textnode = document.createTextNode(err.stack || err)
  pre.appendChild textnode
  document.body.appendChild pre


# let
actx = new AudioContext()
osc = new OSC(actx)
gain = actx.createGain()
gain.connect(actx.destination)
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1); # between Math.pow(2,8) and Math.pow(2,14).
processor.connect(actx.destination)
processor.addEventListener "audioprocess", (ev)->
  if isRecording
    recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
  __nextTick__() if __nextTick__?
# need initialize
recbuf = null
isRecording = false
pulseStartTime = {}
pulseStopTime  = {}
DSSS_SPEC = null
__nextTick__ = null


# main
main = ->
  socket.on "color",      (a)->                  socket.emit("color", {id: socket.id, color: location.hash.slice(1)})
  socket.on "ready",      (a)-> ready(a)      -> socket.emit("ready")
  socket.on "startRec",      -> startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> stopRec       -> socket.emit("stopRec")
  socket.on "sendRec",       -> sendRec    (a)-> socket.emit("sendRec", a)
  socket.on "play",       (a)-> play(a)
  socket.on "volume",     (a)-> gain.gain.value = a[socket.id]


# where
n = (a)-> a.split("").map(Number)
ready      = ({length, seedA, seedB, carrier_freq})-> (next)->
  document.body.style.backgroundColor = location.hash.slice(1)
  recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
  isRecording    = false
  pulseStartTime = {}
  pulseStopTime  = {}
  DSSS_SPEC = null
  __nextTick__ = null
  mseqA = Signal.mseqGen(length, seedA)
  mseqB = Signal.mseqGen(length, seedB)
  matchedA = Signal.BPSK(mseqA, carrier_freq, actx.sampleRate, 0)
  matchedB = Signal.BPSK(mseqB, carrier_freq, actx.sampleRate, 0)
  signal = new Float32Array(matchedA.length*2 + matchedB.length)
  signal.set(matchedA, 0)
  signal.set(matchedB, matchedA.length*2)
  abuf = osc.createAudioBufferFromArrayBuffer(signal, actx.sampleRate)
  DSSS_SPEC = {abuf, length, seedA, seedB, carrier_freq}
  next()

startRec   = (next)-> isRecording = true; __nextTick__ = -> __nextTick__ = null; next()
startPulse = (id)-> (next)-> pulseStartTime[id] = actx.currentTime; next()
beepPulse  = (next)->
  {abuf} = DSSS_SPEC
  startTime = actx.currentTime
  anode = osc.createAudioNodeFromAudioBuffer(abuf)
  anode.connect(actx.destination)
  anode.start(startTime)
  do recur = ->
    if (startTime + abuf.duration) < actx.currentTime
    then setTimeout(next, 100)
    else setTimeout(recur, 100)
stopPulse  = (id)-> (next)-> __nextTick__ = -> pulseStopTime[id] = actx.currentTime; __nextTick__ = null; next()
stopRec    = (next) -> isRecording = false; next()
sendRec    = (next)->
  f32arr = recbuf.merge()
  recStartTime = recbuf.sampleTimes[0] - (recbuf.bufferSize / recbuf.sampleRate)
  recStopTime = recbuf.sampleTimes[recbuf.sampleTimes.length-1]
  startStops = Object.keys(pulseStartTime).map (id)->
    startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate|0
    stopPtr = (pulseStopTime[id] - recStartTime) * recbuf.sampleRate|0
    {id, startPtr, stopPtr}
  o =
    id: socket.id
    recStartTime: recStartTime
    recStopTime: recStopTime
    alias: location.hash.slice(1)
    startStops: startStops
    pulseStartTime: pulseStartTime
    pulseStopTime: pulseStopTime
    sampleTimes: recbuf.sampleTimes
    sampleRate: actx.sampleRate
    bufferSize: processor.bufferSize
    channelCount: processor.channelCount
    recF32arr: f32arr.buffer
    DSSS_SPEC: DSSS_SPEC
    currentTime: actx.currentTime
  recbuf.clear()
  next(o)

play = (data)->
  {wait, pulseTimes, delayTimes, id, currentTimes, recStartTimes, now, now2} = data
  # pulseTimes[socket.id][id] 自分がidの音を聞いた時刻
  # delayTimes[id][socket.id] 自分がidの音を聞いた時刻にidが実際に音を放っていた時間までの僅差
  offsetTime = recStartTimes[socket.id] + (
    pulseTimes[socket.id][id] - delayTimes[socket.id][id]
  ) + (
    currentTimes[id] - (pulseTimes[id][id] + recStartTimes[id])
  ) + (now2 - now)/1000 + wait
  osc.createAudioBufferFromURL("./TellYourWorld1min.mp3").then (abuf)->
    node = osc.createAudioNodeFromAudioBuffer(abuf)
    node.start(offsetTime+1)
    node.loop = false
    node.connect(gain)


_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    source.connect(processor)
    next()
  navigator.getUserMedia({video: false, audio: true}, right, left)

window.addEventListener "DOMContentLoaded", -> _prepareRec -> main()
