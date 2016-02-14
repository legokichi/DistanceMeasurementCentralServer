import RecordBuffer = require("./RecordBuffer");

class Sync {
  actx: AudioContext;
  isRecording: boolean;
  recbuf: RecordBuffer;
  pulseStartTime: {[id: string]: number};
  pulseStopTime: {[id: string]: number};
  DSSS_SPEC: any
  __nextTick__: any;
  constructor(actx: AudioContext){
    this.actx = actx;
    this.isRecording = false
    this.recbuf = null
    this.pulseStartTime = {}
    this.pulseStopTime  = {}
    this.DSSS_SPEC = null
    this.__nextTick__ = null
  }

}
/*
  constructor: (@actx)->
    @isRecording = false
    @recbuf = null
    @pulseStartTime = {}
    @pulseStopTime  = {}
    @DSSS_SPEC = null
    @__nextTick__ = null
    @processor = @actx.createScriptProcessor(Math.pow(2, 14), 1, 1)
    @processor.connect(@actx.destination)
    @processor.addEventListener "audioprocess", (ev)=>
      if @isRecording
        @recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], @actx.currentTime)
      if @__nextTick__?
        fn = @__nextTick__
        @__nextTick__ = null
        fn()
  prepareRec: (next)->
    left  = (err)-> throw err
    right = (stream)=>
      source = actx.createMediaStreamSource(stream)
      source.connect(@processor)
      next()
    navigator.getUserMedia({video: false, audio: true}, right, left)
  startRec: (next)->
    @isRecording = true
    @__nextTick__ = next
  startPulse: (id, next)->
    pulseStartTime[id] = actx.currentTime
    setTimeout next
  beepPulse: (next)->
    {abuf} = DSSS_SPEC
    startTime = actx.currentTime
    anode = osc.createAudioNodeFromAudioBuffer(abuf)
    anode.connect(actx.destination)
    anode.start(startTime)
    do recur = ->
      if (startTime + abuf.duration) < actx.currentTime
      then setTimeout(next, 100)
      else setTimeout(recur, 100)
  stopPulse: (next)->
  stopRec: (next)->
  sendRec: (next)->
    f32arr = @recbuf.merge()
    recStartTime = recbuf.sampleTimes[0] - (recbuf.bufferSize / recbuf.sampleRate)
    recStopTime = recbuf.sampleTimes[recbuf.sampleTimes.length-1]
    startStops = Object.keys(pulseStartTime).map (id)->
      startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate|0
      stopPtr = (pulseStopTime[id] - recStartTime) * recbuf.sampleRate|0
      {id, startPtr, stopPtr}
    o =
      id: socket.id,
      recStartTime: recStartTime
      recStopTime: recStopTime
      startStops: startStops
      pulseStartTime: @pulseStartTime
      pulseStopTime: @pulseStopTime
      sampleTimes: recbuf.sampleTimes
      sampleRate: actx.sampleRate
      bufferSize: processor.bufferSize
      channelCount: processor.channelCount
      recF32arr: f32arr.buffer
      DSSS_SPEC: DSSS_SPEC
      currentTime: actx.currentTime
    recbuf.clear()
    next(o)
  play: (next)->
*/
