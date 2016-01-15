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
ready      = ({length, seed, carrier_freq})-> (next)->
  document.body.style.backgroundColor = location.hash.slice(1)
  recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
  isRecording    = false
  isBroadcasting = false
  pulseStartTime = {}
  pulseStopTime  = {}
  DSSS_SPEC = null

  ss_code = Signal.mseqGen(length, seed) # {1,-1}
  encoded_data = Signal.encode_chipcode([1], ss_code) # {1,0,-1}
  matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0) # modulated
  modulated_pulse = Signal.BPSK(encoded_data, carrier_freq, actx.sampleRate, 0, encoded_data.length * (1/carrier_freq) * actx.sampleRate) # modulated
  abuf = osc.createAudioBufferFromArrayBuffer(matched, actx.sampleRate)
  #abuf = osc.createAudioBufferFromArrayBuffer(modulated_pulse, actx.sampleRate)
  DSSS_SPEC = {abuf, matched: matched.buffer, ss_code, carrier_freq, modulated_pulse_length: modulated_pulse.length}
  next()
startRec   = (next)-> isRecording = true; next()
startPulse = (id)-> (next)-> pulseStartTime[id] = actx.currentTime; next()
beepPulse  = (next)->
  {abuf, modulated_pulse_length} = DSSS_SPEC
  anode = osc.createAudioNodeFromAudioBuffer(abuf)
  anode.connect(actx.destination)
  anode.start(actx.currentTime)
  setTimeout((recur = ->
    if recbuf.chsBuffers[0].length > Math.ceil(modulated_pulse_length / processor.bufferSize)
    then next()
    else setTimeout(recur, 100)
  ), (modulated_pulse_length/actx.sampleRate) * 1.1 * 1000)
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
  console.info("calc")
  console.time("calc")
  results = datas.map ({id, alias, startStops, recF32arr, DSSS_SPEC, sampleRate})->
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      section = new Float32Array(recF32arr).subarray(startPtr, stopPtr)
      {matched, carrier_freq} = DSSS_SPEC
      correl = Signal.fft_smart_overwrap_correlation(section, new Float32Array(matched))
      [max_score, max_offset] = Signal.Statictics.findMax(correl)
      stdev = Signal.Statictics.stdev(correl)
      stdscore = Signal.Statictics.stdscore(correl, max_score)
      pulseTime = (startPtr + max_offset) / sampleRate
      {id: _id, section, correl, max_score, max_offset, stdev, stdscore, pulseTime}
    {id, alias, results: _results}
  console.timeEnd("calc")
  console.info("afterCalc")
  console.time("afterCalc")
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
  console.timeEnd("afterCalc")
  console.info("distancesAliased", distancesAliased)
  setTimeout ->
    frame_ = _craetePictureFrame "=================="
    document.body.appendChild frame_.element
    results.forEach ({id, alias, results, sampleRate})->
      frame = _craetePictureFrame "#{alias}@#{id}"
      frame_.add frame.element
      results.forEach ({id: _id, section, correl, max_offset})->
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
        RANGE = Math.pow(2, 10)
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
        # lowpass
        zoomarr = _lowpass(zoomarr, sampleRates[id], 100, 1/Math.sqrt(2, 2))
        render = new Signal.Render(VIEW_SIZE, 127)
        render.drawSignal(zoomarr, true, true)
        _frame.add render.element
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
# void lowpass(float input[], float output[], int size, float samplerate, float freq, float q)
_lowpass = (input, sampleRate, freq, q)->
  ###
  // float input[]  …入力信号の格納されたバッファ。
  // flaot output[] …フィルタ処理した値を書き出す出力信号のバッファ。
  // int   size     …入力信号・出力信号のバッファのサイズ。
  // float sampleRate … サンプリング周波数。
  // float freq … カットオフ周波数。
  // float q    … フィルタのQ値。
  ###
  size = input.length
  output = new Float32Array(size)
  # // フィルタ係数を計算する
  omega = 2.0 * Math.PI *  freq　/　sampleRate
  alpha = Math.sin(omega) / (2.0 * q)

  a0 =  1.0 + alpha;
  a1 = -2.0 * Math.cos(omega);
  a2 =  1.0 - alpha;
  b0 = (1.0 - Math.cos(omega)) / 2.0
  b1 =  1.0 - Math.cos(omega);
  b2 = (1.0 - Math.cos(omega)) / 2.0

  # // フィルタ計算用のバッファ変数。
  in1  = 0.0
  in2  = 0.0
  out1 = 0.0
  out2 = 0.0

  # // フィルタを適用
  for i in [0..size]
    #// 入力信号にフィルタを適用し、出力信号として書き出す。
    output[i] = b0/a0 * input[i] + b1/a0 * in1  + b2/a0 * in2 - a1/a0 * out1 - a2/a0 * out2

    in2  = in1;       #// 2つ前の入力信号を更新
    in1  = input[i];  #// 1つ前の入力信号を更新

    out2 = out1;      #// 2つ前の出力信号を更新
    out1 = output[i]; #// 1つ前の出力信号を更新

  return output


# main proc
window.addEventListener "DOMContentLoaded", -> _prepareRec -> _prepareSpect -> main()
