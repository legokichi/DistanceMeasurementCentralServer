// Generated by CoffeeScript 1.10.0
(function() {
  var actx, input_processor, left, n, osc, output_processor, pn, right, socket, tse;

  window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia || window.navigator.mozGetUserMedia || window.navigator.getUserMedia;

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

  this.view = function(arr, w, h) {
    var _view;
    if (w == null) {
      w = arr.length;
    }
    if (h == null) {
      h = 128;
    }
    _view = new SignalViewer(w, h);
    _view.draw(arr);
    return document.body.appendChild(_view.cnv);
  };

  n = function(a) {
    return a.split("").map(Number);
  };

  actx = new AudioContext();

  osc = new OSC(actx);

  output_processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1);

  output_processor.connect(actx.destination);

  input_processor = actx.createScriptProcessor(Math.pow(2, 14), 1, 1);

  input_processor.connect(actx.destination);

  pn = new Float32Array(Signal.mseqGen(14, n("11000000000101")));

  tse = new TimeSpreadEcho(pn, output_processor.bufferSize);

  output_processor.addEventListener("audioprocess", function(ev) {
    var buffer;
    buffer = ev.inputBuffer.getChannelData(0);
    tse.encode(buffer);
    return ev.outputBuffer.getChannelData(0).set(buffer, 0);
  });

  left = function(err) {
    throw err;
  };

  right = function(stream) {
    var source;
    source = actx.createMediaStreamSource(stream);
    source.connect(input_processor);
    input_processor.connect(actx.destination);
    return input_processor.addEventListener("audioprocess", function(ev) {
      var buffer;
      buffer = ev.inputBuffer.getChannelData(0);
      return console.log(tse.decode(buffer));
    });
  };

  navigator.getUserMedia({
    video: false,
    audio: true
  }, right, left);

  osc.createAudioBufferFromURL("TellYourWorld1min.mp3").then(function(abuf) {
    var anode;
    anode = osc.createAudioNodeFromAudioBuffer(abuf);
    anode.connect(output_processor);
    return anode.start(actx.currentTime);
  });

}).call(this);
