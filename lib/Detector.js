// Generated by CoffeeScript 1.10.0
(function() {
  var OSC, Signal, SignalViewer, Statistics, __MULTIPASS_DISTANCE__, __SOUND_OF_SPEED__;

  SignalViewer = window["duxca"]["lib"]["SignalViewer"];

  Signal = window["duxca"]["lib"]["Signal"];

  Statistics = window["duxca"]["lib"]["Statistics"];

  OSC = window["duxca"]["lib"]["OSC"];

  __MULTIPASS_DISTANCE__ = 9;

  __SOUND_OF_SPEED__ = 340;

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
        case "barker":
          return this.init_barker(data, next);
        case "chirp":
          return this.init_chirp(data, next);
        case "barkerCodedChirp":
          return this.init_barkerCodedChirp(data, next);
        case "mseq":
          return this.init_mseq(data, next);
        default:
          throw new Error("uknown pulse type " + pulseType);
      }
    };

    Detector.prototype.init_barker = function(arg, next) {
      var barker, carrierFreq;
      carrierFreq = arg.carrierFreq;
      barker = Signal.createBarkerCode(13);
      this.matchedA = Signal.BPSK(barker, carrierFreq, this.actx.sampleRate, 0);
      this.abuf = this.osc.createAudioBufferFromArrayBuffer(this.matchedA, this.actx.sampleRate);
      return next();
    };

    Detector.prototype.init_chirp = function(arg, next) {
      var chirp, length;
      length = arg.length;
      chirp = Signal.createChirpSignal(length);
      this.matchedA = chirp;
      this.abuf = this.osc.createAudioBufferFromArrayBuffer(this.matchedA, this.actx.sampleRate);
      return next();
    };

    Detector.prototype.init_barkerCodedChirp = function(arg, next) {
      var bcc, length;
      length = arg.length;
      bcc = Signal.createBarkerCodedChirp(13, length);
      this.matchedA = bcc;
      this.abuf = this.osc.createAudioBufferFromArrayBuffer(this.matchedA, this.actx.sampleRate);
      return next();
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
      var matchedA, matchedB, pulseType, result, sampleRate, slideWidth, windowSize;
      if (opt == null) {
        opt = {};
      }

      /*
      startStops: {
        id:       string,
        startPtr: number,
        stopPtr:  number
      }
       */
      sampleRate = opt.sampleRate;
      if (sampleRate == null) {
        sampleRate = this.actx.sampleRate;
      }
      pulseType = this.pulseType;
      windowSize = Math.pow(2, 8);
      slideWidth = Math.pow(2, 4);
      matchedA = this.matchedA;
      matchedB = this.matchedB;
      result = (function() {
        switch (this.pulseType) {
          case "barker":
            return startStops.map(this.calc_barker(f32arr, sampleRate, matchedA));
          case "chirp":
            return startStops.map(this.calc_chirp(f32arr, sampleRate, matchedA));
          case "barkerCodedChirp":
            return startStops.map(this.calc_barkerCodedChirp(f32arr, sampleRate, matchedA));
          case "mseq":
            return startStops.map(this.calc_mseq(f32arr, sampleRate, matchedA, matchedB));
          default:
            throw new Error("uknown pulse type " + pulseType);
        }
      }).call(this);
      return Promise.resolve(result);
    };

    Detector.prototype.calc_barker = function(rawdata, sampleRate, matchedA) {
      return (function(_this) {
        return function(arg) {
          var correlA, counter, filename_head, id, idxA, images, marker, maxA, max_offset, max_val, pulseTime, range, ref, section, startPtr, stopPtr, zoomA;
          id = arg.id, startPtr = arg.startPtr, stopPtr = arg.stopPtr;
          counter = 0;
          images = {};
          filename_head = "-TO-" + id + "_";
          section = rawdata.subarray(startPtr, stopPtr);
          correlA = Signal.fft_smart_overwrap_correlation(section, matchedA);
          images[filename_head + ((counter++) + "section")] = section;
          images[filename_head + ((counter++) + "correlA")] = correlA;
          ref = Statistics.findMax(correlA), maxA = ref[0], idxA = ref[1];
          range = (__MULTIPASS_DISTANCE__ / __SOUND_OF_SPEED__ * sampleRate) | 0;
          marker = new Uint8Array(correlA.length);
          while (idxA - range < 0) {
            range /= 2;
          }
          marker[idxA - range] = 255;
          marker[idxA] = 255;
          marker[idxA + range] = 255;
          images[filename_head + ((counter++) + "marker")] = marker;
          zoomA = correlA.subarray(idxA - range, idxA + range);
          images[filename_head + ((counter++) + "zoomA")] = zoomA;
          max_offset = idxA;
          pulseTime = (startPtr + max_offset) / sampleRate;
          max_val = maxA;
          return {
            images: images,
            pulseInfo: {
              id: id,
              max_offset: max_offset,
              pulseTime: pulseTime,
              max_val: max_val
            }
          };
        };
      })(this);
    };

    Detector.prototype.calc_chirp = function(rawdata, sampleRate, matchedA) {
      return (function(_this) {
        return function(arg) {
          var id, startPtr, stopPtr;
          id = arg.id, startPtr = arg.startPtr, stopPtr = arg.stopPtr;
          return _this.calc_barker(rawdata, sampleRate, matchedA)({
            id: id,
            startPtr: startPtr,
            stopPtr: stopPtr
          });
        };
      })(this);
    };

    Detector.prototype.calc_barkerCodedChirp = function(rawdata, sampleRate, matchedA) {
      return (function(_this) {
        return function(arg) {
          var id, startPtr, stopPtr;
          id = arg.id, startPtr = arg.startPtr, stopPtr = arg.stopPtr;
          return _this.calc_barker(rawdata, sampleRate, matchedA)({
            id: id,
            startPtr: startPtr,
            stopPtr: stopPtr
          });
        };
      })(this);
    };

    Detector.prototype.calc_mseq = function(rawdata, sampleRate, matchedA, matchedB) {
      return (function(_this) {
        return function(arg) {
          var _, _idx, correl, correlA, correlB, counter, filename_head, i, id, idx, idxA, idxB, images, logs, lowpass, marker, marker2, max, maxA, maxB, max_offset, max_val, pulseTime, range, ref, ref1, ref2, ref3, ref4, relA, relB, scoreA, scoreB, section, slidewidth, startPtr, stdscoreA, stdscoreB, stopPtr, val, windowsize, zoom, zoomA, zoomB;
          id = arg.id, startPtr = arg.startPtr, stopPtr = arg.stopPtr;
          images = {};
          counter = 0;
          filename_head = "-TO-" + id + "_";
          section = rawdata.subarray(startPtr, stopPtr);
          correlA = Signal.fft_smart_overwrap_correlation(section, matchedA);
          correlB = Signal.fft_smart_overwrap_correlation(section, matchedB);
          images[filename_head + ((counter++) + "section")] = section;
          images[filename_head + ((counter++) + "correlA")] = correlA;
          images[filename_head + ((counter++) + "correlB")] = correlB;
          ref = Statistics.findMax(correlA), _ = ref[0], idxA = ref[1];
          ref1 = Statistics.findMax(correlB), _ = ref1[0], idxB = ref1[1];
          relB = idxA + matchedA.length * 2;
          if (relB < 0) {
            relB = 0;
          }
          relA = idxB - matchedA.length * 2;
          if (relA < 0) {
            relA = 0;
          }
          stdscoreA = (function() {
            var ave, vari;
            ave = Statistics.average(correlA);
            vari = Statistics.variance(correlA);
            if (vari === 0) {
              vari = 0.000001;
            }
            return function(x) {
              return 10 * (x - ave) / vari + 50;
            };
          })();
          stdscoreB = (function() {
            var ave, vari;
            ave = Statistics.average(correlB);
            vari = Statistics.variance(correlB);
            if (vari === 0) {
              vari = 0.000001;
            }
            return function(x) {
              return 10 * (x - ave) / vari + 50;
            };
          })();
          scoreB = stdscoreB(correlB[idxB]) + stdscoreA(correlA[relA]);
          scoreA = stdscoreA(correlA[idxA]) + stdscoreB(correlB[relB]);
          range = (__MULTIPASS_DISTANCE__ / __SOUND_OF_SPEED__ * sampleRate) | 0;
          if (relA > 0 && scoreB > scoreA) {
            ref2 = Statistics.findMax(correlA.subarray(relA - range, relA + range)), _ = ref2[0], idx = ref2[1];
            idxA = relA - range + idx;
          } else {
            ref3 = Statistics.findMax(correlB.subarray(relB - range, relB + range)), _ = ref3[0], idx = ref3[1];
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
          images[filename_head + ((counter++) + "marker")] = marker;
          zoomA = correlA.subarray(idxA - range, idxA + range);
          zoomB = correlB.subarray(idxB - range, idxB + range);
          images[filename_head + ((counter++) + "zoomA")] = zoomA;
          images[filename_head + ((counter++) + "zoomB")] = zoomB;
          correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB);
          images[filename_head + ((counter++) + "correl")] = correl;
          zoom = zoomA.map(function(_, i) {
            return zoomA[i] * zoomB[i];
          });
          logs = new Float32Array(zoom.length);
          windowsize = (0.6 / __SOUND_OF_SPEED__ * sampleRate) | 0;
          slidewidth = 1;
          i = 0;
          while (zoomA.length > i + windowsize) {
            val = zoom.subarray(i, i + windowsize).reduce((function(sum, v, i) {
              return sum + v;
            }), 0);
            logs[i] = val;
            i += slidewidth;
          }
          images[filename_head + ((counter++) + "logs")] = logs;
          lowpass = Signal.lowpass(logs, sampleRate, 800, 1);
          images[filename_head + ((counter++) + "lowpass")] = lowpass;
          ref4 = Statistics.findMax(lowpass), max = ref4[0], _idx = ref4[1];
          i = 1;
          while (i < _idx && lowpass[i] < max / 5) {
            i++;
          }
          while (i < _idx && lowpass[i] > lowpass[i - 1]) {
            i++;
          }
          idx = i;
          marker2 = new Uint8Array(logs.length);
          marker2[idx] = 255;
          images[filename_head + ((counter++) + "marker2")] = marker2;
          max_offset = idx + (idxA - range);
          pulseTime = (startPtr + max_offset) / sampleRate;
          max_val = (maxA + maxB) / 2;
          return {
            images: images,
            pulseInfo: {
              id: id,
              max_offset: max_offset,
              pulseTime: pulseTime,
              max_val: max_val
            }
          };
        };
      })(this);
    };

    Detector.prototype.distribute = function(datas) {

      /*
      datas: {
        [index: number]: {
          id:           string,
          alias:        string,
          sampleRate:   number,
          recStartTime: number,
          recStopTime:  number,
          startStops: {
            [index: number]: {
              id:       string,
              startPtr: string,
              stopPtr:  string}},
          pulseInfos: {
            [index: number]: {
              id        : string,
              max_offset: number,
              pulseTime : number,
              max_val   : number}}}}
       */
      var aliases, delayTimes, distances, pulseTimes, recStartTimes, recStopTimes, relDelayTimes, sampleRates;
      console.log(datas);
      pulseTimes = {};
      relDelayTimes = {};
      delayTimes = {};
      distances = {};
      aliases = datas.reduce((function(o, arg) {
        var alias, id;
        id = arg.id, alias = arg.alias;
        o[id] = alias;
        return o;
      }), {});
      sampleRates = datas.reduce((function(o, arg) {
        var alias, sampleRate;
        alias = arg.alias, sampleRate = arg.sampleRate;
        o[alias] = sampleRate;
        return o;
      }), {});
      recStartTimes = datas.reduce((function(o, arg) {
        var alias, recStartTime;
        alias = arg.alias, recStartTime = arg.recStartTime;
        o[alias] = recStartTime;
        return o;
      }), {});
      recStopTimes = datas.reduce((function(o, arg) {
        var alias, recStopTime;
        alias = arg.alias, recStopTime = arg.recStopTime;
        o[alias] = recStopTime;
        return o;
      }), {});
      datas.forEach(function(arg) {
        var alias, id1, pulseInfos;
        id1 = arg.id, alias = arg.alias, pulseInfos = arg.pulseInfos;
        return pulseInfos.forEach(function(arg1) {
          var id2, pulseTime;
          id2 = arg1.id, pulseTime = arg1.pulseTime;
          pulseTimes[aliases[id1]] = pulseTimes[aliases[id1]] || {};
          return pulseTimes[aliases[id1]][aliases[id2]] = pulseTime;
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
          return distances[id1][id2] = Math.abs(delayTimes[id1][id2]) / 2 * __SOUND_OF_SPEED__;
        });
      });
      console.group("table");
      console.info("aliases", aliases);
      console.info("sampleRates", sampleRates);
      console.info("recStartTimes", recStartTimes);
      console.info("recStopTimes", recStopTimes);
      console.info("pulseTimes");
      console.table(pulseTimes);
      console.info("relDelayTimes");
      console.table(relDelayTimes);
      console.info("delayTimes");
      console.table(delayTimes);
      console.info("distances");
      console.table(distances);
      console.groupEnd();
      return {
        aliases: aliases,
        sampleRates: sampleRates,
        recStartTimes: recStartTimes,
        recStopTimes: recStopTimes,
        pulseTimes: pulseTimes,
        relDelayTimes: relDelayTimes,
        delayTimes: delayTimes,
        distances: distances
      };
    };

    return Detector;

  })();

}).call(this);
