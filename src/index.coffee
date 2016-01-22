

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
  #_view.drawAuto = false
  _view.zoomY = 30
  _view.draw arr
  document.body.appendChild(_view.cnv)
n = (a)-> a.split("").map(Number)

# global var
actx = new AudioContext()
osc = new OSC(actx)
input_processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1)
input_processor.connect(actx.destination)

goldA = Signal.goldSeqGen(12, n("111000011001"), n("011110111111"), 0)
goldB = Signal.goldSeqGen(12, n("100101000001"), n("101101010111"), 3)
signalA = Signal.BPSK(goldA, 3000, 44100, 0, 44100)
signalB = Signal.BPSK(goldB, 3000, 44100, 0, 44100)
setTimeout ->
  view Signal.fft_smart_overwrap_correlation(signalA, signalA), 1024
  view Signal.fft_smart_overwrap_correlation(signalB, signalB), 1024
console.log abufA = osc.createAudioBufferFromArrayBuffer(signalA, 44100)
console.log abufB = osc.createAudioBufferFromArrayBuffer(signalB, 44100)
anodeA = osc.createAudioNodeFromAudioBuffer(abufA)
anodeB = osc.createAudioNodeFromAudioBuffer(abufB)
anodeA.connect(actx.destination)
anodeB.connect(actx.destination)
anodeA.start(actx.currentTime + 1)
anodeB.start(actx.currentTime + 4)

recbuf = new RecordBuffer(actx.sampleRate, input_processor.bufferSize, input_processor.channelCount)

input_processor.addEventListener "audioprocess", (ev)->
  buffer = ev.inputBuffer.getChannelData(0)
  recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
  if actx.currentTime > 10
    input_processor.disconnect()
    rawdata = recbuf.merge()
    view rawdata, 1024
    _signalA = Signal.BPSK(goldA, 3000, 44100, 0, rawdata.length)
    _signalB = Signal.BPSK(goldB, 3000, 44100, 0, rawdata.length)
    view Signal.fft_smart_overwrap_correlation(rawdata, _signalA), 1024
    view Signal.fft_smart_overwrap_correlation(rawdata, _signalB), 1024

left  = (err)-> throw err
right = (stream)->
  source = actx.createMediaStreamSource(stream)
  source.connect(input_processor)

navigator.getUserMedia({video: false, audio: true}, right, left)
