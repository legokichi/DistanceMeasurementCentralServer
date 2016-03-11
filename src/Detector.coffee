SignalViewer = window["SignalViewer"]
Signal = window["Signal"]

MULTIPASS_DISTANCE = 9
SOUND_OF_SPEED = 340

class this.Detector
  constructor: (actx)->
    @actx = actx
    @osc = new OSC(@actx)
    @abuf = null
    @matchedA = null
    @matchedB = null
    @pulseType = null
  init: (data, next)->
    {pulseType} = data
    @pulseType = pulseType
    switch @pulseType
      when "mseq" then @init_mseq(data, next)
      else             throw new Error "uknown pulse type #{pulseType}"
  init_mseq: ({length, seedA, seedB, carrierFreq}, next)->
    mseqA = Signal.mseqGen(length, seedA)
    mseqB = Signal.mseqGen(length, seedB)
    @matchedA = Signal.BPSK(mseqA, carrierFreq, @actx.sampleRate, 0)
    @matchedB = Signal.BPSK(mseqB, carrierFreq, @actx.sampleRate, 0)
    signal = new Float32Array(@matchedA.length*2 + @matchedB.length)
    signal.set(@matchedA, 0)
    signal.set(@matchedB, @matchedA.length*2)
    @abuf = @osc.createAudioBufferFromArrayBuffer(signal, @actx.sampleRate)
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
  calc: (f32arr, startStops, opt={})->
    {sampleRate} = opt
    sampleRate ?= @actx.sampleRate
    windowSize = Math.pow(2, 8) # 周波数分解能
    slideWidth = Math.pow(2, 4) # 時間分解能
    new SignalViewer(f32arr.length/slideWidth, windowSize/2).draw(f32arr).appendTo(document.body)
    new SignalViewer(1024, 256).drawSpectrogram(f32arr, {sampleRate, windowSize, slideWidth}).appendTo(document.body)
    results = switch @pulseType
      when "mseq" then startStops.map(@calc_mseq(f32arr, sampleRate))
      else             throw new Error "uknown pulse type #{pulseType}"
    console.table results

  calc_mseq: (rawdata, sampleRate)-> ({id, startPtr, stopPtr})=>
    frame = craetePictureFrame "#{socket.id}<->#{id}", document.body
    correlA = Signal.fft_smart_overwrap_correlation(rawdata, @matchedA)
    correlB = Signal.fft_smart_overwrap_correlation(rawdata, @matchedB)
    frame.view rawdata, "rawdata"
    frame.view correlA, "correlA"
    frame.view correlB, "correlB"
    [_, idxA] = Signal.Statictics.findMax(correlA)
    [_, idxB] = Signal.Statictics.findMax(correlB)
    relB = idxA + @matchedA.length*2; if relB < 0 then relB = 0; # Bの位置とAから見たBの位置
    relA = idxB - @matchedA.length*2; if relA < 0 then relA = 0; # Aの位置とBから見たAの位置
    stdscoreA = do ->
      ave = Signal.Statictics.average(correlA)
      vari = Signal.Statictics.variance(correlA)
      if vari is 0 then vari = 0.000001
      (x)-> 10 * (x - ave) / vari + 50
    stdscoreB = do ->
      ave = Signal.Statictics.average(correlB)
      vari = Signal.Statictics.variance(correlB)
      if vari is 0 then vari = 0.000001
      (x)-> 10 * (x - ave) / vari + 50
    scoreB = stdscoreB(correlB[idxB]) + stdscoreA(correlA[relA])
    scoreA = stdscoreA(correlA[idxA]) + stdscoreB(correlB[relB]) # Aの値とAから見たBの位置の値
    range = (MULTIPASS_DISTANCE/SOUND_OF_SPEED*sampleRate)|0
    if relA > 0 && scoreB > scoreA
      # Bが正しいのでAを修正
      [_, idx] = Signal.Statictics.findMax(correlA.subarray(relA-range, relA+range))
      idxA = relA - range + idx
    else
      # Aが正しいのでBを修正
      [_, idx] = Signal.Statictics.findMax(correlB.subarray(relB-range, relB+range))
      idxB = relB - range + idx
    # 音圧ピーク値
    maxA = correlA[idxA]
    maxB = correlB[idxB]
    marker = new Uint8Array(correlA.length)
    marker[idxA-range] = 255
    marker[idxA] = 255
    marker[idxA+range] = 255
    marker[idxB-range] = 255
    marker[idxB] = 255
    marker[idxB+range] = 255
    frame.view marker, "marker"
    # 最大値付近を切り取り
    zoomA = correlA.subarray(idxA-range, idxA+range)
    zoomB = correlB.subarray(idxB-range, idxB+range)
    frame.view zoomA, "zoomA"
    frame.view zoomB, "zoomB"
    # 位置が一致するように微調整
    correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB)
    frame.view correl, "correl"
    # 区間に分けて相関値を探索
    # パルス位置は上記の通りを一致させてあるので AとBの区間において相互相関[0] の位置の相関値を調べグラフ化
    zoom = zoomA.map (_, i)-> zoomA[i]*zoomB[i]
    logs = new Float32Array(zoom.length)
    windowsize = (0.6/SOUND_OF_SPEED*sampleRate)|0
    slidewidth = 1
    i = 0
    while zoomA.length > i + windowsize
      val = zoom.subarray(i, i + windowsize).reduce(((sum, v, i)-> sum + v), 0)
      logs[i] = val
      i += slidewidth
    frame.view logs, "logs"
    _logs = Signal.lowpass(logs, sampleRate, 800, 1)
    frame.view _logs, "logs(lowpass)"
    [max, _idx] = Signal.Statictics.findMax(_logs)
    i = 1
    i++ while i < _idx && _logs[i] < max/5
    i++ while i < _idx && _logs[i] > _logs[i-1]
    idx = i
    marker = new Uint8Array(logs.length)
    marker[idx] = 255
    frame.view marker, "marker"
    max_offset = idx + (idxA - range)
    pulseTime = (startPtr + max_offset) / sampleRate
    max_val = (maxA + maxB)/2
    {id, max_offset, pulseTime, max_val}


VIEW_SIZE = Math.pow(2, 12)
craetePictureFrame = (description, target) ->
  fieldset = document.createElement('fieldset')
  style = document.createElement('style')
  style.appendChild(document.createTextNode("canvas,img{border:1px solid black;}"))
  style.setAttribute("scoped", "scoped")
  fieldset.appendChild(style)
  legend = document.createElement('legend')
  legend.appendChild(document.createTextNode(description))
  fieldset.appendChild(legend)
  fieldset.style.display = 'inline-block'
  fieldset.style.backgroundColor = "white"
  target.appendChild fieldset if target?
  return {
    element: fieldset
    add: (element)->
      if typeof element is "string"
        txtNode = document.createTextNode element
        p = document.createElement("p")
        p.appendChild txtNode
        fieldset.appendChild p
      else fieldset.appendChild element
    view: (arr, title="")->
      __frame = craetePictureFrame title + "(#{arr.length})"
      width = if VIEW_SIZE < arr.length then VIEW_SIZE else arr.length
      render = new SignalViewer(width, 64)
      render.draw(arr)
      __frame.add render.cnv
      @add __frame.element
      @add document.createElement "br"
    text: (title)->
      @add document.createTextNode title
      @add document.createElement "br"
  }
