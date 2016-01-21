

# setup
window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

# sockets
window["socket"] = socket = io(location.hostname+":"+location.port)

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
socket.on "connect",        -> socket.emit("echo", "hello")

# util
this.view = (arr,w=arr.length,h=128)->
  _view = new SignalViewer(w, h)
  _view.draw arr
  document.body.appendChild(_view.cnv)
n = (a)-> a.split("").map(Number)

# global var
actx = new AudioContext()
osc = new OSC(actx)


# pn
pn = new Float32Array(Signal.mseqGen(11, n("01001001001")))
tse = new TimeSpreadEcho(actx, kernel)
tse.processor.connect(actx.destination)

osc.createAudioBufferFromURL("TellYourWorld1min.mp3").then (abuf)->
  anode = osc.createAudioNodeFromAudioBuffer(abuf)
  anode.connect(tse.processor)
  anode.start(actx.currentTime)
