

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
processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1)
processor.connect(actx.destination)

freq = 2205
mseqA = Signal.mseqGen(12, n("111000011001"))
mseqB = Signal.mseqGen(12, n("101101010111"))
matchedA = Signal.BPSK(mseqA, freq, actx.sampleRate, 0)
matchedB = Signal.BPSK(mseqB, freq, actx.sampleRate, 0)
signal = new Float32Array(matchedA.length*2 + matchedB.length)
signal.set(matchedA, 0)
signal.set(matchedB, matchedA.length*2)
console.log abuf = osc.createAudioBufferFromArrayBuffer(signal, actx.sampleRate)
anode = osc.createAudioNodeFromAudioBuffer(abuf)
anode.connect(actx.destination)
anode.start(actx.currentTime+1)

recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount)

processor.addEventListener "audioprocess", (ev)->
  recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime)
  if actx.currentTime > abuf.duration+1
    processor.disconnect()
    rawdata = recbuf.merge()
    view rawdata, 1024
    correlA = Signal.fft_smart_overwrap_correlation(rawdata, matchedA)
    correlB = Signal.fft_smart_overwrap_correlation(rawdata, matchedB)
    view correlA, 1023
    view correlB, 1023
    [maxA, idxA] = Signal.Statictics.findMax(correlA)
    [maxB, idxB] = Signal.Statictics.findMax(correlB)
    console.log idxB, relB = idxA+matchedA.length*2
    console.log idxA, relA = idxB-matchedA.length*2
    if correlB[relB] + maxA > correlA[relA] + maxB
      # Aが正しいのでAを修正
      idxB = relB
      maxB = correlB[idxB]
    else
      # Bが正しいのでAを修正
      idxA = relA
      maxA = correlA[idxA]
    marker = new Uint8Array(correlA.length)
    marker[idxA] = 255
    marker[idxB] = 255
    view marker, 1024
    range = 5/340*actx.sampleRate|0
    view zoomA = correlA.subarray(idxA-range, idxA+range)
    view zoomB = correlB.subarray(idxB-range, idxB+range)
    i = 0
    idxs = new Uint16Array(zoomB.length)
    maxs = new Float32Array(zoomB.length)
    prevIdx = 0
    searchRange = 128
    do recur = ->
      if i > zoomB.length
        view idxs
        view maxs
        return
      correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB.subarray(i, zoomB.length))
      begin = if i - searchRange < 0 then 0 else i - searchRange
      [max, idx] = Signal.Statictics.findMax(correl.subarray(begin, i + searchRange))
      idxs[i] = begin + idx
      maxs[i] = max
      i += 10
      setTimeout recur





left  = (err)-> throw err
right = (stream)->
  source = actx.createMediaStreamSource(stream)
  source.connect(processor)

navigator.getUserMedia({video: false, audio: true}, right, left)
