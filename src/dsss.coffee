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
CARRIER_FREQ = 4410/2
#MSEQ_KEY = [15, [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1]]
MSEQ_KEY = [12, [1,0,0,1,0,1,0,0,0,0,0,1]]
SS_CODE = Signal.mseqGen(MSEQ_KEY[0], MSEQ_KEY[1]) # {1,-1}
#SS_CODE = Signal.goldSeqGen(12, [1,0,0,1,0,1,0,0,0,0,0,1], [1,0,1,1,0,1,0,1,0,1,1,1], 3)
ENCODED_DATA = Signal.encode_chipcode([1], SS_CODE)
MATCHED = Signal.BPSK(SS_CODE, CARRIER_FREQ, actx.sampleRate, 0)
MODULATED_PULSE = Signal.BPSK(ENCODED_DATA, CARRIER_FREQ, actx.sampleRate, 0, ENCODED_DATA.length * (1/CARRIER_FREQ) * actx.sampleRate)
console.log abuf = osc.createAudioBufferFromArrayBuffer(MODULATED_PULSE, actx.sampleRate)
VIEW_SIZE = Math.pow(2, 10)

# main
main = ->
  notdo= ->
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
  socket.on "collect",    (a)-> collect(a)    -> socket.emit("collect")

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
    recStartTime = recbuf.sampleTimes[0] - (recbuf.bufferSize / recbuf.sampleRate)
    recStopTime = recbuf.sampleTimes[recbuf.sampleTimes.length-1]
    startStops = Object.keys(pulseStartTime).map (id)->
      startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate
      stopPtr = (pulseStopTime[id] - recStartTime) * recbuf.sampleRate
      {id, startPtr, stopPtr}
    o =
      id: socket.id
      alias: location.hash.slice(1)
      startStops: startStops
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
      SS_CODE: SS_CODE
      CARRIER_FREQ: CARRIER_FREQ
    recbuf.clear()
    next(o)
  collect = (datas)-> (next)->
    if location.hash.slice(1) isnt "red" then return next()
    console.log datas
    aliases = datas.reduce(((o, {id, alias})-> o[id] = alias; o), {})
    console.time("calc")
    results = datas.map ({id, alias, startStops, recF32arr, MATCHEDarr, sampleRate})->
      _results = startStops.map ({id: _id, startPtr, stopPtr})->
        section = new Float32Array(recF32arr).subarray(startPtr, stopPtr)
        correl = Signal.fft_smart_overwrap_correlation(section, new Float32Array(MATCHEDarr))
        console.log id, _id
        console.log [max_score, max_offset] = Signal.Statictics.findMax(correl)
        console.log stdev = Signal.Statictics.stdev(correl)
        console.log stdscore = Signal.Statictics.stdscore(correl, max_score)
        console.log pulseTime = (startPtr + max_offset) / sampleRate
        {id: _id, section, correl, max_score, max_offset, stdev, stdscore, pulseTime}
      {id, alias, results: _results}

    pulseTimes = {}
    relDelayTimes = {} # relDelayTimes:{[id:string]:{[id:string]: number}}
    delayTimes = {}
    distances = {}
    distancesAliased = {}
    results.forEach ({id, alias, results})->
      results.forEach ({id: _id, section, correl, max_score, max_offset, stdev, stdscore, pulseTime})->
        pulseTimes[id] = pulseTimes[id] || {}
        pulseTimes[id][_id] = pulseTime

    Object.keys(pulseTimes).forEach (id1)->
      Object.keys(pulseTimes).forEach (id2)->
        relDelayTimes[id1] = relDelayTimes[id1] || {}
        relDelayTimes[id1][id2] = pulseTimes[id1][id2] - pulseTimes[id1][id1]
    Object.keys(pulseTimes).forEach (id1)->
      Object.keys(pulseTimes).forEach (id2)->
        delayTimes[id1] = delayTimes[id1] || {}
        delayTimes[id1][id2] = Math.abs(Math.abs(relDelayTimes[id1][id2]) - Math.abs(relDelayTimes[id2][id1]))
        distances[id1] = distances[id1] || {}
        distances[id1][id2] = delayTimes[id1][id2]/2*340
        distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {}
        distancesAliased[aliases[id1]][aliases[id2]] = delayTimes[id1][id2]/2*340
    console.timeEnd("calc")
    console.info("distancesAliased", distancesAliased)
    setTimeout ->
      results.forEach ({id, alias, results})->
        results.forEach ({id: _id, section, correl, max_score, max_offset, stdev, stdscore, pulseTime})->
          document.body.appendChild document.createTextNode(aliases[id]+"@"+aliases[_id]+"("+id+"@"+_id+")")
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
          offset_arr[max_offset-256] = 255
          offset_arr[max_offset] = 255
          offset_arr[max_offset+256] = 255
          render.ctx.strokeStyle = "red"
          render.drawSignal(offset_arr, true, true)
          document.body.appendChild(render.element)
          # zoom
          zoomarr = correl.subarray(max_offset-256, max_offset+256)
          render = new Signal.Render(VIEW_SIZE, 127)
          render.drawSignal(zoomarr, true, true)
          document.body.appendChild(render.element)
          # offset
          render = new Signal.Render(VIEW_SIZE, 12)
          offset_arr = new Uint8Array(zoomarr.length)
          offset_arr[256] = 255
          render.ctx.strokeStyle = "red"
          render.drawSignal(offset_arr, true, true)
          document.body.appendChild(render.element)
      document.body.style.backgroundColor = "lime"
    next()



# where
_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    #source.connect(analyser)
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
  #document.body.appendChild(rndr.element)
  donot= render = ->
    spectrum = spectrums.shift()
    analyser.getByteFrequencyData(spectrum)
    spectrums.push(spectrum)
    rndr.drawSpectrogram(spectrums)
    requestAnimationFrame(render)
  next()
_flipProc = (next)-> (proc)-> proc(); next()

# main proc
window.addEventListener "DOMContentLoaded", -> _prepareRec -> _prepareSpect -> main()
