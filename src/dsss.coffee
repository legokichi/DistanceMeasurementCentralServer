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
    matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0, processor.bufferSize*3) # modulated
    ss_sig = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0, processor.bufferSize*3) # modulated
    abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate)
    DSSS_SPEC = {abuf, matched: matched.buffer}
    console.log matched.length, ss_sig.length, abuf
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
  frame_ = _craetePictureFrame ""
  document.body.appendChild frame_.element
  aliases = datas.reduce(((o, {id, alias})-> o[id] = alias; o), {})
  results = datas.map ({id, alias, startStops, recF32arr, DSSS_SPEC, sampleRate})->
    frame = _craetePictureFrame "#{alias}@#{id}"
    frame_.add frame.element
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      section = new Float32Array(recF32arr).subarray(startPtr, stopPtr)
      matched = new Float32Array(DSSS_SPEC.matched)
      correl = Signal.fft_smart_overwrap_correlation(section, matched)
      # 相関結果を切りわける
      T = matched.length
      arrs = for i in [0..Math.ceil(correl.length/T)]
        _arr = new Float32Array(T)
        _arr.set(correl.subarray(T*i, T*i+T), 0)
        _arr
      S = new Float32Array(T)
      # Sにarrを加算合成
      for _,i in S
        sum = 0
        for arr in arrs
          sum += arr[i]
        S[i] = sum
      range = Math.pow(2, 9)
      [_, idxS] = Signal.Statictics.findMax(S)
      # 加算したもののピークを基準として +-range の区間切り出し
      _S = S.subarray(idxS-range, idxS+range)
      # 平均化
      ave = Signal.Statictics.average(_S)
      for _,i in _S
        _S[i] = _S[i] - ave
      U = range*2
      maxesSS = new Float32Array(U)
      # パルスを後ろからずらしてエネルギーが最大になる地点を探索。計算量悪し
      for i in [0..U*0.8|0]
        __S = new Float32Array(U)
        __S.set(_S.subarray(U-i, U), 0)
        corrSS = Signal.fft_smart_overwrap_correlation(_S, __S)
        [val, idx] = Signal.Statictics.findMax(corrSS)
        maxesSS[i] = if idx > 0 then val else 0
      [_, idxSS] = Signal.Statictics.findMax(maxesSS) # これがピーク
      max_offset = idxS-range+(idxSS+idxSS)/2
      pulseTime = (startPtr + max_offset) / sampleRate
      # title
      _frame = _craetePictureFrame "#{aliases[id]}<->#{aliases[_id]}"
      frame.add _frame.element
      S_clipe_range = new Uint8Array(T)
      S_clipe_range[idxS-range] = 255
      S_clipe_range[idxS+range] = 255
      maxesSS_pt = new Uint8Array(U)
      maxesSS_pt[idxSS] = 255
      [_, idxS] = Signal.Statictics.findMax(_S)
      maxesSS_pt[idxS] = 255
      coms = [
        [section, true, true]
        [correl, true, true]
        [S, true, true]
        [S_clipe_range, true, true]
        [_S, true, true]
        [maxesSS_pt, true, true]
        [maxesSS, true, true]
      ].forEach (com, i)->
        render = new Signal.Render(VIEW_SIZE, 64)
        Signal.Render::drawSignal.apply(render, com)
        _frame.add render.element
        _frame.add document.createElement "br"
      {id: _id, max_offset, pulseTime}
    {id, alias, results: _results}
  console.timeEnd("calcCorrel")
  console.info("calcRelDist")
  console.time("calcRelDist")
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
  # relpos
  render = new Signal.Render(Math.pow(2, 8), Math.pow(2, 8))
  basePt = sdm.points[0]
  sdm.points.forEach (pt)->
    render.cross(render.cnv.width/2+(pt.x-basePt.x)*10, render.cnv.height/2+(pt.y-basePt.y)*10, 16)
  document.body.appendChild render.element
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
