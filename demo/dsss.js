// Generated by CoffeeScript 1.10.0
(function() {
  var DSSS_SPEC, VIEW_SIZE, _craetePictureFrame, _prepareRec, _prepareSpect, actx, analyser, beepPulse, changeColor, collect, isBroadcasting, isRecording, main, osc, processor, pulseStartTime, pulseStopTime, ready, recbuf, sendRec, socket, startPulse, startRec, stopPulse, stopRec;

  window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia || window.navigator.mozGetUserMedia || window.navigator.getUserMedia;

  changeColor = function() {
    return document.body.style.backgroundColor = location.hash.slice(1);
  };

  window.addEventListener("DOMContentLoaded", changeColor);

  window.addEventListener("hashchange", changeColor);

  window["socket"] = socket = io(location.hostname + ":" + location.port);

  socket.on("connect", console.info.bind(console, "connect"));

  socket.on("reconnect", console.info.bind(console, "reconnect"));

  socket.on("reconnect_attempt", console.info.bind(console, "reconnect_attempt"));

  socket.on("reconnecting", console.info.bind(console, "reconnecting"));

  socket.on("reconnect_error", console.info.bind(console, "reconnect_error"));

  socket.on("reconnect_failed", console.info.bind(console, "reconnect_failed"));

  socket.on("disconnect", console.info.bind(console, "disconnect"));

  socket.on("error", console.info.bind(console, "error"));

  socket.on("echo", console.info.bind(console, "echo"));

  socket.on("connect", function() {
    return socket.emit("echo", "hello");
  });

  window.onerror = function(err) {
    var pre, textnode;
    console.error(err, err != null ? err.stack : void 0);
    document.body.style.backgroundColor = "gray";
    pre = document.createElement("pre");
    textnode = document.createTextNode(err.stack || err);
    pre.appendChild(textnode);
    return document.body.appendChild(pre);
  };

  VIEW_SIZE = Math.pow(2, 10);

  actx = new AudioContext();

  osc = new OSC(actx);

  analyser = actx.createAnalyser();

  analyser.smoothingTimeConstant = 0;

  analyser.fftSize = 512;

  processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1);

  recbuf = null;

  isRecording = false;

  isBroadcasting = false;

  pulseStartTime = {};

  pulseStopTime = {};

  DSSS_SPEC = null;

  main = function() {
    socket.on("ready", function(a) {
      return ready(a)(function() {
        return socket.emit("ready");
      });
    });
    socket.on("startRec", function() {
      return startRec(function() {
        return socket.emit("startRec");
      });
    });
    socket.on("startPulse", function(a) {
      return startPulse(a)(function() {
        return socket.emit("startPulse");
      });
    });
    socket.on("beepPulse", function() {
      return beepPulse(function() {
        return socket.emit("beepPulse");
      });
    });
    socket.on("stopPulse", function(a) {
      return stopPulse(a)(function() {
        return socket.emit("stopPulse");
      });
    });
    socket.on("stopRec", function() {
      return stopRec(function() {
        return socket.emit("stopRec");
      });
    });
    socket.on("sendRec", function() {
      return sendRec(function(a) {
        return socket.emit("sendRec", a);
      });
    });
    return socket.on("collect", function(a) {
      return collect(a)(function() {
        return socket.emit("collect");
      });
    });
  };

  ready = function(arg) {
    var carrier_freq, isChirp, length, powL, seed;
    length = arg.length, seed = arg.seed, carrier_freq = arg.carrier_freq, isChirp = arg.isChirp, powL = arg.powL;
    return function(next) {
      var abuf, encoded_data, matched, n, ss_code, ss_sig;
      n = function(a) {
        return a.split("").map(Number);
      };
      document.body.style.backgroundColor = location.hash.slice(1);
      recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount);
      isRecording = false;
      isBroadcasting = false;
      pulseStartTime = {};
      pulseStopTime = {};
      DSSS_SPEC = null;
      if (isChirp) {
        console.log(ss_code = Signal.mseqGen(length, seed));
        return osc.resampling(Signal.createCodedChirp(ss_code, powL), 14).then(function(matched) {
          var abuf;
          abuf = osc.createAudioBufferFromArrayBuffer(matched, actx.sampleRate);
          DSSS_SPEC = {
            abuf: abuf,
            matched: matched.buffer
          };
          return next();
        });
      } else {
        ss_code = Signal.mseqGen(length, seed);
        encoded_data = Signal.encode_chipcode_separated_zero([1, 0, 1], ss_code);
        matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0);
        ss_sig = Signal.BPSK(encoded_data, carrier_freq, actx.sampleRate, 0);
        abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate);
        DSSS_SPEC = {
          abuf: abuf,
          matched: matched.buffer
        };
        console.log(matched.length, ss_sig.length, abuf);
        (function() {
          var coms, corr;
          corr = Signal.fft_smart_overwrap_correlation(ss_sig, matched);
          return coms = [[matched, true, true], [ss_sig, true, true], [corr, true, true]].forEach(function(com, i) {
            var render;
            render = new Signal.Render(com[0].length / 100, 64);
            Signal.Render.prototype.drawSignal.apply(render, com);
            document.body.appendChild(render.element);
            return document.body.appendChild(document.createElement("br"));
          });
        });
        return next();
      }
    };
  };

  startRec = function(next) {
    isRecording = true;
    return next();
  };

  startPulse = function(id) {
    return function(next) {
      pulseStartTime[id] = actx.currentTime;
      return next();
    };
  };

  beepPulse = function(next) {
    var abuf, anode, recur;
    abuf = DSSS_SPEC.abuf;
    anode = osc.createAudioNodeFromAudioBuffer(abuf);
    anode.connect(actx.destination);
    anode.start(actx.currentTime);
    return setTimeout((recur = function() {
      if (recbuf.chsBuffers[0].length > Math.ceil(abuf.length / processor.bufferSize)) {
        return next();
      } else {
        return setTimeout(recur, 100);
      }
    }), abuf.duration * 1.1 * 1000);
  };

  stopPulse = function(id) {
    return function(next) {
      pulseStopTime[id] = actx.currentTime;
      return next();
    };
  };

  stopRec = function(next) {
    isRecording = false;
    return next();
  };

  sendRec = function(next) {
    var f32arr, o, recStartTime, recStopTime, startStops;
    f32arr = recbuf.merge();
    recStartTime = recbuf.sampleTimes[0] - (recbuf.bufferSize / recbuf.sampleRate);
    recStopTime = recbuf.sampleTimes[recbuf.sampleTimes.length - 1];
    startStops = Object.keys(pulseStartTime).map(function(id) {
      var startPtr, stopPtr;
      startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate;
      stopPtr = (pulseStopTime[id] - recStartTime) * recbuf.sampleRate;
      return {
        id: id,
        startPtr: startPtr,
        stopPtr: stopPtr
      };
    });
    o = {
      id: socket.id,
      alias: location.hash.slice(1),
      startStops: startStops,
      pulseStartTime: pulseStartTime,
      pulseStopTime: pulseStopTime,
      sampleTimes: recbuf.sampleTimes,
      sampleRate: actx.sampleRate,
      bufferSize: processor.bufferSize,
      channelCount: processor.channelCount,
      recF32arr: f32arr.buffer,
      DSSS_SPEC: DSSS_SPEC
    };
    recbuf.clear();
    return next(o);
  };

  collect = function(datas) {
    return function(next) {
      var K, aliases, basePt, delayTimes, distances, distancesAliased, ds, frame_, pseudoPts, pulseTimes, relDelayTimes, render, results, sampleRates, sdm;
      if (location.hash.slice(1) !== "red") {
        return next();
      }
      console.info("calcCorrel");
      console.time("calcCorrel");
      frame_ = _craetePictureFrame("");
      document.body.appendChild(frame_.element);
      aliases = datas.reduce((function(o, arg) {
        var alias, id;
        id = arg.id, alias = arg.alias;
        o[id] = alias;
        return o;
      }), {});
      results = datas.map(function(arg) {
        var DSSS_SPEC, _results, alias, frame, id, recF32arr, sampleRate, startStops;
        id = arg.id, alias = arg.alias, startStops = arg.startStops, recF32arr = arg.recF32arr, DSSS_SPEC = arg.DSSS_SPEC, sampleRate = arg.sampleRate;
        frame = _craetePictureFrame(alias + "@" + id);
        frame_.add(frame.element);
        _results = startStops.map(function(arg1) {
          var A, B, C, T, U, _, _A, _B, _C, __A, __C, _frame, _id, coms, corrBA, corrBC, correl, i, idx, idxB, idxBA, idxBC, j, matched, max_offset, maxesBA, maxesBC, offset_arr, offset_arr2, offset_arr3, pulseTime, range, ref, ref1, ref2, ref3, ref4, ref5, ref6, section, startPtr, stopPtr, sum, val;
          _id = arg1.id, startPtr = arg1.startPtr, stopPtr = arg1.stopPtr;
          section = new Float32Array(recF32arr).subarray(startPtr, stopPtr);
          matched = new Float32Array(DSSS_SPEC.matched);
          correl = Signal.fft_smart_overwrap_correlation(section, matched);
          T = matched.length * 2;
          A = correl.subarray(T * 0, T * 0 + T);
          B = correl.subarray(T * 1, T * 1 + T);
          C = correl.subarray(T * 2, T * 2 + T);
          range = Math.pow(2, 9);
          sum = B.map(function(_, i) {
            return A[i] + B[i] + C[i];
          });
          ref = Signal.Statictics.findMax(sum), _ = ref[0], idxB = ref[1];
          ref1 = [A, B, C].map(function(X) {
            return A.subarray(idxB - range, idxB + range).map(function(v) {
              return v * v * v;
            });
          }), _A = ref1[0], _B = ref1[1], _C = ref1[2];
          U = range * 2;
          maxesBA = new Float32Array(U);
          maxesBC = new Float32Array(U);
          for (i = j = 0, ref2 = U * 0.8 | 0; 0 <= ref2 ? j <= ref2 : j >= ref2; i = 0 <= ref2 ? ++j : --j) {
            __A = new Float32Array(U);
            __A.set(_A.subarray(U - i, U), 0);
            corrBA = Signal.fft_smart_overwrap_correlation(_B, __A);
            ref3 = Signal.Statictics.findMax(corrBA), val = ref3[0], idx = ref3[1];
            maxesBA[i] = idx > 0 ? val : 0;
            __C = new Float32Array(U);
            __C.set(_C.subarray(U - i, U), 0);
            corrBC = Signal.fft_smart_overwrap_correlation(_B, __C);
            ref4 = Signal.Statictics.findMax(corrBC), val = ref4[0], idx = ref4[1];
            maxesBC[i] = idx > 0 ? val : 0;
          }
          ref5 = Signal.Statictics.findMax(maxesBA), _ = ref5[0], idxBA = ref5[1];
          ref6 = Signal.Statictics.findMax(maxesBC), _ = ref6[0], idxBC = ref6[1];
          max_offset = idxB - range + (idxBC + idxBA) / 2;
          pulseTime = (startPtr + max_offset) / sampleRate;
          _frame = _craetePictureFrame(aliases[id] + "<->" + aliases[_id]);
          frame.add(_frame.element);
          offset_arr = new Uint8Array(correl.length);
          offset_arr[max_offset] = 255;
          offset_arr[T * 0] = 255;
          offset_arr[T * 1] = 255;
          offset_arr[T * 2] = 255;
          offset_arr2 = new Uint8Array(T);
          offset_arr2[idxB] = 255;
          offset_arr2[idxB - range] = 255;
          offset_arr2[idxB + range] = 255;
          offset_arr3 = new Uint8Array(maxesBA.length);
          offset_arr3[idxBA] = 255;
          offset_arr3[idxBC] = 255;
          coms = [[section, true, true], [correl, true, true], [offset_arr, true, true], [A, true, true], [B, true, true], [C, true, true], [sum, true, true], [offset_arr2, true, true], [_A, true, true], [_B, true, true], [_C, true, true], [offset_arr3, true, true], [maxesBA, true, true], [maxesBC, true, true]].forEach(function(com, i) {
            var render;
            render = new Signal.Render(VIEW_SIZE, 64);
            Signal.Render.prototype.drawSignal.apply(render, com);
            _frame.add(render.element);
            return _frame.add(document.createElement("br"));
          });
          _frame.add(document.createTextNode([idxBC, idxBA].join(",")));
          return {
            id: _id,
            max_offset: max_offset,
            pulseTime: pulseTime
          };
        });
        return {
          id: id,
          alias: alias,
          results: _results
        };
      });
      console.timeEnd("calcCorrel");
      console.info("calcRelDist");
      console.time("calcRelDist");
      sampleRates = datas.reduce((function(o, arg) {
        var id, sampleRate;
        id = arg.id, sampleRate = arg.sampleRate;
        o[id] = sampleRate;
        return o;
      }), {});
      pulseTimes = {};
      relDelayTimes = {};
      delayTimes = {};
      distances = {};
      distancesAliased = {};
      results.forEach(function(arg) {
        var alias, id, results;
        id = arg.id, alias = arg.alias, results = arg.results;
        return results.forEach(function(arg1) {
          var _id, correl, max_offset, max_score, pulseTime, results, section, stdev, stdscore;
          _id = arg1.id, section = arg1.section, results = arg1.results, correl = arg1.correl, max_score = arg1.max_score, max_offset = arg1.max_offset, stdev = arg1.stdev, stdscore = arg1.stdscore, pulseTime = arg1.pulseTime;
          pulseTimes[id] = pulseTimes[id] || {};
          return pulseTimes[id][_id] = pulseTime;
        });
      });
      Object.keys(pulseTimes).forEach(function(id1) {
        return Object.keys(pulseTimes).forEach(function(id2) {
          relDelayTimes[id1] = relDelayTimes[id1] || {};
          return relDelayTimes[id1][id2] = pulseTimes[id1][id2] - pulseTimes[id1][id1];
        });
      });
      Object.keys(pulseTimes).forEach(function(id1) {
        return Object.keys(pulseTimes).forEach(function(id2) {
          delayTimes[id1] = delayTimes[id1] || {};
          delayTimes[id1][id2] = Math.abs(Math.abs(relDelayTimes[id1][id2]) - Math.abs(relDelayTimes[id2][id1]));
          distances[id1] = distances[id1] || {};
          distances[id1][id2] = delayTimes[id1][id2] / 2 * 340;
          distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {};
          return distancesAliased[aliases[id1]][aliases[id2]] = distances[id1][id2];
        });
      });
      console.timeEnd("calcRelDist");
      console.info("distancesAliased", distancesAliased);
      console.info("calcRelPos");
      console.time("calcRelPos");
      ds = Object.keys(delayTimes).map(function(id1) {
        return Object.keys(delayTimes).map(function(id2) {
          return distances[id1][id2];
        });
      });
      pseudoPts = results.map(function(id1, i) {
        return new Point(Math.random() * 10, Math.random() * 10);
      });
      sdm = new SDM(pseudoPts, ds);
      K = 0;
      while (K++ < 200) {
        sdm.step();
      }
      console.timeEnd("calcRelPos");
      console.info("calcRelPos", sdm.det(), sdm.points);
      render = new Signal.Render(Math.pow(2, 8), Math.pow(2, 8));
      basePt = sdm.points[0];
      sdm.points.forEach(function(pt) {
        return render.cross(render.cnv.width / 2 + (pt.x - basePt.x) * 10, render.cnv.height / 2 + (pt.y - basePt.y) * 10, 16);
      });
      document.body.appendChild(render.element);
      document.body.style.backgroundColor = "lime";
      return next();
    };
  };

  _prepareRec = function(next) {
    var left, right;
    left = function(err) {
      throw err;
    };
    right = function(stream) {
      var source;
      source = actx.createMediaStreamSource(stream);
      if (location.hash.slice(1) === "red") {
        source.connect(analyser);
      }
      source.connect(processor);
      processor.connect(actx.destination);
      processor.addEventListener("audioprocess", function(ev) {
        if (isRecording) {
          return recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime);
        }
      });
      return next();
    };
    return navigator.getUserMedia({
      video: false,
      audio: true
    }, right, left);
  };

  _prepareSpect = function(next) {
    var i, render, rndr, spectrums;
    if (location.hash.slice(1) !== "red") {
      return next();
    }
    spectrums = (function() {
      var j, ref, results1;
      results1 = [];
      for (i = j = 0, ref = analyser.frequencyBinCount; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
        results1.push(new Uint8Array(analyser.frequencyBinCount));
      }
      return results1;
    })();
    rndr = new Signal.Render(spectrums.length, spectrums[0].length);
    document.body.appendChild(rndr.element);
    (render = function() {
      var spectrum;
      spectrum = spectrums.shift();
      analyser.getByteFrequencyData(spectrum);
      spectrums.push(spectrum);
      rndr.drawSpectrogram(spectrums);
      return requestAnimationFrame(render);
    })();
    return next();
  };

  _craetePictureFrame = function(description) {
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
    fieldset.style.backgroundColor = "#D2E0E6";
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
      }
    };
  };

  window.addEventListener("DOMContentLoaded", function() {
    return _prepareRec(function() {
      return _prepareSpect(function() {
        return main();
      });
    });
  });

}).call(this);
