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
socket.on "connect",        -> socket.emit("echo", socket.id); socket.emit("colors")

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
  socket.on "colors", (datas)->
    points = datas.map ([id, color])->
      [Math.random()*(WIDTH-100)+50,
       Math.random()*(HEIGHT-100)+50,
       color, id]
  $("#colors").click -> socket.emit("colors")
  $("#play").click ->
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

    TIME_DATA = {wait, pulseTimes, delayTimes, id, currentTimes, recStartTimes, now, now2, volumes}
    socket.emit("play", TIME_DATA)

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

window.addEventListener "DOMContentLoaded", -> _processing -> main()
