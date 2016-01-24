# sockets
window["socket"] = socket = io(location.hostname+":"+location.port+"/calc")

# middleware event
socket.on "connect",           console.info.bind(console, "connect")
socket.on "reconnect",         console.info.bind(console, "reconnect")
socket.on "reconnect_attempt", console.info.bind(console, "reconnect_attempt")
socket.on "reconnecting",      console.info.bind(console, "reconnecting")
socket.on "reconnect_error",   console.info.bind(console, "reconnect_error")
socket.on "reconnect_failed",  console.info.bind(console, "reconnect_failed")
socket.on "disconnect",        console.info.bind(console, "disconnect")
socket.on "error",             console.info.bind(console, "error")

MULTIPASS_DISTANCE = 3
SOUND_OF_SPEED = 340

socket.on "calc", (a)-> calc(a) (a)-> socket.emit("calc", a)

calc = (datas)-> (next)->
  if datas.length is 0 then return next()
  now = Date.now()
  frame = _craetePictureFrame "calc", document.body
  aliases = datas.reduce(((o, {id, alias})-> o[id] = alias; o), {})
  results = datas.map ({id, alias, startStops, recF32arr, DSSS_SPEC, sampleRate})->
    {length, seedA, seedB, carrier_freq} = DSSS_SPEC
    _frame = _craetePictureFrame "#{alias}@#{id}"; frame.add _frame.element
    mseqA = Signal.mseqGen(length, seedA)
    mseqB = Signal.mseqGen(length, seedB)
    matchedA = Signal.BPSK(mseqA, carrier_freq, sampleRate, 0)
    matchedB = Signal.BPSK(mseqB, carrier_freq, sampleRate, 0)
    recF32arr = new Float32Array(recF32arr)
    console.log recF32arr.length, alias
    _results = startStops.map ({id: _id, startPtr, stopPtr})->
      console.log _id, startPtr, stopPtr
      __frame = _craetePictureFrame "#{aliases[id]}<->#{aliases[_id]}"; _frame.add __frame.element
      rawdata = section = recF32arr.subarray(startPtr, stopPtr)
      correlA = Signal.fft_smart_overwrap_correlation(rawdata, matchedA)
      correlB = Signal.fft_smart_overwrap_correlation(rawdata, matchedB)
      __frame.view section, "section"
      __frame.view correlA, "correlA"
      __frame.view correlB, "correlB"
      [_, idxA] = Signal.Statictics.findMax(correlA)
      [_, idxB] = Signal.Statictics.findMax(correlB)
      relB = idxA+matchedA.length*2 # Bの位置とAから見たBの位置
      relA = idxB-matchedA.length*2 # Aの位置とBから見たAの位置
      stdscoreA = do ->
        ave = Signal.Statictics.average(correlA)
        vari = Signal.Statictics.variance(correlA)
        (x)-> 10 * (x - ave) / vari + 50
      stdscoreB = do ->
        ave = Signal.Statictics.average(correlB)
        vari = Signal.Statictics.variance(correlB)
        (x)-> 10 * (x - ave) / vari + 50
      scoreB = stdscoreB(correlB[idxB]) + stdscoreA(correlA[relA])
      scoreA = stdscoreA(correlA[idxA]) + stdscoreB(correlB[relB]) # Aの値とAから見たBの位置の値
      range = (MULTIPASS_DISTANCE/SOUND_OF_SPEED*sampleRate)|0
      if relA > 0 && scoreB > scoreA
        # Bが正しいのでAを修正
        #[_, idx] = Signal.Statictics.findMax(correlA.subarray(relA-range, relA+range))
        idxA = relA# - range + idx
      else
        # Aが正しいのでBを修正
        #[_, idx] = Signal.Statictics.findMax(correlB.subarray(relB-range, relB+range))
        idxB = relB# - range + idx
      marker = new Uint8Array(correlA.length)
      marker[idxA-range] = 255
      marker[idxA] = 255
      marker[idxA+range] = 255
      marker[idxB-range] = 255
      marker[idxB] = 255
      marker[idxB+range] = 255
      __frame.view marker,"marker"
      # 最大値付近を切り取り
      zoomA = correlA.subarray(idxA-range, idxA+range)
      zoomB = correlB.subarray(idxB-range, idxB+range)
      __frame.view zoomA, "zoomA"
      __frame.view zoomB, "zoomB"
      # 位置が一致するように微調整
      correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB)
      __frame.view correl, "correl"
            
      # 区間に分けて相関値を探索
      # パルス位置は上記の通りを一致させてあるので AとBの区間において相互相関[0] の位置の相関値を調べグラフ化
      zoom = zoomA.map (_, i)-> zoomA[i]*zoomB[i]
      logs = new Float32Array(zoom.length)
      windowsize = (0.6/SOUND_OF_SPEED*sampleRate)|0
      slidewidth = 1
      i = 0
      while zoomA.length > i + windowsize
        val = zoom.subarray(i, i + windowsize).reduce(((sum, v, i)-> sum + v), 0)
        logs[i] = val
        i += slidewidth
      __frame.view logs, "logs"
      _logs = Signal.lowpass(logs, sampleRate, 800, 1)
      __frame.view _logs, "logs(lowpass)"
      [max, _idx] = Signal.Statictics.findMax(_logs)
      i = 1
      i++ while i < _idx && _logs[i] < max/3
      i++ while i < _idx && _logs[i] > _logs[i-1]
      idx = i
      marker = new Uint8Array(logs.length)
      marker[idx] = 255
      __frame.view marker, "marker"
      max_offset = idx + (idxA - range)
      pulseTime = (startPtr + max_offset) / sampleRate
      {id: _id, max_offset, pulseTime}
    {id, alias, results: _results}
  sampleRates = datas.reduce(((o, {id, sampleRate})-> o[id] = sampleRate; o), {})
  recStartTimes = datas.reduce(((o, {id, recStartTime})-> o[id] = recStartTime; o), {})
  currentTimes = datas.reduce(((o, {id, currentTime})-> o[id] = currentTime; o), {})
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
      distances[id1][id2] = Math.abs(delayTimes[id1][id2])/2*SOUND_OF_SPEED
      distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {}
      distancesAliased[aliases[id1]][aliases[id2]] = distances[id1][id2]

  console.group("table")
  console.info("recStartTimes", recStartTimes)
  console.info("pulseTimesAliased");    console.table(pulseTimesAliased)
  console.info("relDelayTimesAliased"); console.table(relDelayTimesAliased)
  console.info("delayTimesAliased");    console.table(delayTimesAliased)
  console.info("distancesAliased");     console.table(distancesAliased)
  console.groupEnd()

  document.body.style.backgroundColor = "lime"
  TIME_DATA = {pulseTimes, delayTimes, aliases, recStartTimes, now, currentTimes, id: results[0].id, distances}
  next(TIME_DATA)


VIEW_SIZE = Math.pow(2, 12)
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
  fieldset.style.backgroundColor = "white"
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
    view: (arr, title="")->
      __frame = _craetePictureFrame title + "(#{arr.length})"
      width = if VIEW_SIZE < arr.length then VIEW_SIZE else arr.length
      render = new SignalViewer(width, 64)
      render.draw(arr)
      __frame.add render.cnv
      @add __frame.element
      @add document.createElement "br"
    text: (title)->
      @add document.createTextNode title
      @add document.createElement "br"
  }
