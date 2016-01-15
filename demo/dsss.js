// Generated by CoffeeScript 1.10.0
var DSSS_SPECS, VIEW_SIZE, _prepareRec, _prepareSpect, actx, analyser, beepPulse, changeColor, collect, isBroadcasting, isRecording, main, osc, processor, pulseStartTime, pulseStopTime, ready, recbuf, sendRec, socket, startPulse, startRec, stopPulse, stopRec;

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

actx = new AudioContext();

osc = new OSC(actx);

analyser = actx.createAnalyser();

analyser.smoothingTimeConstant = 0;

analyser.fftSize = 512;

processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1);

recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount);

isRecording = false;

isBroadcasting = false;

pulseStartTime = {};

pulseStopTime = {};

DSSS_SPECS = [];

VIEW_SIZE = Math.pow(2, 10);

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

ready = function(data) {
  return function(next) {
    document.body.style.backgroundColor = location.hash.slice(1);
    recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount);
    isRecording = false;
    isBroadcasting = false;
    pulseStartTime = {};
    pulseStopTime = {};
    DSSS_SPECS = data[socket.id].map(function(arg, i) {
      var abuf, carrier_freq, encoded_data, length, matched, modulated_pulse, seedA, seedB, shift, ss_code;
      length = arg.length, seedA = arg.seedA, seedB = arg.seedB, shift = arg.shift, carrier_freq = arg.carrier_freq;
      ss_code = Signal.goldSeqGen(length, seedA, seedB, shift);
      encoded_data = Signal.encode_chipcode([1], ss_code);
      matched = Signal.BPSK(ss_code, carrier_freq, actx.sampleRate, 0);
      modulated_pulse = Signal.BPSK(encoded_data, carrier_freq, actx.sampleRate, 0, encoded_data.length * (1 / carrier_freq) * actx.sampleRate);
      abuf = osc.createAudioBufferFromArrayBuffer(modulated_pulse, actx.sampleRate);
      return {
        abuf: abuf,
        delay: 0.1 * i,
        matched: matched.buffer,
        ss_code: ss_code,
        carrier_freq: carrier_freq,
        modulated_pulse_length: modulated_pulse.length
      };
    });
    return next();
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
  return Promise.all(DSSS_SPECS.map(function(arg) {
    var abuf, anode, delay, modulated_pulse_length;
    abuf = arg.abuf, delay = arg.delay, modulated_pulse_length = arg.modulated_pulse_length;
    anode = osc.createAudioNodeFromAudioBuffer(abuf);
    anode.connect(actx.destination);
    anode.start(actx.currentTime + delay);
    return new Promise(function(resolve, reject) {
      var recur;
      return setTimeout((recur = function() {
        if (recbuf.chsBuffers[0].length > Math.ceil(modulated_pulse_length / processor.bufferSize)) {
          return resolve();
        } else {
          return setTimeout(recur, 100);
        }
      }), (modulated_pulse_length / actx.sampleRate + delay) * 1000);
    });
  }))["catch"](function(err) {
    return window.onerror(err);
  }).then(function() {
    return next();
  });
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
    DSSS_SPECS: DSSS_SPECS
  };
  recbuf.clear();
  return next(o);
};

collect = function(datas) {
  return function(next) {
    var aliases, delayTimes, distances, distancesAliased, pulseTimes, relDelayTimes, results;
    if (location.hash.slice(1) !== "red") {
      return next();
    }
    console.info("calc");
    console.time("calc");
    results = datas.map(function(arg) {
      var DSSS_SPECS, _results, alias, id, recF32arr, sampleRate, startStops;
      id = arg.id, alias = arg.alias, startStops = arg.startStops, recF32arr = arg.recF32arr, DSSS_SPECS = arg.DSSS_SPECS, sampleRate = arg.sampleRate;
      _results = startStops.map(function(arg1) {
        var __results, _id, section, startPtr, stopPtr;
        _id = arg1.id, startPtr = arg1.startPtr, stopPtr = arg1.stopPtr;
        section = new Float32Array(recF32arr).subarray(startPtr, stopPtr);
        __results = DSSS_SPECS.map(function(arg2, i) {
          var carrier_freq, correl, matched, max_offset, max_score, pulseTime, ref, stdev, stdscore;
          matched = arg2.matched, carrier_freq = arg2.carrier_freq;
          correl = Signal.fft_smart_overwrap_correlation(section, new Float32Array(matched));
          ref = Signal.Statictics.findMax(correl), max_score = ref[0], max_offset = ref[1];
          stdev = Signal.Statictics.stdev(correl);
          stdscore = Signal.Statictics.stdscore(correl, max_score);
          pulseTime = (startPtr + max_offset) / sampleRate;
          return {
            correl: correl,
            max_score: max_score,
            max_offset: max_offset,
            stdev: stdev,
            stdscore: stdscore,
            pulseTime: pulseTime
          };
        });
        return {
          id: _id,
          section: section,
          results: __results
        };
      });
      return {
        id: id,
        alias: alias,
        results: _results
      };
    });
    console.timeEnd("calc");
    aliases = datas.reduce((function(o, arg) {
      var alias, id;
      id = arg.id, alias = arg.alias;
      o[id] = alias;
      return o;
    }), {});
    console.info("afterCalc");
    console.time("afterCalc");
    pulseTimes = {};
    relDelayTimes = {};
    delayTimes = {};
    distances = {};
    distancesAliased = {};
    results.forEach(function(arg) {
      var alias, id, results;
      id = arg.id, alias = arg.alias, results = arg.results;
      return results.forEach(function(arg1) {
        var _id, results, section;
        _id = arg1.id, section = arg1.section, results = arg1.results;
        pulseTimes[id] = pulseTimes[id] || {};
        pulseTimes[id][_id] = [];
        return results.forEach(function(arg2, i) {
          var correl, max_offset, max_score, pulseTime, stdev, stdscore;
          correl = arg2.correl, max_score = arg2.max_score, max_offset = arg2.max_offset, stdev = arg2.stdev, stdscore = arg2.stdscore, pulseTime = arg2.pulseTime;
          return pulseTimes[id][_id][i] = pulseTime;
        });
      });
    });
    Object.keys(pulseTimes).forEach(function(id1) {
      return Object.keys(pulseTimes).forEach(function(id2) {
        relDelayTimes[id1] = relDelayTimes[id1] || {};
        relDelayTimes[id1][id2] = [];
        return pulseTimes[id1][id2].forEach(function(_, i) {
          return relDelayTimes[id1][id2][i] = pulseTimes[id1][id2][i] - pulseTimes[id1][id1][i];
        });
      });
    });
    Object.keys(pulseTimes).forEach(function(id1) {
      return Object.keys(pulseTimes).forEach(function(id2) {
        delayTimes[id1] = delayTimes[id1] || {};
        delayTimes[id1][id2] = [];
        distances[id1] = distances[id1] || {};
        distances[id1][id2] = [];
        distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {};
        distancesAliased[aliases[id1]][aliases[id2]] = [];
        return pulseTimes[id1][id2].forEach(function(_, i) {
          delayTimes[id1][id2][i] = Math.abs(Math.abs(relDelayTimes[id1][id2][i]) - Math.abs(relDelayTimes[id2][id1][i]));
          distances[id1][id2][i] = delayTimes[id1][id2][i] / 2 * 340;
          return distancesAliased[aliases[id1]][aliases[id2]][i] = distances[id1][id2][i];
        });
      });
    });
    console.timeEnd("afterCalc");
    console.info("distancesAliased", distancesAliased);
    setTimeout(function() {
      results.forEach(function(arg) {
        var alias, id, results;
        id = arg.id, alias = arg.alias, results = arg.results;
        return results.forEach(function(arg1) {
          var _id, render, results, section;
          _id = arg1.id, section = arg1.section, results = arg1.results;
          document.body.appendChild(document.createTextNode(aliases[id] + "<->" + aliases[_id]));
          render = new Signal.Render(VIEW_SIZE, 127);
          render.drawSignal(section, true, true);
          document.body.appendChild(render.element);
          return results.forEach(function(arg2, i) {
            var RANGE, correl, max_offset, offset_arr, zoomarr;
            correl = arg2.correl, max_offset = arg2.max_offset;
            document.body.appendChild(document.createTextNode(aliases[id] + "<-" + i + "->" + aliases[_id]));
            render = new Signal.Render(VIEW_SIZE, 127);
            render.drawSignal(correl, true, true);
            document.body.appendChild(render.element);
            RANGE = 512;
            render = new Signal.Render(VIEW_SIZE, 12);
            offset_arr = new Uint8Array(correl.length);
            offset_arr[max_offset - RANGE] = 255;
            offset_arr[max_offset] = 255;
            offset_arr[max_offset + RANGE] = 255;
            render.ctx.strokeStyle = "red";
            render.drawSignal(offset_arr, true, true);
            document.body.appendChild(render.element);
            zoomarr = correl.subarray(max_offset - RANGE, max_offset + RANGE);
            render = new Signal.Render(VIEW_SIZE, 127);
            render.drawSignal(zoomarr, true, true);
            document.body.appendChild(render.element);
            render = new Signal.Render(VIEW_SIZE, 12);
            offset_arr = new Uint8Array(zoomarr.length);
            offset_arr[RANGE] = 255;
            render.ctx.strokeStyle = "red";
            render.drawSignal(offset_arr, true, true);
            return document.body.appendChild(render.element);
          });
        });
      });
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
  var donot, i, render, rndr, spectrums;
  spectrums = (function() {
    var j, ref, results1;
    results1 = [];
    for (i = j = 0, ref = analyser.frequencyBinCount; 0 <= ref ? j <= ref : j >= ref; i = 0 <= ref ? ++j : --j) {
      results1.push(new Uint8Array(analyser.frequencyBinCount));
    }
    return results1;
  })();
  rndr = new Signal.Render(spectrums.length, spectrums[0].length);
  donot = render = function() {
    var spectrum;
    spectrum = spectrums.shift();
    analyser.getByteFrequencyData(spectrum);
    spectrums.push(spectrum);
    rndr.drawSpectrogram(spectrums);
    return requestAnimationFrame(render);
  };
  return next();
};

window.addEventListener("DOMContentLoaded", function() {
  return _prepareRec(function() {
    return _prepareSpect(function() {
      return main();
    });
  });
});
