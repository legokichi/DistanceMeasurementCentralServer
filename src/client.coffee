setup = ->
  window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                     window.navigator.mozGetUserMedia    ||
                                     window.navigator.getUserMedia

  # color state
  changeColor = -> document.body.style.backgroundColor = location.hash.slice(1)
  window.addEventListener("DOMContentLoaded", changeColor)
  window.addEventListener("hashchange", changeColor)

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

  # error logger
  window.onerror = (err)->
    console.error(err)
    document.body.style.backgroundColor = "gray"
    pre = document.createElement("pre")
    textnode = document.createTextNode(err.stack || err)
    pre.appendChild textnode
    document.body.appendChild pre

# let
actx = new AudioContext()
osc = new OSC(actx)
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1); # between Math.pow(2,8) and Math.pow(2,14).
recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)
isRecording    = false
pulseStartTime = {}
pulseStopTime  = {}
pulse = null
abuf = null

main = ->
  # user event
  socket.on "ready",         -> ready         -> socket.emit("ready")
  socket.on "startRec",      -> startRec      -> socket.emit("startRec")
  socket.on "startPulse", (a)-> startPulse(a) -> socket.emit("startPulse")
  socket.on "beepPulse",     -> beepPulse     -> socket.emit("beepPulse")
  socket.on "stopPulse",  (a)-> stopPulse(a)  -> socket.emit("stopPulse")
  socket.on "stopRec",       -> stopRec       -> socket.emit("stopRec")
  socket.on "sendRec",       -> sendRec    (a)-> socket.emit("sendRec", a)

  # main proc
  ready      = (next)-> _preparePulse -> _prepareRec -> next()
  startRec   = _flipProc -> isRecording = true
  startPulse = (id)-> _flipProc -> pulseStartTime[id] = actx.currentTime
  beepPulse  = _beep
  stopPulse  = (id)-> _flipProc -> pulseStopTime[id] = actx.currentTime
  stopRec    = _flipProc -> isRecording = false
  sendRec    = (next)->
    f32arr = recbuf.merge()
    console.log f32arr
    o =
      id: socket.id
      alias: location.hash.slice(1)
      pulseStartTime: pulseStartTime
      pulseStopTime: pulseStopTime
      sampleTimes: recbuf.sampleTimes
      sampleRate: actx.sampleRate
      bufferSize: processor.bufferSize
      channelCount: processor.channelCount
      recF32arr: f32arr.buffer
      recF32arrLen: f32arr.length
      pulseF32arr: pulse.buffer
      pulseF32arrLen: pulse.length
    recbuf.clear()
    next(o)

# where
_preparePulse = (next)->
  osc.createBarkerCodedChirp(13, 8).then (_pulse)->
    pulse = _pulse
    abuf = osc.createAudioBufferFromArrayBuffer(pulse, actx.sampleRate)
    next()
_prepareRec = (next)->
  left  = (err)-> throw err
  right = (stream)->
    source = actx.createMediaStreamSource(stream)
    source.connect(processor)
    processor.connect(actx.destination)
    processor.addEventListener "audioprocess", (ev)->
      if(isRecording)
        recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
    next()
  navigator.getUserMedia({video: false, audio: true}, right, left)
_beep = (next)->
  anode = osc.createAudioNodeFromAudioBuffer(abuf)
  anode.connect(actx.destination)
  anode.start(actx.currentTime)
  setTimeout(next, pulse.length/actx.sampleRate * 1000)
_flipProc = (next)-> (proc)-> proc(); next()
_merge = (base, overwrite)->
  Object.keys(overwrite).forEach (key)-> base[key] = overwrite[key]
  base

setup()
main()
