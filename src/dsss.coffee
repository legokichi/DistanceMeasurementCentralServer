# setup
window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

# color state
changeColor = -> document.body.style.backgroundColor = location.hash.slice(1)
window.addEventListener("DOMContentLoaded", changeColor)
window.addEventListener("hashchange", changeColor)

# sockets
window["socket"] = socket = io(location.hostname+":"+location.port)

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
socket.on "connect",        -> socket.emit("echo", "hello")

# error logger
window.onerror = (err)->
  console.error(err)
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
recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
isRecording    = false
isBroadcasting = false
pulseStartTime = {}
pulseStopTime  = {}
CARRIER_FREQ = 4410
MSEQ_KEY = [15, [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1]]
SS_CODE = Signal.mseqGen(MSEQ_KEY[0], MSEQ_KEY[1]) # {1,-1}
#SS_CODE = Signal.goldSeqGen(12, [1,0,0,1,0,1,0,0,0,0,0,1], [1,0,1,1,0,1,0,1,0,1,1,1], 3)
console.log SS_CODE.length
ENCODED_DATA = Signal.encode_chipcode([1], SS_CODE)
MATCHED = Signal.BPSK(SS_CODE, CARRIER_FREQ, actx.sampleRate, 0)
console.log MATCHED.length
MODULATED_PULSE = Signal.BPSK(ENCODED_DATA, CARRIER_FREQ, actx.sampleRate, 0, ENCODED_DATA.length * (1/CARRIER_FREQ) * actx.sampleRate)
console.log ENCODED_DATA.length
console.log abuf = osc.createAudioBufferFromArrayBuffer(MODULATED_PULSE, actx.sampleRate)
VIEW_SIZE = Math.pow(2, 12)

# main
main = ->
  do ->
    correl = Signal.fft_smart_overwrap_correlation(ENCODED_DATA, SS_CODE)
    render = new Signal.Render(VIEW_SIZE, 127)
    render.drawSignal(ENCODED_DATA, true, true)
    document.body.appendChild(render.element)
    render = new Signal.Render(VIEW_SIZE, 127)
    render.drawSignal(correl, true, true)
    document.body.appendChild(render.element)
    correl = Signal.fft_smart_overwrap_correlation(MODULATED_PULSE, MATCHED)
    render = new Signal.Render(VIEW_SIZE, 127)
    render.drawSignal(MODULATED_PULSE, true, true)
    document.body.appendChild(render.element)
    render = new Signal.Render(VIEW_SIZE, 127)
    render.drawSignal(correl, true, true)
    document.body.appendChild(render.element)

  socket.on "ready",         -> ready         -> socket.emit("ready")
  socket.on "startRec",      -> startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> stopRec       -> socket.emit("stopRec")
  socket.on "sendRec",       -> sendRec    (a)-> socket.emit("sendRec", a)

  ready      = (next)-> next()
  startRec   = _flipProc -> isRecording = true
  startPulse = (id)-> _flipProc -> pulseStartTime[id] = actx.currentTime
  beepPulse  = (next)->
    anode = osc.createAudioNodeFromAudioBuffer(abuf)
    anode.connect(actx.destination)
    anode.start(actx.currentTime)
    setTimeout((recur = ->
      if recbuf.chsBuffers[0].length > Math.ceil(MODULATED_PULSE.length / processor.bufferSize)
      then next()
      else setTimeout(recur, 1)
    ), MODULATED_PULSE.length/actx.sampleRate * 1000)
  stopPulse  = (id)-> _flipProc -> pulseStopTime[id] = actx.currentTime
  stopRec    = _flipProc -> isRecording = false
  sendRec    = (next)->
    f32arr = recbuf.merge()
    Object.keys(pulseStartTime).forEach (id)->
      recStartTime = recbuf.sampleTimes[0] - (recbuf.bufferSize / recbuf.sampleRate)
      recStopTime = recbuf.sampleTimes[recbuf.sampleTimes.length-1]
      startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate
      stopPtr = (pulseStopTime[id] - recStartTime) * recbuf.sampleRate
      section = f32arr.subarray(startPtr, stopPtr)
      correl = Signal.fft_smart_overwrap_correlation(section, MATCHED)
      console.log [max_score, max_offset] = Signal.Statictics.findMax(correl)
      console.log Signal.Statictics.stdev(correl)
      console.log Signal.Statictics.stdscore(correl, max_score)

      do ->
        document.body.appendChild document.createTextNode(id+"@"+socket.id+location.hash)
        # signal
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(section, true, true)
        document.body.appendChild(render.element)
        # correl
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(correl, true, true)
        document.body.appendChild(render.element)
        # offset
        render = new Signal.Render(VIEW_SIZE, 12)
        offset_arr = new Uint8Array(correl.length)
        offset_arr[max_offset] = 255
        render.ctx.strokeStyle = "red"
        render.drawSignal(offset_arr, true, true)
        document.body.appendChild(render.element)
    o =
      id: socket.id
      alias: location.hash.slice(1)
      pulseStartTime: pulseStartTime
      pulseStopTime: pulseStopTime
      sampleTimes: recbuf.sampleTimes
      sampleRate: actx.sampleRate
      bufferSize: processor.bufferSize
      channelCount: processor.channelCount
      recF32arr: f32arr.buffer
      recF32arrLen: f32arr.length
      MATCHEDarr: MATCHED.buffer
      MATCHEDLen: MATCHED.length
      MSEQ_KEY: MSEQ_KEY
    recbuf.clear()
    next(o)


# where
_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    source.connect(analyser)
    source.connect(processor)
    processor.connect(actx.destination)
    processor.addEventListener "audioprocess", (ev)->
      if(isRecording)
        recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
    next()
  navigator.getUserMedia({video: false, audio: true}, right, left)
_prepareSpect = (next)->
  targetIndex = (CARRIER_FREQ * analyser.fftSize) / actx.sampleRate |0
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
_flipProc = (next)-> (proc)-> proc(); next()

# main proc
window.addEventListener "DOMContentLoaded", -> _prepareRec -> _prepareSpect -> main()
