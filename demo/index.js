// Generated by CoffeeScript 1.10.0
(function() {
  var DSSS_SPEC, __nextTick__, _prepareRec, actx, beepPulse, changeColor, gain, isRecording, main, n, osc, play, processor, pulseStartTime, pulseStopTime, ready, recbuf, sendRec, socket, startPulse, startRec, stopPulse, stopRec;

  window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia || window.navigator.mozGetUserMedia || window.navigator.getUserMedia;

  changeColor = function() {
    document.body.style.backgroundColor = location.hash.slice(1);
    return socket.emit("colors");
  };

  window.addEventListener("DOMContentLoaded", changeColor);

  window.addEventListener("hashchange", changeColor);

  window["socket"] = socket = io(location.hostname + ":" + location.port + "/node");

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
    return socket.emit("colors");
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

  gain = actx.createGain();

  gain.connect(actx.destination);

  processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1);

  recbuf = null;

  isRecording = false;

  pulseStartTime = {};

  pulseStopTime = {};

  DSSS_SPEC = null;

  __nextTick__ = null;

  main = function() {
    socket.on("color", function(a) {
      return socket.emit("color", {
        id: socket.id,
        color: location.hash.slice(1)
      });
    });
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
    socket.on("play", function(a) {
      return play(a);
    });
    return socket.on("volume", function(a) {
      return gain.gain.value = a[socket.id];
    });
  };

  n = function(a) {
    return a.split("").map(Number);
  };

  ready = function(arg) {
    var carrier_freq, length, seedA, seedB;
    length = arg.length, seedA = arg.seedA, seedB = arg.seedB, carrier_freq = arg.carrier_freq;
    return function(next) {
      var abuf, matchedA, matchedB, mseqA, mseqB, signal;
      document.body.style.backgroundColor = location.hash.slice(1);
      recbuf = new RecordBuffer(actx.sampleRate, processor.bufferSize, processor.channelCount);
      isRecording = false;
      pulseStartTime = {};
      pulseStopTime = {};
      DSSS_SPEC = null;
      __nextTick__ = null;
      mseqA = Signal.mseqGen(length, seedA);
      mseqB = Signal.mseqGen(length, seedB);
      matchedA = Signal.BPSK(mseqA, carrier_freq, actx.sampleRate, 0);
      matchedB = Signal.BPSK(mseqB, carrier_freq, actx.sampleRate, 0);
      signal = new Float32Array(matchedA.length * 2 + matchedB.length);
      signal.set(matchedA, 0);
      signal.set(matchedB, matchedA.length * 2);
      abuf = osc.createAudioBufferFromArrayBuffer(signal, actx.sampleRate);
      DSSS_SPEC = {
        abuf: abuf,
        length: length,
        seedA: seedA,
        seedB: seedB,
        carrier_freq: carrier_freq
      };
      return next();
    };
  };

  startRec = function(next) {
    isRecording = true;
    return __nextTick__ = function() {
      __nextTick__ = null;
      return next();
    };
  };

  startPulse = function(id) {
    return function(next) {
      pulseStartTime[id] = actx.currentTime;
      return next();
    };
  };

  beepPulse = function(next) {
    var abuf, anode, recur, startTime;
    abuf = DSSS_SPEC.abuf;
    startTime = actx.currentTime;
    anode = osc.createAudioNodeFromAudioBuffer(abuf);
    anode.connect(actx.destination);
    anode.start(startTime);
    return (recur = function() {
      if ((startTime + abuf.duration) < actx.currentTime) {
        return setTimeout(next, 100);
      } else {
        return setTimeout(recur, 100);
      }
    })();
  };

  stopPulse = function(id) {
    return function(next) {
      return __nextTick__ = function() {
        pulseStopTime[id] = actx.currentTime;
        __nextTick__ = null;
        return next();
      };
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
      startPtr = (pulseStartTime[id] - recStartTime) * recbuf.sampleRate | 0;
      stopPtr = (pulseStopTime[id] - recStartTime) * recbuf.sampleRate | 0;
      return {
        id: id,
        startPtr: startPtr,
        stopPtr: stopPtr
      };
    });
    o = {
      id: socket.id,
      recStartTime: recStartTime,
      recStopTime: recStopTime,
      alias: location.hash.slice(1),
      startStops: startStops,
      pulseStartTime: pulseStartTime,
      pulseStopTime: pulseStopTime,
      sampleTimes: recbuf.sampleTimes,
      sampleRate: actx.sampleRate,
      bufferSize: processor.bufferSize,
      channelCount: processor.channelCount,
      recF32arr: f32arr.buffer,
      DSSS_SPEC: DSSS_SPEC,
      currentTime: actx.currentTime
    };
    recbuf.clear();
    return next(o);
  };

  play = function(data) {
    var currentTimes, delayTimes, id, now, now2, offsetTime, pulseTimes, recStartTimes, wait;
    wait = data.wait, pulseTimes = data.pulseTimes, delayTimes = data.delayTimes, id = data.id, currentTimes = data.currentTimes, recStartTimes = data.recStartTimes, now = data.now, now2 = data.now2;
    offsetTime = recStartTimes[socket.id] + (pulseTimes[socket.id][id] - delayTimes[socket.id][id]) + (currentTimes[id] - (pulseTimes[id][id] + recStartTimes[id])) + (now2 - now) / 1000 + wait;
    return osc.createAudioBufferFromURL("./TellYourWorld1min.mp3").then(function(abuf) {
      var node;
      node = osc.createAudioNodeFromAudioBuffer(abuf);
      node.start(offsetTime + 1);
      node.loop = false;
      return node.connect(gain);
    });
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
          recbuf.add([new Float32Array(ev.inputBuffer.getChannelData(0))], actx.currentTime);
        }
        if (__nextTick__ != null) {
          return __nextTick__();
        }
      });
      return next();
    };
    return navigator.getUserMedia({
      video: false,
      audio: true
    }, right, left);
  };

  window.addEventListener("DOMContentLoaded", function() {
    return _prepareRec(function() {
      return main();
    });
  });

}).call(this);
