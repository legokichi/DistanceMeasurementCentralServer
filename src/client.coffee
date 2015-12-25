window["socket"] = socket = io("localhost:8000")
socket.on "connect", console.info.bind(console, "connect")
socket.on "reconnect", console.info.bind(console, "reconnect")
socket.on "reconnect_attempt", console.info.bind(console, "reconnect_attempt")
socket.on "reconnecting", console.info.bind(console, "reconnecting")
socket.on "reconnect_error", console.info.bind(console, "reconnect_error")
socket.on "reconnect_failed", console.info.bind(console, "reconnect_failed")
socket.on "disconnect", console.info.bind(console, "disconnect")
socket.on "error", console.info.bind(console, "error")
socket.on "echo", console.info.bind(console, "echo")
socket.on "connect", ->
  socket.emit("echo", "hello")

socket.on "ready",      -> socket.emit("ready")
socket.on "startRec",   -> socket.emit("startRec")
socket.on "startPulse", -> socket.emit("startPulse")
socket.on "beepPulse",  -> socket.emit("beepPulse")
socket.on "stopPulse",  -> socket.emit("stopPulse")
socket.on "stopRec",    -> socket.emit("stopRec")
socket.on "sendRec",    -> socket.emit("sendRec", {alias: location.hash.slice(1), id: socket.id, f32arr: new ArrayBuffer(1024)})

window.getSockets = ->
  $.getJSON("../api/sockets").then(console.log.bind(console))
  $.getJSON("../api/sockets")

changeColor = ->
  document.body.style.backgroundColor = location.hash.slice(1)

window.addEventListener("DOMContentLoaded", changeColor)
window.addEventListener("hashchange", changeColor)

window.onerror = (err)->
  console.dir(err)
  document.body.style.backgroundColor = "gray"
