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
recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
isRecording    = false
isBroadcasting = false
pulseStartTime = {}
pulseStopTime  = {}
DSSS_SPECS = []
VIEW_SIZE = Math.pow(2, 10)

# main
main = ->
  socket.on "ready",      (a)-> ready(a)      -> socket.emit("ready")
  socket.on "startRec",      -> startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> stopRec       -> socket.emit("stopRec")
  socket.on "sendRec",       -> sendRec    (a)-> socket.emit("sendRec", a)
  socket.on "collect",    (a)-> collect(a)    -> socket.emit("collect")

# where
ready      = (data)-> (next)->
  document.body.style.backgroundColor = location.hash.slice(1)
  recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
  isRecording    = false
  isBroadcasting = false
  pulseStartTime = {}
  pulseStopTime  = {}
  DSSS_SPECS = data[socket.id].map ({length, seedA, seedB, shift, carrier_freq}, i)->
    ss_code = Signal.mseqGen(length, seedA) # {1,-1}
    #ss_code = Signal.goldSeqGen(length, seedA, seedB, shift)
    encoded_data = Signal.encode_chipcode([1], ss_code)
    matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0)
    modulated_pulse = Signal.BPSK(encoded_data, carrier_freq, actx.sampleRate, 0, encoded_data.length * (1/carrier_freq) * actx.sampleRate)
    abuf = osc.createAudioBufferFromArrayBuffer(modulated_pulse, actx.sampleRate)
    {abuf, delay: 0.1*i, matched: matched.buffer, ss_code, carrier_freq, modulated_pulse_length: modulated_pulse.length}
  next()
startRec   = (next)-> isRecording = true; next()
startPulse = (id)-> (next)-> pulseStartTime[id] = actx.currentTime; next()
beepPulse  = (next)->
  Promise.all DSSS_SPECS.map ({abuf, delay, modulated_pulse_length})->
    anode = osc.createAudioNodeFromAudioBuffer(abuf)
    anode.connect(actx.destination)
    anode.start(actx.currentTime + delay)
    new Promise (resolve, reject)->
      setTimeout((recur = ->
        if recbuf.chsBuffers[0].length > Math.ceil(modulated_pulse_length / processor.bufferSize)
        then resolve()
        else setTimeout(recur, 100)
      ), (modulated_pulse_length/actx.sampleRate + delay) * 1000)
  .catch (err)-> window.onerror(err)
  .then -> next()
stopPulse  = (id)-> (next)-> pulseStopTime[id] = actx.currentTime; next()
stopRec    = (next) -> isRecording = false; next()
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
    DSSS_SPECS: DSSS_SPECS
  recbuf.clear()
  next(o)
collect = (datas)-> (next)->
  if location.hash.slice(1) isnt "red" then return next()
  console.info("calc")
  console.time("calc")
  results = datas.map ({id, alias, startStops, recF32arr, DSSS_SPECS, sampleRate})->
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      section = new Float32Array(recF32arr).subarray(startPtr, stopPtr)
      __results = DSSS_SPECS.map ({matched, carrier_freq}, i)->
        correl = Signal.fft_smart_overwrap_correlation(section, new Float32Array(matched))
        [max_score, max_offset] = Signal.Statictics.findMax(correl)
        stdev = Signal.Statictics.stdev(correl)
        stdscore = Signal.Statictics.stdscore(correl, max_score)
        pulseTime = (startPtr + max_offset) / sampleRate
        return {correl, max_score, max_offset, stdev, stdscore, pulseTime}
      return {id: _id, section, results: __results}
    return {id, alias, results: _results}
  console.timeEnd("calc")
  aliases = datas.reduce(((o, {id, alias})-> o[id] = alias; o), {})
  console.info("afterCalc")
  console.time("afterCalc")
  pulseTimes = {}
  relDelayTimes = {}
  delayTimes = {}
  distances = {}
  distancesAliased = {}
  results.forEach ({id, alias, results})->
    results.forEach ({id: _id, section, results})->
      pulseTimes[id] = pulseTimes[id] || {}
      pulseTimes[id][_id] = []
      results.forEach ({correl, max_score, max_offset, stdev, stdscore, pulseTime}, i)->
        pulseTimes[id][_id][i] = pulseTime
  Object.keys(pulseTimes).forEach (id1)->
    Object.keys(pulseTimes).forEach (id2)->
      relDelayTimes[id1] = relDelayTimes[id1] || {}
      relDelayTimes[id1][id2] = []
      pulseTimes[id1][id2].forEach (_, i)->
        relDelayTimes[id1][id2][i] = pulseTimes[id1][id2][i] - pulseTimes[id1][id1][i]
  Object.keys(pulseTimes).forEach (id1)->
    Object.keys(pulseTimes).forEach (id2)->
      delayTimes[id1] = delayTimes[id1] || {}
      delayTimes[id1][id2] = []
      distances[id1] = distances[id1] || {}
      distances[id1][id2] = []
      distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {}
      distancesAliased[aliases[id1]][aliases[id2]] = []
      pulseTimes[id1][id2].forEach (_, i)->
        delayTimes[id1][id2][i] = Math.abs(Math.abs(relDelayTimes[id1][id2][i]) - Math.abs(relDelayTimes[id2][id1][i]))
        distances[id1][id2][i] = delayTimes[id1][id2][i]/2*340
        distancesAliased[aliases[id1]][aliases[id2]][i] = distances[id1][id2][i]
  console.timeEnd("afterCalc")
  console.info("distancesAliased", distancesAliased)
  setTimeout ->
    results.forEach ({id, alias, results})->
      results.forEach ({id: _id, section, results})->
        # title
        document.body.appendChild document.createTextNode("#{aliases[id]}<->#{aliases[_id]}")
        # section
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(section, true, true)
        document.body.appendChild(render.element)
        results.forEach ({correl, max_offset}, i)->
          document.body.appendChild document.createTextNode("#{aliases[id]}<-#{i}->#{aliases[_id]}")
          # correl
          render = new Signal.Render(VIEW_SIZE, 127)
          render.drawSignal(correl, true, true)
          document.body.appendChild(render.element)
          # offset
          RANGE = 512
          render = new Signal.Render(VIEW_SIZE, 12)
          offset_arr = new Uint8Array(correl.length)
          offset_arr[max_offset-RANGE] = 255
          offset_arr[max_offset] = 255
          offset_arr[max_offset+RANGE] = 255
          render.ctx.strokeStyle = "red"
          render.drawSignal(offset_arr, true, true)
          document.body.appendChild(render.element)
          # zoom
          zoomarr = correl.subarray(max_offset-RANGE, max_offset+RANGE)
          render = new Signal.Render(VIEW_SIZE, 127)
          render.drawSignal(zoomarr, true, true)
          document.body.appendChild(render.element)
          # offset
          render = new Signal.Render(VIEW_SIZE, 12)
          offset_arr = new Uint8Array(zoomarr.length)
          offset_arr[RANGE] = 255
          render.ctx.strokeStyle = "red"
          render.drawSignal(offset_arr, true, true)
          document.body.appendChild(render.element)
    document.body.style.backgroundColor = "lime"
  next()
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

# main proc
window.addEventListener "DOMContentLoaded", -> _prepareRec -> _prepareSpect -> main()
