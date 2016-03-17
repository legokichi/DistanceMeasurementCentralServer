RecordBuffer = window["duxca"]["lib"]["RecordBuffer"]
Wave         = window["duxca"]["lib"]["Wave"]
Detector     = window["Detector"]

POST_URL = "/php/file_upload.php"
#POST_URL = "/push"

VIEW_SIZE = Math.pow(2, 12)

class this._Hoge
  constructor: (actx, color)->
    @actx        = actx
    @color       = color
    @isRecording = false
    @nextTick    = null
    @pulseStartTime = {}
    @pulseStopTime  = {}
    @processor   = @actx.createScriptProcessor(Math.pow(2, 14), 1, 1) # between Math.pow(2,8) and Math.pow(2,14).
    @processor.connect(@actx.destination)
    @processor.addEventListener("audioprocess", @audioprocess.bind(@))
    @gain        = @actx.createGain()
    @gain.connect(@actx.destination)
    @recbuf      = new RecordBuffer(@actx.sampleRate, @processor.bufferSize, @processor.channelCount)
    @detector    = new Detector(@actx)
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
  collect: (data)-> (next)=>
    {experimentID, timeStamp} = data
    id          = socket.id
    color       = @color
    startStops  = @getStartStops()
    f32arr      = @recbuf.merge()
    int16arr    = @recbuf.toPCM()
    @recbuf.clear()
    sampleRate  = @actx.sampleRate
    json        = new Blob([JSON.stringify({sampleRate, startStops})])
    dat         = new Blob([f32arr])
    wave        = new Wave(1, sampleRate, int16arr).toBlob()
    Promise.resolve()
    .then -> post(POST_URL, {filename: "#{experimentID}_#{timeStamp}_#{color}_#{id}.json", file: json})
    .then -> post(POST_URL, {filename: "#{experimentID}_#{timeStamp}_#{color}_#{id}.dat",  file: dat})
    .then -> post(POST_URL, {filename: "#{experimentID}_#{timeStamp}_#{color}_#{id}.wav",  file: wave})
    .catch (err)-> console.error(err); setTimeout -> throw err
    .then -> next()
  distribute: (data)-> (next)=>
    # data: [{id:string, results: [{id, max_offset, pulseTime, max_val}]}]
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



getSignalImage = (arr, cb)->
  new Promise (resolve)->
    width = if VIEW_SIZE < arr.length then VIEW_SIZE else arr.length
    render = new SignalViewer(width, 64)
    render.draw(arr)
    render.cnv.toBlob(resolve, "image/jpeg", 0.5)
