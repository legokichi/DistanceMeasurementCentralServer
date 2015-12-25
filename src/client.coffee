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


window.getSockets = ->
  # $.getJSON("../api/sockets").then(console.log.bind(console))
  $.getJSON("../api/sockets")
