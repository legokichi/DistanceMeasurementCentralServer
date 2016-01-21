# color state
changeColor = ->
  document.body.style.backgroundColor = location.hash.slice(1)
  socket.emit("colors")
window.addEventListener("DOMContentLoaded", changeColor)
window.addEventListener("hashchange", changeColor)

# sockets
window["socket"] = socket = io(location.hostname+":"+location.port+"/node")

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
gain = actx.createGain()
gain.connect(actx.destination)

# main
main = ->
  socket.on "color", (data)-> socket.emit("color", [socket.id, location.hash.slice(1)])
  socket.on "play", (data)-> play(data)
  socket.on "volume", (data)->
    gain.gain.value = data[socket.id]


# where
play = (data)->
  {wait, pulseTimes, delayTimes, id, currentTimes, recStartTimes, now, now2} = data
  # pulseTimes[socket.id][id] 自分がidの音を聞いた時刻
  # delayTimes[id][socket.id] 自分がidの音を聞いた時刻にidが実際に音を放っていた時間までの僅差
  offsetTime = recStartTimes[socket.id] + (
    pulseTimes[socket.id][id] - delayTimes[socket.id][id]
  ) + (
    currentTimes[id] - (pulseTimes[id][id] + recStartTimes[id])
  ) + (now2 - now)/1000 + wait
  osc.createAudioBufferFromURL("./TellYourWorld1min.mp3").then (abuf)->
    node = osc.createAudioNodeFromAudioBuffer(abuf)
    node.start(offsetTime+1)
    node.loop = false
    node.connect(gain)


window.addEventListener "DOMContentLoaded", ->  main()
