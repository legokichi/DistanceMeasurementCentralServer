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
VIEW_SIZE = Math.pow(2, 12)
actx = new AudioContext()
osc = new OSC(actx)
analyser = actx.createAnalyser()
analyser.smoothingTimeConstant = 0
analyser.fftSize = 512
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1); # between Math.pow(2,8) and Math.pow(2,14).
MULTIPASS_DISTANCE = 5
SOUND_OF_SPEED = 340
TEST_INPUT_MYSELF = false
_low_section_matched_ranges = {}
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
  socket.on "collect",    (a)-> collect(a) (a)-> socket.emit("collect", a)
  socket.on "play",       (a)-> play(a)       -> socket.emit("play")


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
  ss_code = Signal.mseqGen(length, seed) # {1,-1}
  matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0) # modulated
  ss_sig = matched#Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0, matched.length*PULSE_N) # modulated
  abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate)
  DSSS_SPEC = {abuf, length, seed, carrier_freq, isChirp, powL, PULSE_N}
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
  if TEST_INPUT_MYSELF
    anode.connect(processor)
    anode.connect(analyser)
  else anode.connect(actx.destination)
  anode.start(actx.currentTime)
  startTime = actx.currentTime
  do recur = ->
    if (startTime + abuf.duration * 1.2) < actx.currentTime
    then next()
    else setTimeout(recur, 100)
stopPulse  = (id)-> (next)-> pulseStopTime[id] = actx.currentTime; next()
stopRec    = (next) -> isRecording = false; next()
sendRec    = (next)->
  f32arr = recbuf.merge()
  recStartTime = recbuf.sampleTimes[0] - (recbuf.bufferSize / recbuf.sampleRate)
  recStopTime = recbuf.sampleTimes[recbuf.sampleTimes.length-1]
  startStops = Object.keys(pulseStartTime).map (id)->
    startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate
    stopPtr = (pulseStopTime[id] - recStartTime + 1) * recbuf.sampleRate
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
  recbuf.clear()
  next(o)
collect = (datas)-> (next)->
  if location.hash.slice(1) isnt "red" then return next()
  frame = _craetePictureFrame "collect", document.body
  aliases = datas.reduce(((o, {id, alias})-> o[id] = alias; o), {})
  results = datas.map ({id, alias, startStops, recF32arr, DSSS_SPEC, sampleRate})->
    {length, seed, carrier_freq, isChirp, powL, PULSE_N} = DSSS_SPEC
    _frame = _craetePictureFrame "#{alias}@#{id}"; frame.add _frame.element
    ss_code = Signal.mseqGen(length, seed) # {1,-1}
    matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0) # modulated
    recF32arr = new Float32Array(recF32arr)
    #_frame.view recF32arr, "recF32arr"
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      __frame = _craetePictureFrame "#{aliases[id]}<->#{aliases[_id]}"; _frame.add __frame.element
      T = matched.length
      section = recF32arr.subarray(startPtr, stopPtr)
      __frame.view section, "section"
      section_matched = Signal.fft_smart_overwrap_correlation(section, matched)
      __frame.view section_matched, "section * matched"
      __frame.text [val, idx] = Signal.Statictics.findMax(section_matched)
      range = MULTIPASS_DISTANCE/SOUND_OF_SPEED*sampleRate|0
      begin = idx-range; if begin < 0 then begin = 0
      end   = idx+range
      zoom_ratio = 50
      start = idx-section_matched.length/zoom_ratio|0; if start < 0 then start = 0
      stop  = idx+section_matched.length/zoom_ratio|0
      #section_matched_zoom = section_matched.subarray(start, stop)
      #__frame.view section_matched_zoom, "section * matched, zoom#{zoom_ratio}"
      section_matched_range = section_matched.subarray(begin, end)
      __frame.view section_matched_range, "section * matched, range#{MULTIPASS_DISTANCE}"
      mse_section_matched_range = section_matched_range.map (a)-> a*a # 二乗
      #__frame.view mse_section_matched_range, "section * matched, mse"
      cutoff = 1000
      low_section_matched_range = _lowpass(mse_section_matched_range, actx.sampleRate, cutoff, 1) # low-pass
      __frame.view low_section_matched_range, "section * matched, lowpass#{cutoff}"
      #sort_section_matched_range = new Float32Array(low_section_matched_range)
      #sort_section_matched_range.sort((a, b)-> a - b)
      #__frame.view sort_section_matched_range, "section * matched, sort"
      vari = Signal.Statictics.variance(low_section_matched_range)
      ave = Signal.Statictics.average(low_section_matched_range)
      med = Signal.Statictics.median(low_section_matched_range)
      threshold = 80
      stdscore_section_matched_range = low_section_matched_range.map (x)-> 10 * (x - ave) / vari + 50
      flag = true
      while flag
        for v, offset in stdscore_section_matched_range
          if threshold < v && med < v && ave < v
            flag = false
            break
        threshold -= 1
      marker = new Uint8Array(low_section_matched_range.length)
      marker[offset] = 255
      __frame.view marker, "offset#{offset}"
      max_offset = begin + offset
      pulseTime = (startPtr + max_offset) / sampleRate
      _low_section_matched_ranges[id] = _low_section_matched_ranges[id] || {}
      _low_section_matched_ranges[id][_id] = _low_section_matched_ranges[id][_id] || new Float32Array(low_section_matched_range.length)
      _low_section_matched_ranges[id][_id].forEach (_, i)->
        _low_section_matched_ranges[id][_id][i] += low_section_matched_range[i]
      __frame.view _low_section_matched_ranges[id][_id], "_low_section_matched_ranges[#{id}][#{_id}]"
      {id: _id, max_offset, pulseTime}
    {id, alias, results: _results}
  sampleRates = datas.reduce(((o, {id, sampleRate})-> o[id] = sampleRate; o), {})
  recStartTimes = datas.reduce(((o, {id, recStartTime})-> o[id] = recStartTime; o), {})
  pulseTimes = {} # 各端末時間での録音開始してからの自分のパルスを鳴らした時間
  relDelayTimes = {} # 自分にとって相手の音は何秒前or何秒後に聞こえたか。delayTimes算出に必要
  delayTimes = {} # 音速によるパルスの伝播時間
  distances = {}
  relDelayTimesAliased = {}
  distancesAliased = {}
  delayTimesAliased = {}
  pulseTimesAliased = {}
  results.forEach ({id, alias, results})->
    results.forEach ({id: _id, max_offset, pulseTime})->
      pulseTimes[id] = pulseTimes[id] || {}
      pulseTimes[id][_id] = pulseTime
      pulseTimesAliased[aliases[id]] = pulseTimesAliased[aliases[id]] || {}
      pulseTimesAliased[aliases[id]][aliases[_id]] = pulseTimes[id][_id]
  Object.keys(pulseTimes).forEach (id1)->
    Object.keys(pulseTimes).forEach (id2)->
      relDelayTimes[id1] = relDelayTimes[id1] || {}
      relDelayTimes[id1][id2] = pulseTimes[id1][id2] - pulseTimes[id1][id1]
      relDelayTimesAliased[aliases[id1]] = relDelayTimesAliased[aliases[id1]] || {}
      relDelayTimesAliased[aliases[id1]][aliases[id2]] = relDelayTimes[id1][id2]
  Object.keys(pulseTimes).forEach (id1)->
    Object.keys(pulseTimes).forEach (id2)->
      delayTimes[id1] = delayTimes[id1] || {}
      delayTimes[id1][id2] = Math.abs(Math.abs(relDelayTimes[id1][id2]) - Math.abs(relDelayTimes[id2][id1]))
      delayTimesAliased[aliases[id1]] = delayTimesAliased[aliases[id1]] || {}
      delayTimesAliased[aliases[id1]][aliases[id2]] = delayTimes[id1][id2]
      distances[id1] = distances[id1] || {}
      distances[id1][id2] = delayTimes[id1][id2]/2*SOUND_OF_SPEED
      distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {}
      distancesAliased[aliases[id1]][aliases[id2]] = distances[id1][id2]
  if console.table?
    console.group("table")
    console.info("recStartTimes", recStartTimes)
    console.info("pulseTimesAliased");    console.table(pulseTimesAliased)
    console.info("relDelayTimesAliased"); console.table(relDelayTimesAliased)
    console.info("delayTimesAliased");    console.table(delayTimesAliased)
    console.info("distancesAliased");     console.table(distancesAliased)
    console.groupEnd()
  ds = Object.keys(delayTimes).map (id1)->
    Object.keys(delayTimes).map (id2)->
      distances[id1][id2]
  pseudoPts = results.map((id1, i)-> new Point(Math.random()*10, Math.random()*10))
  sdm = new SDM(pseudoPts, ds)
  K = 0
  while K++ < 200
    sdm.step()
  #console.info("calcRelPos", sdm.det())
  #console.table(sdm.points)
  # relpos
  render = new Signal.Render(Math.pow(2, 8), Math.pow(2, 8))
  basePt = sdm.points[0]
  sdm.points.forEach (pt)->
    render.cross(render.cnv.width/2+(pt.x-basePt.x)*10, render.cnv.height/2+(pt.y-basePt.y)*10, 16)
  document.body.appendChild render.element
  document.body.style.backgroundColor = "lime"
  next({pulseTimes, delayTimes, aliases, currentTime: actx.currentTime, recStartTimes})
play = (data)-> (next)->
  console.log data
  {wait, pulseTimes, delayTimes, id, currentTime, recStartTimes, now, now2} = data
  # pulseTimes[socket.id][id] 自分がidの音を聞いた時刻
  # delayTimes[id][socket.id] 自分がidの音を聞いた時刻にidが実際に音を放っていた時間までの僅差
  # pulseTimes[socket.id][id] - delayTimes[id][socket.id] 自分の時間でidが実際に音を放っていた時間
  # actx.currentTime - (pulseTimes[socket.id][id] - delayTimes[id][socket.id]) 自分の時間でidが実際に音を放っていた時間、からの現在までの経過時間
  console.log actx.currentTime
  console.log offsetTime = recStartTimes[socket.id] + (
    pulseTimes[socket.id][id] - delayTimes[socket.id][id]
  ) + (
    currentTime - (pulseTimes[id][id] + recStartTimes[id])
  ) + (now2 - now)/1000 + wait + 3
  matched = Signal.BPSK([1], 2000, actx.sampleRate, 0, actx.sampleRate*1)
  abuf = osc.createAudioBufferFromArrayBuffer(matched, actx.sampleRate)
  setTimeout (->
    node = osc.createAudioNodeFromAudioBuffer(abuf)
    node.start(offsetTime+1)
    node.loop = false
    node.connect(actx.destination)
    next()
  ), 2000
  -> osc.createAudioBufferFromURL("./TellYourWorld1min.mp3").then (abuf)->
    node = osc.createAudioNodeFromAudioBuffer(abuf)
    node.start(offsetTime)
    node.loop = true
    node.connect(actx.destination)
    next()

_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    unless TEST_INPUT_MYSELF
      source.connect(processor)
      source.connect(analyser)
    processor.connect(actx.destination)
    prev = false
    processor.addEventListener "audioprocess", (ev)->
      if isRecording || prev
        recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
      prev = isRecording
    next()
  navigator.getUserMedia({video: false, audio: true}, right, left)
_prepareSpect = (next)->
  return next()
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
_craetePictureFrame = (description, target) ->
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
  target.appendChild fieldset if target?
  return {
    element: fieldset
    add: (element)->
      if typeof element is "string"
        txtNode = document.createTextNode element
        p = document.createElement("p")
        p.appendChild txtNode
        fieldset.appendChild p
      else fieldset.appendChild element
    view: (arr, title)->
      __frame = _craetePictureFrame title + "(#{arr.length})"
      width = if VIEW_SIZE < arr.length then VIEW_SIZE else arr.length
      render = new Signal.Render(width, 64)
      Signal.Render::drawSignal.apply(render, [arr, true, true])
      __frame.add render.element
      @add __frame.element
      @add document.createElement "br"
    text: (title)->
      @add document.createTextNode title
      @add document.createElement "br"
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
