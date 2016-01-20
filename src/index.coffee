# setup
window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

# color state
changeColor = -> document.body.style.backgroundColor = location.hash.slice(1)
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
socket.on "connect",        -> socket.emit("echo", socket.id)

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
analyser = actx.createAnalyser()
analyser.smoothingTimeConstant = 0
analyser.fftSize = 512
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1); # between Math.pow(2,8) and Math.pow(2,14).
gain = actx.createGain()
gain.connect(actx.destination)
TEST_INPUT_MYSELF = false
# need initialize
recbuf = null
isRecording    = false
isBroadcasting = false
pulseStartTime = {}
pulseStopTime  = {}
DSSS_SPEC = null
VOLUME = 1
__nextTick__ = null

# main
main = ->
  socket.on "ready",      (a)-> ready(a)      -> socket.emit("ready")
  socket.on "startRec",      -> startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> stopRec       -> socket.emit("stopRec")
  socket.on "sendRec",       -> sendRec    (a)-> socket.emit("sendRec", a)
  socket.on "play",       (a)-> play(a)       -> socket.emit("play")
  socket.on "set_vs_weight",(a)-> set_vs_weight(a) -> socket.emit("set_vs_weight")


# where
ready      = ({length, seed, carrier_freq, isChirp, powL, PULSE_N})-> (next)->
  n = (a)-> a.split("").map(Number)
  document.body.style.backgroundColor = location.hash.slice(1)
  recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
  isRecording    = false
  isBroadcasting = false
  pulseStartTime = {}
  pulseStopTime  = {}
  DSSS_SPEC = null
  __nextTick__ = null
  ss_code = Signal.mseqGen(length, seed) # {1,-1}
  matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0) # modulated
  ss_sig = matched#Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0, matched.length*PULSE_N) # modulated
  abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate)
  DSSS_SPEC = {abuf, length, seed, carrier_freq, isChirp, powL, PULSE_N}
  VOLUME = 1
  ->
    corr = Signal.fft_smart_overwrap_correlation(ss_sig, matched)
    coms = [
      [matched, true, true]
      [ss_sig, true, true]
      [corr, true, true]
    ].forEach (com, i)->
      render = new Signal.Render(com[0].length/100, 64)
      Signal.Render::drawSignal.apply(render, com)
      document.body.appendChild render.element
      document.body.appendChild document.createElement "br"
  next()
startRec   = (next)-> isRecording = true; __nextTick__ = -> __nextTick__ = null; next()
startPulse = (id)-> (next)-> pulseStartTime[id] = actx.currentTime; next()
beepPulse  = (next)->
  {abuf} = DSSS_SPEC
  anode = osc.createAudioNodeFromAudioBuffer(abuf)
  if TEST_INPUT_MYSELF
    anode.connect(processor)
    anode.connect(analyser)
  else anode.connect(actx.destination)
  anode.start(actx.currentTime)
  startTime = actx.currentTime
  do recur = ->
    if (startTime + abuf.duration) < actx.currentTime#recbuf.chsBuffers[0]? && recbuf.chsBuffers[0].length * processor.bufferSize > abuf.length #&&
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
play = (data)-> (next)->
  {wait, pulseTimes, delayTimes, id, currentTimes, recStartTimes, now, now2} = data
  # pulseTimes[socket.id][id] 自分がidの音を聞いた時刻
  # delayTimes[id][socket.id] 自分がidの音を聞いた時刻にidが実際に音を放っていた時間までの僅差
  offsetTime = recStartTimes[socket.id] + (
    pulseTimes[socket.id][id] - delayTimes[socket.id][id]
  ) + (
    currentTimes[id] - (pulseTimes[id][id] + recStartTimes[id])
  ) + (now2 - now)/1000 + wait + 3
  matched = Signal.BPSK([1,1,1,1,1], 2000, actx.sampleRate, 0, actx.sampleRate*1)
  ->
    abuf = osc.createAudioBufferFromArrayBuffer(matched, actx.sampleRate)
    setTimeout (->
      node = osc.createAudioNodeFromAudioBuffer(abuf)
      node.start(offsetTime+1)
      node.loop = false
      node.connect(gain)
      next()
    ), 2000
  osc.createAudioBufferFromURL("./TellYourWorld1min.mp3").then (abuf)->
    setTimeout (->
      node = osc.createAudioNodeFromAudioBuffer(abuf)
      node.start(offsetTime+1)
      node.loop = false
      node.connect(gain)
      next()
    ), 2000
set_vs_weight = (data)-> (next)->
  gain.gain.value = data[socket.id]
  next()


_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    unless TEST_INPUT_MYSELF
      source.connect(processor)
      source.connect(analyser)
    processor.connect(actx.destination)
    processor.addEventListener "audioprocess", (ev)->
      if isRecording #|| prev
        recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
      __nextTick__() if __nextTick__?
    next()
  navigator.getUserMedia({video: false, audio: true}, right, left)
_prepareSpect = (next)->
  return next()
  spectrums = (new Uint8Array(analyser.frequencyBinCount) for i in [0..analyser.frequencyBinCount])
  rndr = new Signal.Render(spectrums.length, spectrums[0].length)
  document.body.appendChild(rndr.element)
  do render = ->
    spectrum = spectrums.shift()
    analyser.getByteFrequencyData(spectrum)
    spectrums.push(spectrum)
    rndr.drawSpectrogram(spectrums)
    requestAnimationFrame(render)
  next()

window.addEventListener "DOMContentLoaded", -> _prepareRec -> _prepareSpect -> main()
