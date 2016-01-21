class this.TimeSpreadEcho
  constructor: (@actx, @pn)->
    @osc = new OSC(@actx)
    @offset = 30
    @beta = 1/@pn.length/10
    @processor = @actx.createScriptProcessor(Math.pow(2, 14), 1, 1)
    @handler = (ev)=>
      buffer = ev.inputBuffer.getChannelData(0)
      @process(buffer)
      ev.outputBuffer.getChannelData(0).set(buffer, 0)
    @processor.addEventListener("audioprocess", @handler)
    @cacheBufferA = new Float32Array(@processor.bufferSize*2)
    @cacheBufferB = new Float32Array(@processor.bufferSize*2)
    @cache = new Float32Array(@processor.bufferSize)
  process: (buffer)->
    signal = @cacheBufferA
    kernel = @cacheBufferB
    signal.set(buffer, 0)
    kernel.set(@pn.map((v)=> v*@beta), @offset); kernel[0] = 1
    view kernel,1024
    # ここから畳み込み
    _signal = Signal.fft(signal)
    _kernel = Signal.fft(kernel)
    for _, i in _signal.real
      _signal.real[i] = _signal.real[i] * _kernel.real[i]
      _signal.imag[i] = _signal.imag[i] * _kernel.imag[i] # 畳み込み
    conved = Signal.ifft(_signal.real, _signal.imag)
    # ここまで畳み込み
    A = conved.subarray(0, conved.length/2) # 前半分は前回の後ろ半分と加算
    B = conved.subarray(conved.length/2, conved.length) # 後半分は次回のためにキャッシュ
    for _, i in A
      @cache[i] += conved[i]
    buffer.set(@cache, 0)
    @cache = B
    return
  destructor: ->
    @processor.removeEventListener("audioprocess", @handler)
    @processor.disconnect()
