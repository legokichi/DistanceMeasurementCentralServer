// Generated by CoffeeScript 1.10.0
(function() {
  var PYTHON_IMPORT, TIME_DATA, _loop, api_router, app, bodyParser, calc, experimentID, express, formidable, fs, generateDetectionPythonCode, generateViewerPythonCode, io, isLooping, log, logs, play, request, requestLinear, requestParallel, server, serverStartID, start, stop;

  bodyParser = require('body-parser');

  formidable = require('formidable');

  express = require('express');

  app = express();

  server = require('http').Server(app);

  io = require('socket.io')(server);

  fs = require("fs");

  serverStartID = Date.now();

  experimentID = null;

  logs = [];

  log = function() {
    logs.push(Array.prototype.slice.call(arguments).join("\t"));
    return console.log.apply(console, arguments);
  };

  console.info("ServerStartID:", serverStartID);

  api_router = express.Router();

  api_router.get('/sockets', function(req, res) {
    return res.json(io.sockets.sockets.map(function(a) {
      return a.id;
    }));
  });

  api_router.get('/start', function(req, res) {
    res.statusCode = 204;
    res.send();
    return start();
  });

  api_router.get('/stop', function(req, res) {
    res.statusCode = 204;
    res.send();
    return stop();
  });

  api_router.get('/play', function(req, res) {
    res.statusCode = 204;
    res.send();
    return play();
  });

  api_router.post("/push", function(req, res) {
    var form;
    form = new formidable.IncomingForm();
    form.encoding = "utf-8";
    form.uploadDir = "./uploads";
    form.parse(req, function(err, fields, files) {
      var newPath, oldPath;
      console.info(err, fields, files);
      oldPath = './' + files.file._writeStream.path;
      newPath = './uploads/' + ServerStartID + "_" + Date.now() + "_" + files.file.name;
      return fs.rename(oldPath, newPath, function(err) {
        if (err) {
          throw err;
        }
      });
    });
    res.statusCode = 204;
    return res.send();
  });

  app.use(bodyParser.urlencoded({
    extended: true
  }));

  app.use(bodyParser.json());

  app.use('/api', api_router);

  app.use('/demo', express["static"](__dirname + '/../demo'));

  app.get("/", function(req, res) {
    return res.redirect(301, '/demo' + req.path);
  });

  io.on('connection', function(socket) {
    console.info("connection", socket.client.id);
    socket.on('echo', function(data) {
      return socket.emit("echo", data);
    });
    socket.on('event', console.info.bind(console, "event"));
    return socket.on('disconnect', console.info.bind(console, "disconnect"));
  });

  server.listen(8000);

  TIME_DATA = null;

  isLooping = false;

  stop = function() {
    isLooping = false;
    return console.log("stoped");
  };

  start = function() {
    console.log("started");
    if (!isLooping) {
      experimentID = Date.now();
      isLooping = true;
      _loop();
    } else {
      return console.log("already started");
    }
  };

  _loop = function() {
    var n;
    n = function(a) {
      return a.split("").map(Number);
    };
    return Promise.resolve().then(function() {
      return requestParallel("ready", {
        length: 12,
        seed: n("101101010111"),
        carrier_freq: 3000,
        isChirp: false,
        powL: 10,
        PULSE_N: 1
      });
    }).then(function() {
      return log("sockets", io.sockets.sockets.map(function(socket) {
        return socket.id;
      }));
    }).then(function() {
      return requestParallel("startRec");
    }).then(function() {
      var a, prms;
      prms = io.sockets.sockets.map(function(socket) {
        return function() {
          return Promise.resolve().then(function() {
            return requestParallel("startPulse", socket.id);
          }).then(function() {
            return request(socket, "beepPulse");
          }).then(function() {
            return log("beepPulse", socket.id);
          }).then(function() {
            return requestParallel("stopPulse", socket.id);
          });
        };
      });
      a = prms.reduce((function(a, b) {
        return a.then(function() {
          return b();
        });
      }), Promise.resolve());
      return a["catch"](function(err) {
        return error(err, err.stack);
      });
    }).then(function() {
      return requestParallel("stopRec");
    }).then(function() {
      return requestParallel("sendRec");
    }).then(function(datas) {
      calc(datas);
      return requestParallel("collect", datas);
    }).then(function(datas) {
      TIME_DATA = datas.filter(function(a) {
        return a != null;
      })[0];
      TIME_DATA.now = Date.now();
      return console.log("TIME_DATA", TIME_DATA);
    }).then(function() {
      return console.info("end");
    }).then(function() {
      if (isLooping) {
        return setTimeout(_loop);
      }
    })["catch"](function(err) {
      return console.error(err, err.stack);
    });
  };

  play = function() {
    console.log("TIME_DATA", TIME_DATA);
    TIME_DATA.wait = 2;
    TIME_DATA.now2 = Date.now();
    TIME_DATA.id = Object.keys(TIME_DATA.aliases).filter(function(id) {
      return TIME_DATA.aliases[id] = "red";
    })[0];
    return requestParallel("play", TIME_DATA).then(function() {
      return console.log("to play...");
    });
  };

  request = function(socket, eventName, data) {
    return new Promise(function(resolve, reject) {
      socket.on(eventName, function(data) {
        socket.removeAllListeners(eventName);
        return resolve(data);
      });
      return socket.emit(eventName, data);
    });
  };

  requestParallel = function(eventName, data) {
    var prms;
    log("requestParallel", eventName);
    prms = io.sockets.sockets.map(function(socket) {
      return request(socket, eventName, data);
    });
    return Promise.all(prms);
  };

  requestLinear = function(eventName) {
    var prms;
    log("requestLinear", eventName);
    prms = io.sockets.sockets.map(function(socket) {
      return function() {
        return request(socket, eventName, data);
      };
    });
    return prms.reduce((function(a, b) {
      return a.then(function() {
        return b();
      });
    }), Promise.resolve());
  };

  calc = function(datas, next) {
    var expHead;
    expHead = serverStartID + "_" + experimentID;
    datas.forEach(function(data) {
      var dataHead;
      return dataHead = expHead + "_" + data.id;
    });
    logs = [];
    return console.log(datas);
  };

  PYTHON_IMPORT = "# coding: utf-8\nimport matplotlib.pyplot as plt\nimport matplotlib.mlab as mlab\nimport numpy as np\nimport scipy as sp\nimport sys\nimport struct\ndef plot(fnmtx):\n    w = len(fnmtx[0])\n    h = len(fnmtx)\n    k = 1\n    for fnarr in fnmtx:\n        for fn in fnarr:\n            plt.subplot(w,h,k)\n            fn(k)\n            k += 1\ndef read_Float32Array_from_file(file_name):\n    f32arr = []\n    with open(file_name, \"rb\") as f:\n        while True:\n            data = f.read(4)\n            if not data: break\n            f32 = struct.unpack('f', data)\n            f32arr.append(f32[0])\n        return f32arr";

  generateViewerPythonCode = function(arg) {
    var fileName, sampleRate;
    fileName = arg.fileName, sampleRate = arg.sampleRate;
    return PYTHON_IMPORT + "\n\nfile_name = '" + fileName + "'\nsample_rate = " + sampleRate + "\n\nprint \"open:\" + file_name\nf32arr = read_Float32Array_from_file(file_name)\nprint len(f32arr)\n\ndef plotPulse(id):\n    plt.plot(xrange(len(f32arr)), f32arr)\ndef plotSpecgram(id):\n    nFFT=256\n    window=sp.hamming(nFFT)\n    Pxx,freqs, bins, im = plt.specgram(f32arr,\n                                       NFFT=nFFT, Fs=sample_rate,\n                                       noverlap=nFFT-1, window=mlab.window_hanning)\n\nplot([\n    [plotPulse, plotSpecgram]\n])\nplt.show()";
  };

  generateDetectionPythonCode = function(arg) {
    var machedFileName, recFileName, sampleRate;
    recFileName = arg.recFileName, machedFileName = arg.machedFileName, sampleRate = arg.sampleRate;
    return PYTHON_IMPORT + "\n\nrec_file_name = '" + recFileName + "'\npulse_file_name = '" + machedFileName + "'\nsample_rate = " + sampleRate + "\n\nrec_f32arr = read_Float32Array_from_file(rec_file_name)\npulse_f32arr = read_Float32Array_from_file(pulse_file_name)\n\ndef plotAutoCorrel(id):\n  a = np.correlate(pulse_f32arr, rec_f32arr, \"full\")\n  plt.plot(xrange(len(a)), a)\n\nplot([\n    [plotAutoCorrel]\n])\nplt.show()";
  };

}).call(this);
