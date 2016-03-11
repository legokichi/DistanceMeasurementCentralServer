SignalViewer = window["SignalViewer"]

class this.Detector
  constructor: (actx)->
    @actx = actx
    @osc = new OSC(@actx)
    @abuf = null
    @signal = null
  init: (data, next)->
    {pulseType} = data
    switch pulseType
      when "mseq" then @init_mseq(data, next)
      else             throw new Error "uknown pulse type #{pulseType}"
  init_mseq: ({length, seedA, seedB, carrierFreq}, next)->
    mseqA = Signal.mseqGen(length, seedA)
    mseqB = Signal.mseqGen(length, seedB)
    matchedA = Signal.BPSK(mseqA, carrierFreq, @actx.sampleRate, 0)
    matchedB = Signal.BPSK(mseqB, carrierFreq, @actx.sampleRate, 0)
    @signal = new Float32Array(matchedA.length*2 + matchedB.length)
    @signal.set(matchedA, 0)
    @signal.set(matchedB, matchedA.length*2)
    @abuf = @osc.createAudioBufferFromArrayBuffer(@signal, @actx.sampleRate)
    next()
  beep: (next)->
    startTime = @actx.currentTime
    anode = @osc.createAudioNodeFromAudioBuffer(@abuf)
    anode.connect(@actx.destination)
    anode.start(startTime)
    do recur = =>
      if (startTime + @abuf.duration) < @actx.currentTime
      then setTimeout(next, 100)
      else setTimeout(recur, 100)
  calc: (f32arr)->
    sampleRate = @actx.sampleRate
    windowSize = Math.pow(2, 8) # 周波数分解能
    slideWidth = Math.pow(2, 4) # 時間分解能
    new SignalViewer(f32arr.length/slideWidth, windowSize/2).draw(f32arr).appendTo(document.body)
    new SignalViewer(1024, 256).drawSpectrogram(f32arr, {sampleRate, windowSize, slideWidth}).appendTo(document.body)
