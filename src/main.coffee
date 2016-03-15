_Hoge = window["_Hoge"]
io    = window["io"]

window.navigator["getUserMedia"] = window.navigator.getUserMedia       ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.webkitGetUserMedia

actx = null
socket = null
_hoge = null

setup = (next)->
  color = location.hash.slice(1)
  actx = new AudioContext()
  _hoge = new _Hoge(actx, color)
  _hoge.prepareRec -> initSocket -> next()
  socket = io(location.hostname+":"+location.port+"/")
  window["actx"] = actx
  window["socket"] = socket
  do changeColor = ->
    _hoge.color = document.body.style.backgroundColor = location.hash.slice(1)
  window.addEventListener "hashchange", changeColor

main = (next)->
  next()

initSocket = (next)->
  socket.on "connect",           console.info.bind(console, "connect")
  socket.on "reconnect",         console.info.bind(console, "reconnect")
  socket.on "reconnect_attempt", console.info.bind(console, "reconnect_attempt")
  socket.on "reconnecting",      console.info.bind(console, "reconnecting")
  socket.on "reconnect_error",   console.info.bind(console, "reconnect_error")
  socket.on "reconnect_failed",  console.info.bind(console, "reconnect_failed")
  socket.on "disconnect",        console.info.bind(console, "disconnect")
  socket.on "error",             console.info.bind(console, "error")

  socket.on "connect", -> $("#socketId").html socket.id

  socket.on "ready",      (a)-> _hoge.ready(a)      -> socket.emit("ready")
  socket.on "startRec",      -> _hoge.startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> _hoge.startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> _hoge.beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> _hoge.stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> _hoge.stopRec       -> socket.emit("stopRec")
  socket.on "collect",       -> _hoge.collect    (a)-> socket.emit("collect", a)
  socket.on "distribute", (a)-> _hoge.distribute(a) -> socket.emit("distribute")
  socket.on "collectRec",    -> _hoge.collectRec (a)-> socket.emit("collectRec", a)

  socket.on "play",       (a)-> _hoge.play(a)
  socket.on "volume",     (a)-> _hoge.volume(a)
  socket.on "reload",        -> location.reload()
  next()


window.addEventListener "DOMContentLoaded", -> setup -> main -> console.log "init main"
