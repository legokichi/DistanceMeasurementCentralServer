// Generated by CoffeeScript 1.10.0
(function() {
  var DSSS_SPEC, RANGE, VIEW_SIZE, _craetePictureFrame, _prepareRec, _prepareSpect, actx, analyser, beepPulse, changeColor, collect, correlCache, isBroadcasting, isRecording, main, osc, processor, pulseStartTime, pulseStopTime, ready, recbuf, sendRec, socket, startPulse, startRec, stopPulse, stopRec;

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

  RANGE = Math.pow(2, 10);

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

  correlCache = {};

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
      var abuf, coms, corr, encoded_data, matched, n, ss_code, ss_sig;
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
        encoded_data = Signal.encode_chipcode_separated_zero([1, 1], ss_code);
        matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0);
        ss_sig = Signal.BPSK(encoded_data, carrier_freq, actx.sampleRate, 0);
        abuf = osc.createAudioBufferFromArrayBuffer(ss_sig, actx.sampleRate);
        DSSS_SPEC = {
          abuf: abuf,
          matched: matched.buffer
        };
        next();
        return;
        corr = Signal.fft_smart_overwrap_correlation(ss_sig, matched);
        return coms = [[matched, true, true], [ss_sig, true, true], [corr, true, true]].forEach(function(com, i) {
          var render;
          render = new Signal.Render(VIEW_SIZE, 64);
          Signal.Render.prototype.drawSignal.apply(render, com);
          document.body.appendChild(render.element);
          return document.body.appendChild(document.createElement("br"));
        });
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
      var K, aliases, delayTimes, distances, distancesAliased, ds, pseudoPts, pulseTimes, relDelayTimes, results, sampleRates, sdm;
      if (location.hash.slice(1) !== "red") {
        return next();
      }
      console.info("calcCorrel");
      console.time("calcCorrel");
      results = datas.map(function(arg) {
        var DSSS_SPEC, _results, alias, id, recF32arr, sampleRate, startStops;
        id = arg.id, alias = arg.alias, startStops = arg.startStops, recF32arr = arg.recF32arr, DSSS_SPEC = arg.DSSS_SPEC, sampleRate = arg.sampleRate;
        correlCache[id] = correlCache[id] || {};
        _results = startStops.map(function(arg1) {
          var _id, correl, curr, matched, max_offset, max_score, prev, pulseTime, raked, ref, ref1, section, startPtr, stopPtr;
          _id = arg1.id, startPtr = arg1.startPtr, stopPtr = arg1.stopPtr;
          section = new Float32Array(recF32arr).subarray(startPtr, stopPtr);
          matched = DSSS_SPEC.matched;
          correl = Signal.fft_smart_overwrap_correlation(section, new Float32Array(matched));
          correlCache[id][_id] = correlCache[id][_id] || [null, null];
          correlCache[id][_id].shift();
          correlCache[id][_id].push(correl);
          ref = correlCache[id][_id], prev = ref[0], curr = ref[1];
          if ((prev != null) && (curr != null)) {
            raked = Signal.fft_smart_overwrap_correlation(prev, curr);
          } else {
            raked = null;
          }
          ref1 = Signal.Statictics.findMax(correl), max_score = ref1[0], max_offset = ref1[1];
          pulseTime = (startPtr + max_offset) / sampleRate;
          return {
            id: _id,
            section: section,
            correl: correl,
            max_score: max_score,
            max_offset: max_offset,
            pulseTime: pulseTime,
            raked: raked
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
      aliases = datas.reduce((function(o, arg) {
        var alias, id;
        id = arg.id, alias = arg.alias;
        o[id] = alias;
        return o;
      }), {});
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
      setTimeout(function() {
        var basePt, frame_, render;
        frame_ = _craetePictureFrame("");
        document.body.appendChild(frame_.element);
        results.forEach(function(arg) {
          var alias, frame, id, results, sampleRate;
          id = arg.id, alias = arg.alias, results = arg.results, sampleRate = arg.sampleRate;
          frame = _craetePictureFrame(alias + "@" + id);
          frame_.add(frame.element);
          return results.forEach(function(arg1) {
            var _frame, _id, correl, max_offset, offset_arr, raked, render, section, zoomarr;
            _id = arg1.id, section = arg1.section, correl = arg1.correl, max_offset = arg1.max_offset, raked = arg1.raked;
            _frame = _craetePictureFrame(aliases[id] + "<->" + aliases[_id]);
            frame.add(_frame.element);
            _frame.add(distances[id][_id] + "m");
            render = new Signal.Render(VIEW_SIZE, 127);
            render.drawSignal(section, true, true);
            _frame.add(render.element);
            render = new Signal.Render(VIEW_SIZE, 12);
            offset_arr = new Uint8Array(correl.length);
            offset_arr[max_offset - RANGE] = 255;
            offset_arr[max_offset] = 255;
            offset_arr[max_offset + RANGE] = 255;
            render.ctx.strokeStyle = "red";
            render.drawSignal(offset_arr, true, true);
            _frame.add(render.element);
            render = new Signal.Render(VIEW_SIZE, 127);
            render.drawSignal(correl, true, true);
            _frame.add(render.element);
            zoomarr = correl.subarray(max_offset - RANGE, max_offset + RANGE);
            render = new Signal.Render(VIEW_SIZE, 127);
            render.drawSignal(zoomarr, true, true);
            _frame.add(render.element);
            render = new Signal.Render(VIEW_SIZE, 12);
            offset_arr = new Uint8Array(zoomarr.length);
            offset_arr[RANGE] = 255;
            render.ctx.strokeStyle = "red";
            render.drawSignal(offset_arr, true, true);
            _frame.add(render.element);
            if (raked != null) {
              render = new Signal.Render(VIEW_SIZE, 127);
              render.drawSignal(raked, true, true);
              return _frame.add(render.element);
            }
          });
        });
        render = new Signal.Render(Math.pow(2, 8), Math.pow(2, 8));
        basePt = sdm.points[0];
        sdm.points.forEach(function(pt) {
          return render.cross(render.cnv.width / 2 + (pt.x - basePt.x) * 10, render.cnv.height / 2 + (pt.y - basePt.y) * 10, 16);
        });
        frame_.add(render.element);
        return document.body.style.backgroundColor = "lime";
      });
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
