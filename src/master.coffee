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
socket.on "echo",              console.info.bind(console, "echo")
socket.on "connect",        -> socket.emit("colors")

WIDTH = 400
HEIGHT = 400
RULED_LINE_INTERVAL = 50
MULTIPASS_DISTANCE = 5
SOUND_OF_SPEED = 340
VIEW_SIZE = Math.pow(2, 12)
TIME_DATA = null
VS = [0, 0, "VS"]
points = []

main = ->
  socket.on "calc", (a)-> calc(a) -> socket.emit("calc")
  socket.on "colors", (datas)->
    console.log datas
    points = datas.map ({id, color})->
      [Math.random()*(WIDTH-100)+50, Math.random()*(HEIGHT-100)+50, color, id]
  $("#start").click ->
    document.body.style.backgroundColor = "white"
    socket.emit("start")
  $("#colors").click -> socket.emit("colors")
  $("#play").click ->
    unless TIME_DATA? then return
    TIME_DATA.wait = 4
    TIME_DATA.now2 = Date.now()
    console.log "TIME_DATA", TIME_DATA
    socket.emit("play", TIME_DATA)
  $("#status").click ->
    wait = 0
    distances = points.reduce(((o, [x, y, color1, id1], i)->
      o[id1] = points.reduce(((o, [_x, _y, color2, id2], j)->
        o[id2] = Math.sqrt(Math.pow(x - _x, 2) + Math.pow(y - _y, 2));
        o), {}); o), {})
    delayTimes = points.reduce(((o, [x, y, color1, id1], i)->
      o[id1] = points.reduce(((o, [_x, _y, color2, id2], j)->
        o[id2] = distances[id1][id2]*2/SOUND_OF_SPEED
        o), {}); o), {})
    pulseTimes = points.reduce(((o, [x, y, color1, id1], i)->
      o[id1] = points.reduce(((o, [_x, _y, color2, id2], j)->
        if i is j
        then o[id2] = 0
        else o[id2] = 1
        o), {}); o), {})
    recStartTimes = points.reduce(((o, [x, y, color1, id1], i)-> o[id1] = 0; o), {})
    currentTimes = points.reduce(((o, [x, y, color1, id1], i)-> o[id1] = 2; o), {})
    distancesVS = points.map (point)->
      [x, y] = point
      [_x, _y] = VS
      Math.sqrt(Math.pow(x - _x, 2) + Math.pow(y - _y, 2))
    R = 6
    a = R/(20*Math.log10(2))
    sum = distancesVS.reduce(((a, d)-> a+1/Math.pow(d, 2 * a)), 0)
    k = 1/ Math.sqrt(sum)
    _volumes = distancesVS.map (d)-> k / Math.pow(d, a)
    volumes = points.reduce(((o, [x, y, color1, id1], i)-> o[id1] = _volumes[i]; o), {})
    now = Date.now()
    now2 = Date.now()
    id = points[0][3]

    aliases = points.reduce(((o, [x, y, color1, id1])-> o[id1] = color1; o), {})
    distancesAliased = points.reduce(((o, [x, y, color1, id1], i)->
      o[aliases[id1]] = points.reduce(((o, [_x, _y, color2, id2], j)->
        o[aliases[id2]] = distances[id1][id2]
        o), {}); o), {})
    delayTimesAliased = points.reduce(((o, [x, y, color1, id1], i)->
      o[aliases[id1]] = points.reduce(((o, [_x, _y, color2, id2], j)->
        o[aliases[id2]] = delayTimes[id1][id2]
        o), {}); o), {})
    pulseTimesAliased = points.reduce(((o, [x, y, color1, id1], i)->
      o[aliases[id1]] = points.reduce(((o, [_x, _y, color2, id2], j)->
        o[aliases[id2]] = pulseTimes[id1][id2]
        o), {}); o), {})

    console.info("pulseTimesAliased");    console.table(pulseTimesAliased)
    console.info("delayTimesAliased");    console.table(delayTimesAliased)
    console.info("distancesAliased");     console.table(distancesAliased)



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
        [_, idx] = Signal.Statictics.findMax(correlA.subarray(relA-range, relA+range))
        idxA = relA - range + idx
      else
        # Aが正しいのでBを修正
        [_, idx] = Signal.Statictics.findMax(correlB.subarray(relB-range, relB+range))
        idxB = relB - range + idx
      marker = new Uint8Array(correlA.length)
      marker[idxA] = 255
      marker[idxB] = 255
      __frame.view marker,"marker"
      zoomA = correlA.subarray(idxA-range, idxA+range)
      zoomB = correlB.subarray(idxB-range, idxB+range)
      correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB)
      __frame.view zoomA,"zoomA"
      __frame.view zoomB,"zoomB"
      __frame.view correl,"correl"
      [max, idx] = Signal.Statictics.findMax(correl)
      i = 0
      idxs = new Uint16Array(zoomB.length)
      maxs = new Float32Array(zoomB.length)
      prevIdx = idx
      searchRange = 128
      while i < zoomB.length*3/4
        zoomB = correlB.subarray(i+idxB-range, i+idxB+range)
        correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB)
        begin = prevIdx - searchRange; if begin < 0 then 0 else begin
        [max, idx] = Signal.Statictics.findMax(correl.subarray(begin, prevIdx + searchRange))
        idxs[i] = begin + idx
        maxs[i] = max
        prevIdx = begin + idx
        i += 10
      __frame.view idxs,"idxs"
      __frame.view maxs,"maxs"
      [_, idx] = Signal.Statictics.findMax(maxs)
      marker = new Uint8Array(zoomB.length)
      marker[idx] = 255
      __frame.view marker,"marker"
      max_offset = idx + idxB - range
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
  pseudoPts = results.map(({id1}, i)-> new Point(Math.random()*10, Math.random()*10))
  sdm = new SDM(pseudoPts, ds)
  K = 0
  while K++ < 200
    sdm.step()
  #console.info("calcRelPos", sdm.det())
  #console.table(sdm.points)
  # relpos
  basePt = sdm.points[0]
  points = sdm.points.map (pt, i)->
    [WIDTH/2+(pt.x-basePt.x)*50, HEIGHT/2+(pt.y-basePt.y)*50, results.map(({alias}, i)->alias)[i], results.map(({id}, i)->id)[i]]

  document.body.style.backgroundColor = "lime"
  TIME_DATA = {pulseTimes, delayTimes, aliases, recStartTimes, now, currentTimes, id: results[0].id}
  next()



_processing = (next)->
  drgTrgPtr = null
  new Processing $("#_cnv_")[0], (_)->
    _.mousePressed = ->
      for point,i in [].concat([VS], points)
        [x, y] = point
        if Math.abs(x - _.mouseX) < 25 and Math.abs(y - _.mouseY) < 25
          drgTrgPtr = point
          break
    _.mouseReleased = -> drgTrgPtr = null
    _.setup = ->
      _.size(WIDTH, HEIGHT)
      VS = [50, 50, "VS", "VS"]
    _.draw = ->
      if drgTrgPtr?
        drgTrgPtr[0] = _.mouseX
        drgTrgPtr[1] = _.mouseY
        distancesVS = points.map (point)->
          [x, y] = point
          [_x, _y] = VS
          Math.sqrt(Math.pow(x - _x, 2) + Math.pow(y - _y, 2))
        R = 6
        a = R/(20*Math.log10(2))
        sum = distancesVS.reduce(((a, d)-> a+1/Math.pow(d, 2 * a)), 0)
        k = 1/ Math.sqrt(sum)
        _volumes = distancesVS.map (d)-> k / Math.pow(d, a)
        volumes = points.reduce(((o, [x, y, color1, id1], i)-> o[id1] = _volumes[i]; o), {})
        socket.emit("volume", volumes)
      _.background(255)
      # 罫線
      _.stroke(127)
      _.line(0, i, _.width, i)  for i in [RULED_LINE_INTERVAL.._.width] by RULED_LINE_INTERVAL
      _.line(i, 0, i, _.height) for i in [RULED_LINE_INTERVAL.._.height] by RULED_LINE_INTERVAL
      _.stroke(0)
      # 相対線
      for point, i in points
        [x, y] = point
        for j in [i...points.length] when i != j
          [_x, _y] = points[j]
          _.line(x, y, _x, _y)
          __x = ((x - _x)/2)+_x
          __y = ((y - _y)/2)+_y
          __l = Math.sqrt(
                          Math.pow(x - _x, 2) +
                          Math.pow(y - _y, 2))
          _.text((__l/RULED_LINE_INTERVAL*100 | 0)/100, __x, __y)
      # 丸
      for point, i in points
        [x, y, name, id] = point
        _.fill(255)
        _.ellipse(x, y, 25, 25)
        _.fill(0)
        _.text(name, x+10, y-10)
        _.text("#{x|0}, #{y|0}", x+10, y+10)
      # VS
      [x, y, name] = VS
      _.fill(128)
      _.ellipse(x, y, 25, 25)
      _.fill(0)
      _.text(name, x-3, y+5)
      _.text("#{x|0}, #{y|0}", x+10, y+10)
      return
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
    view: (arr, title)->
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

window.addEventListener "DOMContentLoaded", -> _processing -> main()
