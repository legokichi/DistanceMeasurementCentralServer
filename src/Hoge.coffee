RecordBuffer = window["duxca"]["lib"]["RecordBuffer"]
Wave         = window["duxca"]["lib"]["Wave"]
Detector     = window["Detector"]

POST_URL = "/php/file_upload.php"

class this._Hoge
  constructor: (actx, color)->
    @actx = actx
    @color = color
    @isRecording = false
    @nextTick = null
    @pulseStartTime = {}
    @pulseStopTime  = {}
    @processor = @actx.createScriptProcessor(Math.pow(2, 14), 1, 1) # between Math.pow(2,8) and Math.pow(2,14).
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
    @recbuf.clear()
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
    next()
  getStartStops: ->
    recStartTime = @recbuf.sampleTimes[0] - (@recbuf.bufferSize / @recbuf.sampleRate)
    recStopTime = @recbuf.sampleTimes[@recbuf.sampleTimes.length-1]
    startStops = Object.keys(@pulseStartTime).map (id)=>
      startPtr = (@pulseStartTime[id] - recStartTime) * @recbuf.sampleRate|0
      stopPtr = (@pulseStopTime[id] - recStartTime) * @recbuf.sampleRate|0
      {id, startPtr, stopPtr}
    startStops
  collectRec: (data)-> (next)=>
    {experimentID, timeStamp} = data
    startStops = @getStartStops()
    int16arr = @recbuf.toPCM()
    sampleRate = @actx.sampleRate
    wave = new Wave(1, sampleRate, int16arr).toBlob()
    json = new Blob([JSON.stringify({sampleRate, startStops})])
    Promise.all([
      post(POST_URL, {filename: "#{experimentID}_#{timeStamp}_#{@color}_#{socket.id}.wav",  file: wave})
      post(POST_URL, {filename: "#{experimentID}_#{timeStamp}_#{@color}_#{socket.id}.json", file: json})
    ]).then(next).catch (err)-> console.error(err); throw err
  collect: (next)->
    startStops = @getStartStops()
    f32arr = @recbuf.merge()
    results = @detector.calc(f32arr, startStops)
    @recbuf.clear()
    next({id: socket.id, color: @color, results})
  distribute: (data)=> (next)->
    # data: [{id:string, results: [{id, max_offset, pulseTime, max_val}]}]
    data.forEach ({id, results})->
      console.group(id)
      console.log(id)
      console.table(results)
      console.groupEnd(id)
    next()
  play: (data)-> console.log "play", data
  volume: (data)-> console.log "volume", data

post = (url, param)->
  formData = new FormData()
  Object.keys(param).forEach (key)-> formData.append(key, param[key])
  return $.ajax({
    type: 'POST',
    url: url,
    data: formData,
    contentType: false,
    processData: false
  }).promise()
