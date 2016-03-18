Recorder = window["Recorder"]
io    = window["io"]

window.navigator["getUserMedia"] = window.navigator.getUserMedia       ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.webkitGetUserMedia

actx     = null
socket   = null
recorder = null

setup = (next)->
  color = location.hash.slice(1)
  actx = new AudioContext()
  recorder = new Recorder(actx, color)
  recorder.prepareRec -> initSocket -> next()
  socket = io(location.hostname+":"+location.port+"/")
  window["actx"] = actx
  window["socket"] = socket
  do changeColor = ->
    console.log location.hash.slice(1)
    recorder.color = document.body.style.backgroundColor = location.hash.slice(1)
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

  socket.on "connect",         -> $("#socketId").html(socket.id); $("body").css({"background-color": location.hash.slice(1)}).append("<pre>connect:#{socket.id}</pre>")
  socket.on "reconnect",       -> $("#socketId").html(socket.id); $("body").css({"background-color": location.hash.slice(1)}).append("<pre>reconnect:#{socket.id}</pre>")
  socket.on "disconnect",      -> $("#socketId").html(socket.id); $("body").css({"background-color": "lightgray"}).append("<pre>disconnect</pre>")
  socket.on "error",      (err)-> console.error(err);             $("body").css({"background-color": "lightgray"}).append("<pre>error:#{err}</pre>")

  socket.on "ready",      (a)-> recorder.ready(a)      -> socket.emit("ready")
  socket.on "startRec",      -> recorder.startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> recorder.startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> recorder.beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> recorder.stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> recorder.stopRec       -> socket.emit("stopRec")
  socket.on "collect",    (a)-> recorder.collect(a) (a)-> socket.emit("collect", a)
  socket.on "distribute", (a)-> recorder.distribute(a) -> socket.emit("distribute")

  socket.on "play",       (a)-> recorder.play(a)
  socket.on "volume",     (a)-> recorder.volume(a)
  socket.on "reload",        -> location.reload()
  next()


window.addEventListener "DOMContentLoaded", -> setup -> main -> console.log "init main";
window.addEventListener "error", (ev)->
  err = ev.error
  console.error err
  if err instanceof Error
    pre = $("<pre />")
    .append("<br>"+err)
    .append("<br>"+err.message)
    .append("<br>"+err.stack)
  else if Object::toString.call(err) is "[object Object]"
    pre = $("<pre />")
    .append("<br>"+JSON.stringify(err))
  else
    pre = $("<pre />")
    .append("<br>"+err)
  $("body")
  .css({"background-color": "gray"})
  .append(pre)
