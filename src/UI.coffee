# sockets
window["socket"] = socket = io(location.hostname+":"+location.port+"/ui")

# middleware event
socket.on "connect",           console.info.bind(console, "connect")
socket.on "reconnect",         console.info.bind(console, "reconnect")
socket.on "reconnect_attempt", console.info.bind(console, "reconnect_attempt")
socket.on "reconnecting",      console.info.bind(console, "reconnecting")
socket.on "reconnect_error",   console.info.bind(console, "reconnect_error")
socket.on "reconnect_failed",  console.info.bind(console, "reconnect_failed")
socket.on "disconnect",        console.info.bind(console, "disconnect")
socket.on "error",             console.info.bind(console, "error")

WIDTH = 400
HEIGHT = 400
RULED_LINE_INTERVAL = 50
VS = [0, 0, "VS"]
points = []
drgTrgPtr = null
TIME_DATA = null

socket.on "connect",        -> socket.emit("colors")
socket.on "colors",  (datas)-> points = datas.map ({id, color})-> [Math.random()*(WIDTH-100)+50, Math.random()*(HEIGHT-100)+50, color, id]
socket.on "repos",   (_TIME_DATA)->
  console.log "repos", _TIME_DATA
  TIME_DATA = _TIME_DATA
  {pulseTimes, delayTimes, aliases, recStartTimes, now, currentTimes, distances, max_vals} = TIME_DATA
  ds = Object.keys(delayTimes).map (id1)->
    Object.keys(delayTimes).map (id2)->
      distances[id1][id2]
  ids = Object.keys(recStartTimes)
  pseudoPts = ids.map((id, i)-> new Point(Math.random()*10, Math.random()*10))
  sdm = new SDM(pseudoPts, ds)
  K = 0
  sdm.step() while K++ < 200
  console.info("calcRelPos", sdm.det())
  console.table(sdm.points)
  # relpos
  basePt = sdm.points[0]
  points = sdm.points.map (pt, i)->
    [WIDTH/2+(pt.x-basePt.x)*50, HEIGHT/2+(pt.y-basePt.y)*50, aliases[ids[i]], ids[i]]

$ ->
  $("#start").click ->  socket.emit("start"); document.body.style.backgroundColor = "white"
  $("#colors").click -> socket.emit("colors")
  $("#play").click ->
    unless TIME_DATA? then return
    TIME_DATA.wait = 4
    TIME_DATA.now2 = Date.now()
    console.log "TIME_DATA", TIME_DATA
    socket.emit("play", TIME_DATA)

  new Processing($("#_cnv_")[0], main)

main = (_)->
  _.mousePressed = ->
    for point,i in [].concat([VS], points)
      [x, y] = point
      if Math.abs(x - _.mouseX) < 25 and Math.abs(y - _.mouseY) < 25
        drgTrgPtr = point
        break
    return
  _.mouseReleased = -> drgTrgPtr = null
  _.setup = ->
    _.size(WIDTH, HEIGHT)
    VS = [50, 50, "VS", "VS"]
    return
  _.draw = ->
    if drgTrgPtr?
      drgTrgPtr[0] = _.mouseX
      drgTrgPtr[1] = _.mouseY
      distancesVS = points.map (point)->
        [x, y] = point
        [_x, _y] = VS
        Math.sqrt(Math.pow(x - _x, 2) + Math.pow(y - _y, 2))
      R = 3
      a = R/(20*Math.log10(2))
      sum = distancesVS.reduce(((a, d)-> a+1/Math.pow(d, 2 * a)), 0)
      k = 1/ Math.sqrt(sum)
      _volumes = distancesVS.map (d)-> k / Math.pow(d, a)
      volumes = points.reduce(((o, [x, y, color1, id1], i)-> o[id1] = _volumes[i]; o), {})
      _id = null # base volume device id
      _val = Infinity
      Object.keys(volumes).forEach (id1)->
        Object.keys(volumes).forEach (id2)->
          if id1 is id2 then return
          if TIME_DATA.max_vals[id1][id2] < _val
            _val = TIME_DATA.max_vals[id1][id2]
            _id = id2
      id0 = _id
      Object.keys(volumes).forEach (id1)->
        if id0 is null then return
        if id1 is id0 then return
        weight = 0
        i = 0
        Object.keys(volumes).forEach (id2)->
          if id2 is id0 then return
          if id1 is id2 then return
          i++
          weight += (TIME_DATA.max_vals[id1][id2] * TIME_DATA.distances[id1][id2]) / (TIME_DATA.max_vals[id0][id2] * TIME_DATA.distances[id0][id2])
        console.log id0, id1, weight, i
        volumes[id1] *= weight/i
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
  return
