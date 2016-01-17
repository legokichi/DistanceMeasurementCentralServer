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
ready      = ({length, seed, carrier_freq, isChirp, powL, PULSE_N})-> (next)->
  n = (a)-> a.split("").map(Number)
  document.body.style.backgroundColor = location.hash.slice(1)
  recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
  isRecording    = false
  isBroadcasting = false
  pulseStartTime = {}
  pulseStopTime  = {}
  DSSS_SPEC = null
  if isChirp
    ss_code = Signal.mseqGen(length, seed)
    osc.resampling(Signal.createCodedChirp(ss_code, powL), 14).then (matched)->
      abuf = osc.createAudioBufferFromArrayBuffer(matched, actx.sampleRate)
      DSSS_SPEC = {abuf, matched: matched.buffer}
      next()
  else
    ss_code = Signal.mseqGen(length, seed) # {1,-1}
    matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0) # modulated
    ss_sig = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0, matched.length*PULSE_N) # modulated
    abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate)
    DSSS_SPEC = {abuf, matched: matched.buffer, PULSE_N}
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
    if (startTime + abuf.duration) < actx.currentTime
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
    {PULSE_N} = DSSS_SPEC
    frame = _craetePictureFrame "#{alias}@#{id}"
    frame_.add frame.element
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      _frame = _craetePictureFrame "#{aliases[id]}<->#{aliases[_id]}"
      frame.add _frame.element
      view = (arr, title)->
        __frame = _craetePictureFrame title + "(#{arr.length})"
        width = if VIEW_SIZE < arr.length then VIEW_SIZE else arr.length
        render = new Signal.Render(width, 64)
        Signal.Render::drawSignal.apply(render, [arr, true, true])
        __frame.add render.element
        _frame.add __frame.element
        _frame.add document.createElement "br"
      text = (title)->
        _frame.add document.createTextNode title
        _frame.add document.createElement "br"
      matched = new Float32Array(DSSS_SPEC.matched)
      T = matched.length
      recF32arr = new Float32Array(recF32arr)
      correl_full = Signal.fft_smart_overwrap_correlation(recF32arr, matched)
      section = recF32arr.subarray(startPtr, stopPtr)
      view section, "section"
      correl = correl_full.subarray(startPtr, stopPtr)
      view correl, "correl"
      marker = new Uint8Array(correl.length)
      correls = for i in [0..correl.length/T|0]
        marker[T*i] = 255
        marker[T*i+T] = 255
        a = correl.subarray(T*i, T*i+T)# 相関結果を切りわける
        if a.length is T
        then a
        else
          b = new Float32Array(T)
          b.set(a, 0)
          b
      view marker, "marker"
      summed = new Float32Array(T)
      summed.forEach (_,i)-> summed[i] = correls.reduce(((a, v)-> a + v[i]), 0) # 全加算
      view summed, "summed"
      # correlsからsummedとの相関が大きいものを探す
      maxes = correls.map (correl, i)-> {val:Signal.fft_smart_overwrap_correlation(correl, summed)[0], i}
      text "maxes:#{JSON.stringify(maxes)}"
      [_target] = maxes.sort (a, b)-> a.val < b.val
      target = correls[_target.i]
      src = correls[_target.i+1]
      text "correl#{_target.i}, correl#{_target.i+1}"
      # rake合成
      target_self = Signal.fft_smart_overwrap_correlation(target, target)
      src_self = Signal.fft_smart_overwrap_correlation(src, src)
      normalize_val = target_self[0] + src_self[0]
      raked = Signal.fft_smart_overwrap_correlation(target, src).map (v, i)-> v/normalize_val
      view raked, "raked(0)=#{raked[0]}" # raked は SN比計算に使う
      # 二分探索で一番相関してる場所を探す
      offset = 0
      length = src.length
      while length > Math.pow(2, 10)
        trgview = target.subarray(offset, offset+length)
        srcview = src.subarray(offset, offset+length)
        length = length/2|0
        text "offset:" + offset
        text "length:" + length
        srcL = src.subarray(offset,        offset+length)
        srcR = src.subarray(offset+length, offset+length+length)
        view trgview, "trgview"
        view srcview, "srcview"
        view Signal.fft_smart_overwrap_correlation(trgview, srcview), "correlviews"
        # 正規化相互相関関数
        correlL = Signal.fft_smart_overwrap_correlation(trgview, srcL).map (v, i)-> v/normalize_val
        correlR = Signal.fft_smart_overwrap_correlation(trgview, srcR).map (v, i)-> v/normalize_val
        view correlL, "correlL"
        view correlR, "correlR"
        text [valL, idL] = Signal.Statictics.findMax(correlL)
        text [valR, idR] = Signal.Statictics.findMax(correlR)
        switch Math.max(valL, valR)
          when valL then offset += idL; text "left"
          when valR then offset += idR; text "right"
      view target, "target"
      marker = new Uint8Array(target.length)
      marker[offset] = 255
      view marker, "marker"
      view section, "section"
      view correl, "correl"
      marker = new Uint8Array(correl.length)
      marker[_target.i*T+offset] = 255
      view marker, "marker"
      ###
      mse_correls = correls.map (a)-> a.map (a)-> a*a # 二乗
      low = _lowpass(summed, actx.sampleRate, 1000, 1) # low-pass
      down_sample_ratio = 10
      down = new Float32Array(val for val,i in low when i%down_sample_ratio is 0) # 畳み込みの計算量削減のためのダウンサンプリング
      windowSize = down.length/1000|0
      conved = down.map (_, i)-> down.subarray(i, i+windowSize).reduce(((a,b)-> a+b), 0) # 係数なしで畳み込み
      conved_low = _lowpass(conved, actx.sampleRate, 1000, 1) # low-pass
      [_, idx_down] = Signal.Statictics.findMax(conved_low)
      i_down = idx_down
      while --i_down && conved_low[i_down-1] < conved_low[i_down] then ;
      max_offset_down = i_down + windowSize|0
      max_offset = max_offset_down * down_sample_ratio|0
      ###
      max_offset = 0
      pulseTime = (startPtr + max_offset) / sampleRate
      ###
      clip_ratio = 70
      range = summed.length/clip_ratio|0
      range_down = down.length/clip_ratio|0#MULTIPASS_DISTANCE/SOUND_OF_SPEED*actx.sampleRate/10|0
      [_, idx] = Signal.Statictics.findMax(summed)
      idx_down = idx/10|0
      # title
      ###
      ###
      start = if idx-range < 0 then 0 else idx-range
      stop  = idx+range
      start_down = if idx_down-range_down < 0 then 0 else idx_down-range_down
      stop_down = idx_down+range_down
      ###


      ###
      marker3 = new Uint8Array(T)
      marker3[start] = 255
      marker3[max_offset] = 255
      marker3[stop] = 255
      marker4 = new Uint8Array(down.length).subarray(start_down, stop_down)
      console.log max_offset_down, i_down, idx_down
      marker4[max_offset_down] = 255
      marker4[i_down] = 255
      marker4[idx_down] = 255

      [summed, true, true]
      [low, true, true]
      [down, true, true]
      [conved, true, true]
      [conved_low, true, true]
      [marker3, true, true]
      [summed.subarray(start, stop), true, true]
      [low.subarray(start, stop), true, true]
      [down.subarray(start_down, stop_down), true, true]
      [conved.subarray(start_down, stop_down), true, true]
      [conved_low.subarray(start_down, stop_down), true, true]
      [marker4, true, true]
      ###
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
      distances[id1][id2] = delayTimes[id1][id2]/2*SOUND_OF_SPEED
      distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {}
      distancesAliased[aliases[id1]][aliases[id2]] = distances[id1][id2]
  console.timeEnd("calcRelDist")
  console.info("distancesAliased", distancesAliased)
  ->
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
