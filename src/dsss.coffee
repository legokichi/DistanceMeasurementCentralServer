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
VIEW_SIZE = Math.pow(2, 10)
RANGE = Math.pow(2, 10)
actx = new AudioContext()
osc = new OSC(actx)
analyser = actx.createAnalyser()
analyser.smoothingTimeConstant = 0
analyser.fftSize = 512
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1); # between Math.pow(2,8) and Math.pow(2,14).
# need initialize
recbuf = null
isRecording    = false
isBroadcasting = false
pulseStartTime = {}
pulseStopTime  = {}
correlCache = {}
DSSS_SPEC = null


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
ready      = ({length, seed, carrier_freq, isChirp, powL})-> (next)->
  n = (a)-> a.split("").map(Number)
  document.body.style.backgroundColor = location.hash.slice(1)
  recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
  isRecording    = false
  isBroadcasting = false
  pulseStartTime = {}
  pulseStopTime  = {}
  DSSS_SPEC = null
  if isChirp
    console.log ss_code = Signal.mseqGen(length, seed)
    osc.resampling(Signal.createCodedChirp(ss_code, powL), 14).then (matched)->
      abuf = osc.createAudioBufferFromArrayBuffer(matched, actx.sampleRate)
      DSSS_SPEC = {abuf, matched: matched.buffer}
      next()
  else
    ss_code = Signal.mseqGen(length, seed) # {1,-1}
    encoded_data = Signal.encode_chipcode_separated_zero([1, 1], ss_code) # {1,0,-1}
    matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0) # modulated
    ss_sig = Signal.BPSK(encoded_data, carrier_freq, actx.sampleRate, 0) # modulated
    abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate)
    DSSS_SPEC = {abuf, matched: matched.buffer}
    next()
    return

    corr = Signal.fft_smart_overwrap_correlation(ss_sig, matched)
    coms = [
      [matched, true, true]
      [ss_sig, true, true]
      [corr, true, true]
    ].forEach (com, i)->
      render = new Signal.Render(VIEW_SIZE, 64)
      Signal.Render::drawSignal.apply(render, com)
      document.body.appendChild render.element
      document.body.appendChild document.createElement "br"


startRec   = (next)-> isRecording = true; next()
startPulse = (id)-> (next)-> pulseStartTime[id] = actx.currentTime; next()
beepPulse  = (next)->
  {abuf} = DSSS_SPEC
  anode = osc.createAudioNodeFromAudioBuffer(abuf)
  anode.connect(actx.destination)
  anode.start(actx.currentTime)
  setTimeout((recur = ->
    if recbuf.chsBuffers[0].length > Math.ceil(abuf.length / processor.bufferSize)
    then next()
    else setTimeout(recur, 100)
  ), abuf.duration * 1.1 * 1000)
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
    DSSS_SPEC: DSSS_SPEC
  recbuf.clear()
  next(o)
collect = (datas)-> (next)->
  if location.hash.slice(1) isnt "red" then return next()
  console.info("calcCorrel")
  console.time("calcCorrel")
  results = datas.map ({id, alias, startStops, recF32arr, DSSS_SPEC, sampleRate})->
    correlCache[id] = correlCache[id] || {}
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      section = new Float32Array(recF32arr).subarray(startPtr, stopPtr)
      {matched} = DSSS_SPEC
      correl = Signal.fft_smart_overwrap_correlation(section, new Float32Array(matched))
      correlCache[id][_id] = correlCache[id][_id] || [null, null]
      correlCache[id][_id].shift()
      correlCache[id][_id].push correl
      [prev, curr] = correlCache[id][_id]
      if prev? and curr?
      then raked = Signal.fft_smart_overwrap_correlation(prev, curr)
      else raked = null
      [max_score, max_offset] = Signal.Statictics.findMax(correl)
      pulseTime = (startPtr + max_offset) / sampleRate
      {id: _id, section, correl, max_score, max_offset, pulseTime, raked}
    {id, alias, results: _results}
  console.timeEnd("calcCorrel")
  console.info("calcRelDist")
  console.time("calcRelDist")
  aliases = datas.reduce(((o, {id, alias})-> o[id] = alias; o), {})
  sampleRates = datas.reduce(((o, {id, sampleRate})-> o[id] = sampleRate; o), {})
  pulseTimes = {}
  relDelayTimes = {}
  delayTimes = {}
  distances = {}
  distancesAliased = {}
  results.forEach ({id, alias, results})->
    results.forEach ({id: _id, section, results, correl, max_score, max_offset, stdev, stdscore, pulseTime})->
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
      distancesAliased[aliases[id1]][aliases[id2]] = distances[id1][id2]
  console.timeEnd("calcRelDist")
  console.info("distancesAliased", distancesAliased)
  console.info("calcRelPos")
  console.time("calcRelPos")
  ds = Object.keys(delayTimes).map (id1)->
    Object.keys(delayTimes).map (id2)->
      distances[id1][id2]
  pseudoPts = results.map((id1, i)-> new Point(Math.random()*10, Math.random()*10))
  sdm = new SDM(pseudoPts, ds)
  K = 0
  while K++ < 200
    sdm.step()
  console.timeEnd("calcRelPos")
  console.info("calcRelPos", sdm.det(), sdm.points)
  setTimeout ->
    frame_ = _craetePictureFrame ""
    document.body.appendChild frame_.element
    results.forEach ({id, alias, results, sampleRate})->
      frame = _craetePictureFrame "#{alias}@#{id}"
      frame_.add frame.element
      results.forEach ({id: _id, section, correl, max_offset, raked})->
        # title
        _frame = _craetePictureFrame "#{aliases[id]}<->#{aliases[_id]}"
        frame.add _frame.element
        # result
        _frame.add "#{distances[id][_id]}m"
        # section
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(section, true, true)
        _frame.add render.element
        # offset
        render = new Signal.Render(VIEW_SIZE, 12)
        offset_arr = new Uint8Array(correl.length)
        offset_arr[max_offset-RANGE] = 255
        offset_arr[max_offset] = 255
        offset_arr[max_offset+RANGE] = 255
        render.ctx.strokeStyle = "red"
        render.drawSignal(offset_arr, true, true)
        _frame.add render.element
        # correl
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(correl, true, true)
        _frame.add render.element
        # zoom
        zoomarr = correl.subarray(max_offset-RANGE, max_offset+RANGE)
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(zoomarr, true, true)
        _frame.add render.element
        # offset
        render = new Signal.Render(VIEW_SIZE, 12)
        offset_arr = new Uint8Array(zoomarr.length)
        offset_arr[RANGE] = 255
        render.ctx.strokeStyle = "red"
        render.drawSignal(offset_arr, true, true)
        _frame.add render.element
        # rake
        if raked?
          render = new Signal.Render(VIEW_SIZE, 127)
          render.drawSignal(raked, true, true)
          _frame.add render.element
    # relpos
    render = new Signal.Render(Math.pow(2, 8), Math.pow(2, 8))
    basePt = sdm.points[0]
    sdm.points.forEach (pt)->
      render.cross(render.cnv.width/2+(pt.x-basePt.x)*10, render.cnv.height/2+(pt.y-basePt.y)*10, 16)
    frame_.add render.element
    document.body.style.backgroundColor = "lime"
  next()
_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    source.connect(analyser) if location.hash.slice(1) is "red"
    source.connect(processor)
    processor.connect(actx.destination)
    processor.addEventListener "audioprocess", (ev)->
      if(isRecording)
        recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
    next()
  navigator.getUserMedia({video: false, audio: true}, right, left)
_prepareSpect = (next)->
  if location.hash.slice(1) isnt "red" then return next()
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
_craetePictureFrame = (description) ->
  fieldset = document.createElement('fieldset')
  style = document.createElement('style')
  style.appendChild(document.createTextNode("canvas,img{border:1px solid black;}"))
  style.setAttribute("scoped", "scoped")
  fieldset.appendChild(style)
  legend = document.createElement('legend')
  legend.appendChild(document.createTextNode(description))
  fieldset.appendChild(legend)
  fieldset.style.display = 'inline-block'
  fieldset.style.backgroundColor = "#D2E0E6"
  return {
    element: fieldset
    add: (element)->
      if typeof element is "string"
        txtNode = document.createTextNode element
        p = document.createElement("p")
        p.appendChild txtNode
        fieldset.appendChild p
      else fieldset.appendChild element
  }

# main proc
window.addEventListener "DOMContentLoaded", -> _prepareRec -> _prepareSpect -> main()
