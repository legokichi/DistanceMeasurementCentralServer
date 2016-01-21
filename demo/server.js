// Generated by CoffeeScript 1.10.0
(function() {
  var app, bodyParser, express, formidable, io, log, logs, n, request, requestLinear, requestParallel, server, start;

  bodyParser = require('body-parser');

  formidable = require('formidable');

  express = require('express');

  app = express();

  server = require('http').Server(app);

  io = require('socket.io')(server);

  logs = [];

  log = function() {
    logs.push(Array.prototype.slice.call(arguments).join("\t"));
    return console.log.apply(console, arguments);
  };

  app.use(bodyParser.urlencoded({
    extended: true
  }));

  app.use(bodyParser.json());

  app.use('/', express["static"](__dirname + '/../demo'));

  io.of('/node').on('connection', function(socket) {
    socket.on('echo', function(data) {
      return socket.emit("echo", data);
    });
    socket.on('event', console.info.bind(console, "event"));
    socket.on('disconnect', console.info.bind(console, "disconnect"));
    return socket.on("colors", function(data) {
      return requestParallel("color").then(function(datas) {
        return io.of('/calc').emit("colors", datas);
      });
    });
  });

  io.of('/calc').on('connection', function(socket) {
    socket.on('echo', function(data) {
      return socket.emit("echo", data);
    });
    socket.on('event', console.info.bind(console, "event"));
    socket.on('disconnect', console.info.bind(console, "disconnect"));
    socket.on("volume", function(data) {
      return io.of('/node').sockets.map(function(socket) {
        return socket.emit("volume", data);
      });
    });
    socket.on("colors", function(data) {
      return requestParallel("color").then(function(datas) {
        return socket.emit("colors", datas);
      });
    });
    socket.on("start", function() {
      return start();
    });
    return socket.on("play", function(data) {
      console.log("play", data);
      return io.of('/node').emit("play", data);
    });
  });

  server.listen(8000);

  n = function(a) {
    return a.split("").map(Number);
  };

  start = function() {
    console.log("started");
    return Promise.resolve().then(function() {
      return requestParallel("ready", {
        length: 12,
        seed: n("111000011001"),
        carrier_freq: 2000
      });
    }).then(function() {
      return log("sockets", io.of('/node').sockets.map(function(socket) {
        return socket.id;
      }));
    }).then(function() {
      return requestParallel("startRec");
    }).then(function() {
      var a, prms;
      prms = io.of('/node').sockets.map(function(socket) {
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
      var socket, sockets;
      sockets = io.of('/calc').sockets;
      socket = sockets[sockets.length - 1];
      console.log("preCalc", datas, socket.id);
      return request(socket, "calc", datas);
    }).then(function() {
      return console.info("end");
    })["catch"](function(err) {
      return console.error(err, err.stack);
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
    prms = io.of('/node').sockets.map(function(socket) {
      return request(socket, eventName, data);
    });
    return Promise.all(prms);
  };

  requestLinear = function(eventName) {
    var prms;
    prms = io.of('/node').sockets.map(function(socket) {
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

}).call(this);
