// Generated by CoffeeScript 1.10.0
(function() {
  var MULTIPASS_DISTANCE, SOUND_OF_SPEED, VIEW_SIZE, _craetePictureFrame, calc, socket;

  window["socket"] = socket = io(location.hostname + ":" + location.port + "/calc");

  socket.on("connect", console.info.bind(console, "connect"));

  socket.on("reconnect", console.info.bind(console, "reconnect"));

  socket.on("reconnect_attempt", console.info.bind(console, "reconnect_attempt"));

  socket.on("reconnecting", console.info.bind(console, "reconnecting"));

  socket.on("reconnect_error", console.info.bind(console, "reconnect_error"));

  socket.on("reconnect_failed", console.info.bind(console, "reconnect_failed"));

  socket.on("disconnect", console.info.bind(console, "disconnect"));

  socket.on("error", console.info.bind(console, "error"));

  MULTIPASS_DISTANCE = 9;

  SOUND_OF_SPEED = 340;

  socket.on("calc", function(a) {
    return calc(a)(function(a) {
      socket.emit("calc", a);
      return setTimeout((function() {
        return location.reload();
      }), 2000);
    });
  });

  calc = function(datas) {
    return function(next) {
      var TIME_DATA, aliases, currentTimes, delayTimes, delayTimesAliased, distances, distancesAliased, frame, max_vals, max_valsAliased, now, pulseTimes, pulseTimesAliased, recStartTimes, relDelayTimes, relDelayTimesAliased, results, sampleRates;
      if (datas.length === 0) {
        return next();
      }
      now = Date.now();
      frame = _craetePictureFrame("calc", document.body);
      aliases = datas.reduce((function(o, arg) {
        var alias, id;
        id = arg.id, alias = arg.alias;
        o[id] = alias;
        return o;
      }), {});
      results = datas.map(function(arg) {
        var DSSS_SPEC, _frame, _results, alias, carrier_freq, chirp, id, length, matchedA, matchedB, recF32arr, sampleRate, seedA, seedB, startStops;
        id = arg.id, alias = arg.alias, startStops = arg.startStops, recF32arr = arg.recF32arr, DSSS_SPEC = arg.DSSS_SPEC, sampleRate = arg.sampleRate;
        length = DSSS_SPEC.length, seedA = DSSS_SPEC.seedA, seedB = DSSS_SPEC.seedB, carrier_freq = DSSS_SPEC.carrier_freq, chirp = DSSS_SPEC.chirp;
        _frame = _craetePictureFrame(alias + "@" + id);
        frame.add(_frame.element);
        chirp = new Float32Array(chirp);
        matchedA = chirp;
        matchedB = chirp;
        recF32arr = new Float32Array(recF32arr);
        console.log(recF32arr.length, alias);
        _results = startStops.map(function(arg1) {
          var _, __frame, _id, _idx, _logs, correl, correlA, i, idx, idxA, idxB, logs, marker, max, maxA, maxB, max_offset, max_val, pulseTime, range, rawdata, ref, ref1, relA, relB, scoreA, scoreB, section, slidewidth, startPtr, stdscoreA, stdscoreB, stopPtr, val, windowsize, zoom, zoomA, zoomB;
          _id = arg1.id, startPtr = arg1.startPtr, stopPtr = arg1.stopPtr;
          console.log(_id, startPtr, stopPtr, recF32arr[0]);
          __frame = _craetePictureFrame(aliases[id] + "<->" + aliases[_id]);
          _frame.add(__frame.element);
          rawdata = section = recF32arr.subarray(startPtr, stopPtr);
          correlA = Signal.fft_smart_overwrap_correlation(rawdata, matchedA);
          __frame.view(section, "section");
          __frame.view(correlA, "correlA");
          ref = Signal.Statictics.findMax(correlA), _ = ref[0], idxA = ref[1];
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
            idxA = relA;
          } else {
            idxB = relB;
          }
          console.log(maxA = correlA[idxA]);
          console.log(maxB = correlB[idxB]);
          marker = new Uint8Array(correlA.length);
          marker[idxA - range] = 255;
          marker[idxA] = 255;
          marker[idxA + range] = 255;
          marker[idxB - range] = 255;
          marker[idxB] = 255;
          marker[idxB + range] = 255;
          __frame.view(marker, "marker");
          zoomA = correlA.subarray(idxA - range, idxA + range);
          zoomB = correlB.subarray(idxB - range, idxB + range);
          __frame.view(zoomA, "zoomA");
          __frame.view(zoomB, "zoomB");
          correl = Signal.fft_smart_overwrap_correlation(zoomA, zoomB);
          __frame.view(correl, "correl");
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
          __frame.view(logs, "logs");
          _logs = Signal.lowpass(logs, sampleRate, 800, 1);
          __frame.view(_logs, "logs(lowpass)");
          ref1 = Signal.Statictics.findMax(_logs), max = ref1[0], _idx = ref1[1];
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
          __frame.view(marker, "marker");
          max_offset = idx + (idxA - range);
          pulseTime = (startPtr + max_offset) / sampleRate;
          max_val = (maxA + maxB) / 2;
          return {
            id: _id,
            max_offset: max_offset,
            pulseTime: pulseTime,
            max_val: max_val
          };
        });
        return {
          id: id,
          alias: alias,
          results: _results
        };
      });
      sampleRates = datas.reduce((function(o, arg) {
        var id, sampleRate;
        id = arg.id, sampleRate = arg.sampleRate;
        o[id] = sampleRate;
        return o;
      }), {});
      recStartTimes = datas.reduce((function(o, arg) {
        var id, recStartTime;
        id = arg.id, recStartTime = arg.recStartTime;
        o[id] = recStartTime;
        return o;
      }), {});
      currentTimes = datas.reduce((function(o, arg) {
        var currentTime, id;
        id = arg.id, currentTime = arg.currentTime;
        o[id] = currentTime;
        return o;
      }), {});
      pulseTimes = {};
      relDelayTimes = {};
      delayTimes = {};
      max_vals = {};
      distances = {};
      relDelayTimesAliased = {};
      distancesAliased = {};
      delayTimesAliased = {};
      pulseTimesAliased = {};
      max_valsAliased = {};
      results.forEach(function(arg) {
        var alias, id, results;
        id = arg.id, alias = arg.alias, results = arg.results;
        return results.forEach(function(arg1) {
          var _id, max_offset, max_val, pulseTime;
          _id = arg1.id, max_offset = arg1.max_offset, pulseTime = arg1.pulseTime, max_val = arg1.max_val;
          pulseTimes[id] = pulseTimes[id] || {};
          pulseTimes[id][_id] = pulseTime;
          pulseTimesAliased[aliases[id]] = pulseTimesAliased[aliases[id]] || {};
          return pulseTimesAliased[aliases[id]][aliases[_id]] = pulseTimes[id][_id];
        });
      });
      Object.keys(pulseTimes).forEach(function(id1) {
        return Object.keys(pulseTimes).forEach(function(id2) {
          relDelayTimes[id1] = relDelayTimes[id1] || {};
          relDelayTimes[id1][id2] = pulseTimes[id1][id2] - pulseTimes[id1][id1];
          relDelayTimesAliased[aliases[id1]] = relDelayTimesAliased[aliases[id1]] || {};
          return relDelayTimesAliased[aliases[id1]][aliases[id2]] = relDelayTimes[id1][id2];
        });
      });
      Object.keys(pulseTimes).forEach(function(id1) {
        return Object.keys(pulseTimes).forEach(function(id2) {
          delayTimes[id1] = delayTimes[id1] || {};
          delayTimes[id1][id2] = Math.abs(Math.abs(relDelayTimes[id1][id2]) - Math.abs(relDelayTimes[id2][id1]));
          delayTimesAliased[aliases[id1]] = delayTimesAliased[aliases[id1]] || {};
          delayTimesAliased[aliases[id1]][aliases[id2]] = delayTimes[id1][id2];
          distances[id1] = distances[id1] || {};
          distances[id1][id2] = Math.abs(delayTimes[id1][id2]) / 2 * SOUND_OF_SPEED;
          distancesAliased[aliases[id1]] = distancesAliased[aliases[id1]] || {};
          return distancesAliased[aliases[id1]][aliases[id2]] = distances[id1][id2];
        });
      });
      console.group("table");
      console.info("recStartTimes", recStartTimes);
      console.info("pulseTimesAliased");
      console.table(pulseTimesAliased);
      console.info("relDelayTimesAliased");
      console.table(relDelayTimesAliased);
      console.info("delayTimesAliased");
      console.table(delayTimesAliased);
      console.info("distancesAliased");
      console.table(distancesAliased);
      console.groupEnd();
      document.body.style.backgroundColor = "lime";
      console.log("TIME_DATA", TIME_DATA = {
        pulseTimes: pulseTimes,
        delayTimes: delayTimes,
        aliases: aliases,
        recStartTimes: recStartTimes,
        now: now,
        currentTimes: currentTimes,
        id: results[0].id,
        distances: distances,
        max_vals: max_vals
      });
      socket.emit("log", TIME_DATA);
      return next(TIME_DATA);
    };
  };

  VIEW_SIZE = Math.pow(2, 12);

  _craetePictureFrame = function(description, target) {
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
        __frame = _craetePictureFrame(title + ("(" + arr.length + ")"));
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
