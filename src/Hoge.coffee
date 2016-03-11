RecordBuffer = window["RecordBuffer"]
Detector = window["Detector"]

class this._Hoge
  constructor: (actx)->
    @actx = actx
    @isRecording = false
    @nextTick = null
    @pulseStartTime = {}
    @pulseStopTime  = {}
    @processor = @actx.createScriptProcessor(Math.pow(2, 14), 1, 1); # between Math.pow(2,8) and Math.pow(2,14).
    @processor.connect(@actx.destination)
    @processor.addEventListener("audioprocess", @audioprocess.bind(@))
    @gain = @actx.createGain()
    @gain.connect(@actx.destination)
    @recbuf = new RecordBuffer(@actx.sampleRate, @processor.bufferSize, @processor.channelCount)
    @detector = new Detector(@actx)
  audioprocess: (ev)->
    if @isRecording
      @recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], @actx.currentTime)
    if @nextTick instanceof Function
      fn = @nextTick
      @nextTick = null
      fn()
  prepareRec: (next)->
    left  = (err)-> throw err
    right = (stream)=>
      source = @actx.createMediaStreamSource(stream)
      source.connect(@processor)
      next()
    navigator.getUserMedia({video: false, audio: true}, right, left)
  ready: (data)-> (next)=>
    @detector.init(data, next)
  startRec: (next)->
    @isRecording = true
    next()
  startPulse: (id)-> (next)=>
    @pulseStartTime[id] = @actx.currentTime
    next()
  beepPulse: (next)->
    @detector.beep(next)
  stopPulse: (id)-> (next)=>
    @nextTick = =>
      @pulseStopTime[id] = @actx.currentTime
      next()
  stopRec: (next)->
    @isRecording = false
    setTimeout(@calc.bind(@), 0)
    next()
  calc: ->
    f32arr = @recbuf.merge()
    recStartTime = @recbuf.sampleTimes[0] - (@recbuf.bufferSize / @recbuf.sampleRate)
    recStopTime = @recbuf.sampleTimes[@recbuf.sampleTimes.length-1]
    startStops = Object.keys(@pulseStartTime).map (id)=>
      startPtr = (@pulseStartTime[id] - recStartTime) * @recbuf.sampleRate|0
      stopPtr = (@pulseStopTime[id] - recStartTime) * @recbuf.sampleRate|0
      {id, startPtr, stopPtr}
    @recbuf.clear()
    @detector.calc(f32arr, startStops)

  collect: (next)-> next()
  distribute: (next)-> next()
  play: (data)-> console.log "play", data
  volume: (data)-> console.log "volume", data
