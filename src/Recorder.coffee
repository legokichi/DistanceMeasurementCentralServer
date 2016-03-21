RecordBuffer = window["duxca"]["lib"]["RecordBuffer"]
Wave         = window["duxca"]["lib"]["Wave"]
Detector     = window["Detector"]
JSZip        = window["JSZip"]

#__UPLOADER_POST_URL__ = "/php/upload.php"
__UPLOADER_POST_URL__ = "/upload"

__VIEW_SIZE__ = Math.pow(2, 12)

class this.Recorder
  constructor: (actx, color)->
    @actx        = actx
    @alias       = color
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
  collect: (data)-> (next)=>
    {experimentID, pulseType, timeStamp}  = data
    recStartTime = @recbuf.sampleTimes[0] - (@recbuf.bufferSize / @recbuf.sampleRate)
    recStopTime  = @recbuf.sampleTimes[@recbuf.sampleTimes.length-1]
    startStops   = Object.keys(@pulseStartTime).map (id)=>
      startPtr = (@pulseStartTime[id] - recStartTime) * @recbuf.sampleRate|0
      stopPtr  = (@pulseStopTime[id] - recStartTime) * @recbuf.sampleRate|0
      {id, startPtr, stopPtr}
    id          = socket.id
    alias       = @alias
    sampleRate  = @actx.sampleRate
    f32arr      = @recbuf.merge()
    int16arr    = @recbuf.toPCM()
    @recbuf.clear()
    @detector.calc(f32arr, startStops)
    .then (results)=>
      pulseInfos  = results.map ({pulseInfo})-> pulseInfo
      resObj      = {experimentID, pulseType, timeStamp, id, alias, sampleRate, recStartTime, recStopTime, startStops, pulseInfos}
      imageses    = results.map ({images})-> images
      @upload(resObj, f32arr, int16arr, imageses)
      .then -> next(resObj)
  upload: (resObj, f32arr, int16arr, imageses)->
    {experimentID, pulseType, timeStamp, id, alias, sampleRate, recStartTime, recStopTime, startStops, pulseInfos} = resObj
    json        = JSON.stringify(resObj, null, "  ")
    dat         = f32arr.buffer
    wave        = new Wave(1, sampleRate, int16arr).view.buffer
    prefix      = "#{experimentID}_#{pulseType}_#{timeStamp}_collect_#{alias}_#{id}"
    jszip = new JSZip()
    jszip.file("#{prefix}.json", json)
    jszip.file("#{prefix}.wav", wave)
    jszip.file("#{prefix}.dat", dat)
    Promise.all imageses.map (images)->
      Promise.all Object.keys(images).map (filename)->
        getSignalImage(images[filename]).then (blob)->
          blobToBuffer(blob).then (jpg)->
            jszip.file("#{prefix}_#{filename}.jpg", jpg)
    .then ->
      zip = jszip.generate({type:"blob", compressionOptions:9, })
      post(__UPLOADER_POST_URL__, {filename: "#{prefix}.zip",  file: zip})
    .catch (err)-> console.error(err)
  distribute: (data)-> (next)=>
    {experimentID, pulseType, timeStamp, datas} = data
    id      = socket.id
    alias   = @alias
    prefix  = "#{experimentID}_#{pulseType}_#{timeStamp}_distribute_#{alias}_#{id}"
    results = @detector.distribute(datas)
    json    = new Blob([JSON.stringify(results, null, "  ")])
    Promise.resolve()
    .then -> post(__UPLOADER_POST_URL__, {filename: "#{prefix}.json", file: json})
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



getSignalImage = (arr)->
  new Promise (resolve)->
    width = if __VIEW_SIZE__ < arr.length then __VIEW_SIZE__ else arr.length
    render = new SignalViewer(width, 64)
    render.draw(arr)
    render.cnv.toBlob(resolve, "image/jpeg", 0.5)


blobToBuffer = (blob)->
  new Promise (resolve, reject)->
    reader = new FileReader()
    reader.onerror = reject
    reader.onload = ->
      buffer = this.result
      resolve(buffer)
    reader.readAsArrayBuffer(blob)
