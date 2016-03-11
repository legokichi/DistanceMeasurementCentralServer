Signal = window["Signal"]

class this.SignalViewer
  constructor: (width, height)->
    @cnv = document.createElement("canvas")
    @cnv.width = width
    @cnv.height = height
    @ctx = @cnv.getContext("2d")
    @offsetX = 0
    @offsetY = @cnv.height/2
    @zoomX = 1
    @zoomY = 1
    @drawZero = true
    @drawAuto = true
    @drawStatus = true
  text: (str, x, y, opt={})->
    {font, lineWidth, strokeStyle, fillStyle} = @ctx
    {color} = opt
    color ?= "black"
    @ctx.font = "35px";
    @ctx.lineWidth = 4;
    @ctx.strokeStyle = "white"
    @ctx.strokeText(str, x, y)
    @ctx.fillStyle = color
    @ctx.fillText(str, x, y)
    o = {font, lineWidth, strokeStyle, fillStyle}
    Object.keys(o).forEach (key)=> @ctx[key] = o[key]
    @
  draw: (f32arr, opt={})->
    {sampleRate} = opt
    arr = f32arr.map (v)-> if isFinite(v) then v else 0
    sampleRate ?= 44100
    [max, _] = Signal.Statictics.findMax(arr)
    [min, _] = Signal.Statictics.findMin(arr)
    if @drawAuto
      @zoomX = @cnv.width / arr.length
      @zoomY = @cnv.height / (max - min + 0.0000001)
      @offsetY = -min*@zoomY
    if @drawZero
      @ctx.beginPath()
      @ctx.moveTo(0,          @cnv.height - (@zoomY * 0 + @offsetY))
      @ctx.lineTo(@cnv.width, @cnv.height - (@zoomY * 0 + @offsetY))
      @ctx.stroke()
      @ctx.beginPath()
      @ctx.moveTo(@offsetX, @cnv.height - 0)
      @ctx.lineTo(@offsetX, @cnv.height - @cnv.height)
      @ctx.stroke()
    @ctx.beginPath()
    @ctx.moveTo(@zoomX * (0 + @offsetX), @cnv.height - (@zoomY * arr[0] + @offsetY))
    i = 0
    while i++<arr.length
      @ctx.lineTo(@zoomX * (i + @offsetX), @cnv.height - (@zoomY * arr[i] + @offsetY))
    @ctx.stroke()
    detail =
      "sampleRate": sampleRate
      "min": min
      "max": max
      "len": arr.length
      "len(ms)": arr.length/sampleRate*1000
      "size": @cnv.width+"x"+@cnv.height
    if @drawStatus
      Object.keys(detail).forEach (key, i)=>
        @text("#{key}:"+detail[key], 5, 15 + 10*i)
    @
  drawSpectrogram: (f32arr, opt={})->
    {sampleRate, windowSize, slideWidth, max} = opt
    arr = f32arr.map (v)-> if isFinite(v) then v else 0
    sampleRate ?= 44100
    windowSize ?= Math.pow(2, 8); # spectrgram height
    slideWidth ?= Math.pow(2, 5); # spectrgram width rate
    max ?= 255
    ptr = 0
    spectrums = []
    while ptr+windowSize < arr.length
      buffer = arr.subarray(ptr, ptr+windowSize)
      if buffer.length isnt windowSize then break
      {spectrum} = Signal.fft(buffer, sampleRate)
      for _, i in spectrum
        spectrum[i] = spectrum[i]*20000
      spectrums.push(spectrum)
      ptr += slideWidth
    @cnv.width = spectrums.length
    @cnv.height = spectrums[0].length
    imgdata = @ctx.createImageData(spectrums.length, spectrums[0].length)
    for _, i in spectrums
      for _, j in spectrum
        [r, g, b] = SignalViewer.hslToRgb(spectrums[i][j] / max, 0.5, 0.5)
        [x, y] = [i, imgdata.height - 1 - j]
        index = x + y * imgdata.width
        imgdata.data[index * 4 + 0] = b | 0
        imgdata.data[index * 4 + 1] = g | 0
        imgdata.data[index * 4 + 2] = r | 0 # is this bug?
        imgdata.data[index * 4 + 3] = 255
    @ctx.putImageData(imgdata, 0, 0)
    detail =
      "sampleRate": sampleRate
      "windowSize": windowSize # 周波数分解能パラメータ
      "slideWidth": slideWidth # 時間分解能パラメータ
      "windowSize(ms)": windowSize/sampleRate*1000
      "slideWidth(ms)": slideWidth/sampleRate*1000
      "ptr": 0+"-"+(ptr-1)+"/"+arr.length
      "ms": 0/sampleRate*1000+"-"+(ptr-1)/sampleRate*1000+"/"+arr.length*1000/sampleRate
      "reso": arr.length/slideWidth
      "size": spectrums.length+"x"+spectrums[0].length
    if @drawStatus
      Object.keys(detail).forEach (key, i)=>
        @text("#{key}:"+detail[key], 5, 15 + 10*i)
    @

  appendTo: (element)->
    element.appendChild(@cnv)
    @

  @hue2rgb = hue2rgb
  @hslToRgb = hslToRgb

  `function hue2rgb(p, q, t) {
    if (t < 0) { t += 1; }
    if (t > 1) { t -= 1; }
    if (t < 1 / 6) { return p + (q - p) * 6 * t; }
    if (t < 1 / 2) { return q; }
    if (t < 2 / 3) { return p + (q - p) * (2 / 3 - t) * 6; }
    return p;
  }
  function hslToRgb(h, s, l) {
    // h, s, l: 0~1
    h *= 5 / 6;
    if (h < 0) {
      h = 0;
    }
    if (5 / 6 < h) {
      h = 5 / 6;
    }
    var r, g, b;
    if (s === 0) {
      r = g = b = l;
    } else {
      var q = l < 0.5 ? l * (1 + s) : l + s - l * s;
      var p = 2 * l - q;
      r = hue2rgb(p, q, h + 1 / 3);
      g = hue2rgb(p, q, h);
      b = hue2rgb(p, q, h - 1 / 3);
    }
    return [r * 255, g * 255, b * 255];
  }`
