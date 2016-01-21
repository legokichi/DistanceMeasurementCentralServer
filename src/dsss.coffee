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
actx = new AudioContext()
osc = new OSC(actx)
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1)
recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
osc.createAudioBufferFromURL("TellYourWorld1min.mp3").then (abuf)->
  console.log abuf
  console.log anode = osc.createAudioNodeFromAudioBuffer(abuf);
  anode.connect(processor)
  processor.connect(this.actx.destination)
  processor.addEventListener "audioprocess", handler=(ev)->
    buf = ev.inputBuffer.getChannelData(0)
    ev.outputBuffer.getChannelData(0).set(buf, 0)
    recbuf.add([new Float32Array(buf)], actx.currentTime)
    console.log "rec.", recbuf.count*recbuf.bufferSize/actx.sampleRate, abuf.duration
    if(recbuf.count*recbuf.bufferSize/actx.sampleRate > abuf.duration)
      console.log "fin."
      processor.removeEventListener("audioprocess", handler)
      processor.disconnect()
      console.log rawdata = recbuf.merge()
      recbuf.clear()
  anode.start(this.actx.currentTime)
