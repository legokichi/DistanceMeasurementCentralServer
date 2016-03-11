window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

socket = null
_hoge = null

setup = (next)->
  id = location.hash.slice(1)
  actx = new AudioContext()
  _hoge = new _Hoge(actx)
  _hoge.prepareRec -> initSocket -> next()

main = (next)->
  next()

initSocket = (next)->
  window["socket"] = socket = io(location.hostname+":"+location.port+"/")
  socket.on "connect",           console.info.bind(console, "connect")
  socket.on "reconnect",         console.info.bind(console, "reconnect")
  socket.on "reconnect_attempt", console.info.bind(console, "reconnect_attempt")
  socket.on "reconnecting",      console.info.bind(console, "reconnecting")
  socket.on "reconnect_error",   console.info.bind(console, "reconnect_error")
  socket.on "reconnect_failed",  console.info.bind(console, "reconnect_failed")
  socket.on "disconnect",        console.info.bind(console, "disconnect")
  socket.on "error",             console.info.bind(console, "error")

  socket.on "ready",      (a)-> _hoge.ready(a)      -> socket.emit("ready")
  socket.on "startRec",      -> _hoge.startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> _hoge.startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> _hoge.beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> _hoge.stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> _hoge.stopRec       -> socket.emit("stopRec")
  socket.on "collect",       -> _hoge.collect    (a)-> socket.emit("collect", a)
  socket.on "distribute", (a)-> _hoge.distribute (a)-> socket.emit("distribute")

  socket.on "play",       (a)-> _hoge.play(a)
  socket.on "volume",     (a)-> _hoge.volume(a)
  socket.on "reload",        -> location.reload()
  next()


changeColor = -> document.body.style.backgroundColor = location.hash.slice(1)

window.addEventListener "DOMContentLoaded", -> setup -> main -> changeColor()
window.addEventListener("hashchange", changeColor)
