// Generated by CoffeeScript 1.10.0
(function() {
  var MULTIPASS_DISTANCE, SOUND_OF_SPEED, Signal, SignalViewer, VIEW_SIZE, craetePictureFrame;

  SignalViewer = window["SignalViewer"];

  Signal = window["Signal"];

  MULTIPASS_DISTANCE = 9;

  SOUND_OF_SPEED = 340;

  this.Detector = (function() {
    function Detector(actx) {
      this.actx = actx;
      this.osc = new OSC(this.actx);
      this.abuf = null;
      this.matchedA = null;
      this.matchedB = null;
      this.pulseType = null;
    }

    Detector.prototype.init = function(data, next) {
      var pulseType;
      pulseType = data.pulseType;
      this.pulseType = pulseType;
      switch (this.pulseType) {
        case "mseq":
          return this.init_mseq(data, next);
        default:
          throw new Error("uknown pulse type " + pulseType);
      }
    };

    Detector.prototype.init_mseq = function(arg, next) {
      var carrierFreq, length, mseqA, mseqB, seedA, seedB, signal;
      length = arg.length, seedA = arg.seedA, seedB = arg.seedB, carrierFreq = arg.carrierFreq;
      mseqA = Signal.mseqGen(length, seedA);
      mseqB = Signal.mseqGen(length, seedB);
      this.matchedA = Signal.BPSK(mseqA, carrierFreq, this.actx.sampleRate, 0);
      this.matchedB = Signal.BPSK(mseqB, carrierFreq, this.actx.sampleRate, 0);
      signal = new Float32Array(this.matchedA.length * 2 + this.matchedB.length);
      signal.set(this.matchedA, 0);
      signal.set(this.matchedB, this.matchedA.length * 2);
      this.abuf = this.osc.createAudioBufferFromArrayBuffer(signal, this.actx.sampleRate);
      return next();
    };

    Detector.prototype.beep = function(next) {
      var anode, recur, startTime;
      startTime = this.actx.currentTime;
      anode = this.osc.createAudioNodeFromAudioBuffer(this.abuf);
      anode.connect(this.actx.destination);
      anode.start(startTime);
      return (recur = (function(_this) {
        return function() {
          if ((startTime + _this.abuf.duration) < _this.actx.currentTime) {
            return setTimeout(next, 100);
          } else {
            return setTimeout(recur, 100);
          }
        };
      })(this))();
    };

    Detector.prototype.calc = function(f32arr, startStops, opt) {
      var results, sampleRate, slideWidth, windowSize;
      if (opt == null) {
        opt = {};
      }
      sampleRate = opt.sampleRate;
      if (sampleRate == null) {
        sampleRate = this.actx.sampleRate;
      }
      windowSize = Math.pow(2, 8);
      slideWidth = Math.pow(2, 4);
      new SignalViewer(f32arr.length / slideWidth, windowSize / 2).draw(f32arr).appendTo(document.body);
      new SignalViewer(1024, 256).drawSpectrogram(f32arr, {
        sampleRate: sampleRate,
        windowSize: windowSize,
        slideWidth: slideWidth
      }).appendTo(document.body);
      results = (function() {
        switch (this.pulseType) {
          case "mseq":
            return startStops.map(this.calc_mseq(f32arr, sampleRate));
          default:
            throw new Error("uknown pulse type " + pulseType);
        }
      }).call(this);
      return console.table(results);
    };

    Detector.prototype.calc_mseq = function(rawdata, sampleRate) {
      return (function(_this) {
        return function(arg) {
          var _, _idx, _logs, correl, correlA, correlB, frame, i, id, idx, idxA, idxB, logs, marker, max, maxA, maxB, max_offset, max_val, pulseTime, range, ref, ref1, ref2, ref3, ref4, relA, relB, scoreA, scoreB, slidewidth, startPtr, stdscoreA, stdscoreB, stopPtr, val, windowsize, zoom, zoomA, zoomB;
          id = arg.id, startPtr = arg.startPtr, stopPtr = arg.stopPtr;
          frame = craetePictureFrame(socket.id + "<->" + id, document.body);
          correlA = Signal.fft_smart_overwrap_correlation(rawdata, _this.matchedA);
          correlB = Signal.fft_smart_overwrap_correlation(rawdata, _this.matchedB);
          frame.view(rawdata, "rawdata");
          frame.view(correlA, "correlA");
          frame.view(correlB, "correlB");
          ref = Signal.Statictics.findMax(correlA), _ = ref[0], idxA = ref[1];
          ref1 = Signal.Statictics.findMax(correlB), _ = ref1[0], idxB = ref1[1];
          relB = idxA + _this.matchedA.length * 2;
          if (relB < 0) {
            relB = 0;
          }
          relA = idxB - _this.matchedA.length * 2;
          if (relA < 0) {
            relA = 0;
          }
          stdscoreA = (function() {
            var ave, vari;
            ave = Signal.Statictics.average(correlA);
            vari = Signal.Statictics.variance(correlA);
            if (vari === 0) {
              vari = 0.000001;
            }
            return function(x) {
              return 10 * (x - ave) / vari + 50;
            };
          })();
          stdscoreB = (function() {
            var ave, vari;
            ave = Signal.Statictics.average(correlB);
            vari = Signal.Statictics.variance(correlB);
            if (vari === 0) {
              vari = 0.000001;
            }
            return function(x) {
              return 10 * (x - ave) / vari + 50;
            };
          })();
          scoreB = stdscoreB(correlB[idxB]) + stdscoreA(correlA[relA]);
          scoreA = stdscoreA(correlA[idxA]) + stdscoreB(correlB[relB]);
          range = (MULTIPASS_DISTANCE / SOUND_OF_SPEED * sampleRate) | 0;
          if (relA > 0 && scoreB > scoreA) {
            ref2 = Signal.Statictics.findMax(correlA.subarray(relA - range, relA + range)), _ = ref2[0], idx = ref2[1];
            idxA = relA - range + idx;
          } else {
            ref3 = Signal.Statictics.findMax(correlB.subarray(relB - range, relB + range)), _ = ref3[0], idx = ref3[1];
            idxB = relB - range + idx;
          }
          maxA = correlA[idxA];
          maxB = correlB[idxB];
          marker = new Uint8Array(correlA.length);
          marker[idxA - range] = 255;
          marker[idxA] = 255;
          marker[idxA + range] = 255;
          marker[idxB - range] = 255;
          marker[idxB] = 255;
          marker[idxB + range] = 255;
          frame.view(marker, "marker");
          zoomA = correlA.subarray(idxA - range, idxA + range);
          zoomB = correlB.subarray(idxB - range, idxB + range);
          frame.view(zoomA, "zoomA");
          frame.view(zoomB, "zoomB");
          correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB);
          frame.view(correl, "correl");
          zoom = zoomA.map(function(_, i) {
            return zoomA[i] * zoomB[i];
          });
          logs = new Float32Array(zoom.length);
          windowsize = (0.6 / SOUND_OF_SPEED * sampleRate) | 0;
          slidewidth = 1;
          i = 0;
          while (zoomA.length > i + windowsize) {
            val = zoom.subarray(i, i + windowsize).reduce((function(sum, v, i) {
              return sum + v;
            }), 0);
            logs[i] = val;
            i += slidewidth;
          }
          frame.view(logs, "logs");
          _logs = Signal.lowpass(logs, sampleRate, 800, 1);
          frame.view(_logs, "logs(lowpass)");
          ref4 = Signal.Statictics.findMax(_logs), max = ref4[0], _idx = ref4[1];
          i = 1;
          while (i < _idx && _logs[i] < max / 5) {
            i++;
          }
          while (i < _idx && _logs[i] > _logs[i - 1]) {
            i++;
          }
          idx = i;
          marker = new Uint8Array(logs.length);
          marker[idx] = 255;
          frame.view(marker, "marker");
          max_offset = idx + (idxA - range);
          pulseTime = (startPtr + max_offset) / sampleRate;
          max_val = (maxA + maxB) / 2;
          return {
            id: id,
            max_offset: max_offset,
            pulseTime: pulseTime,
            max_val: max_val
          };
        };
      })(this);
    };

    return Detector;

  })();

  VIEW_SIZE = Math.pow(2, 12);

  craetePictureFrame = function(description, target) {
    var fieldset, legend, style;
    fieldset = document.createElement('fieldset');
    style = document.createElement('style');
    style.appendChild(document.createTextNode("canvas,img{border:1px solid black;}"));
    style.setAttribute("scoped", "scoped");
    fieldset.appendChild(style);
    legend = document.createElement('legend');
    legend.appendChild(document.createTextNode(description));
    fieldset.appendChild(legend);
    fieldset.style.display = 'inline-block';
    fieldset.style.backgroundColor = "white";
    if (target != null) {
      target.appendChild(fieldset);
    }
    return {
      element: fieldset,
      add: function(element) {
        var p, txtNode;
        if (typeof element === "string") {
          txtNode = document.createTextNode(element);
          p = document.createElement("p");
          p.appendChild(txtNode);
          return fieldset.appendChild(p);
        } else {
          return fieldset.appendChild(element);
        }
      },
      view: function(arr, title) {
        var __frame, render, width;
        if (title == null) {
          title = "";
        }
        __frame = craetePictureFrame(title + ("(" + arr.length + ")"));
        width = VIEW_SIZE < arr.length ? VIEW_SIZE : arr.length;
        render = new SignalViewer(width, 64);
        render.draw(arr);
        __frame.add(render.cnv);
        this.add(__frame.element);
        return this.add(document.createElement("br"));
      },
      text: function(title) {
        this.add(document.createTextNode(title));
        return this.add(document.createElement("br"));
      }
    };
  };

}).call(this);