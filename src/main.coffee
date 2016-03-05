window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

{Chord} = P2PRingNet
chord = null
joinNodeId = null

setup = (next)->
  id = location.hash.slice(1)
  chord = new Chord(id, {host: location.hostname, port: location.port, path: "peerjs", secure: true, debug: 3})
  window["chord"] = chord
  joinNodeId = location.search.slice(1)
  $("#joinNodeId").html(joinNodeId)
  $("#ping").click ->
    $("#ping").css("background-color", "yellow")
    chord.request("ping").then ->
      $("#ping").css("background-color", "lime")
  $("#reload").click -> chord.request("reload")
  $("#start").click -> start(chord)
  $("#play").click -> play(chord)
  next()

main = (next)->
  if joinNodeId
  then prm = chord.join(joinNodeId)
  else prm = chord.create()
  prm
  .then(initChord)
  .then(next)

initChord = (chord)->
  chord.on "ping", (token, cb)->
    console.log(token.payload.event, token.payload.data)
    cb(token)
  chord.on "ready",      (token, cb)-> cb()
  chord.on "startRec",   (token, cb)-> cb()
  chord.on "startPulse", (token, cb)-> cb()
  chord.on "beepPulse",  (token, cb)-> cb()
  chord.on "stopPulse",  (token, cb)-> cb()
  chord.on "stopRec",    (token, cb)-> cb()
  chord.on "collect",    (token, cb)-> cb()
  chord.on "distribute", (token, cb)-> cb()
  chord.on "play",       (token, cb)-> cb()
  chord.on "volume",     (token, cb)-> cb()
  chord.on "reload",     (token, cb)->
    console.log("aaaa")
    setTimeout(-> location.reload(), 1000); cb(token)

start = (chord)->
  chord.request("ready")
  .then (token)-> chord.request("startRec", null, token.route)
  .then (token)->
    token.payload.addressee.reduce((prm, id)->
      prm
      .then (token)-> chord.request("startPulse", id, token.payload.addressee)
      .then (token)-> chord.request("beepPulse", id, token.payload.addressee)
      .then (token)-> chord.request("stopPulse", id, token.payload.addressee)
    , Promise.resolve(token))
  .then (token)-> chord.request("stopRec", null, token.payload.addressee)
  .then (token)-> chord.request("collect", {}, token.payload.addressee)
  .then (token)-> chord.request("distribute", token.payload.data, token.payload.addressee)
  .then (token)-> chord.request("play", (Date.now()-token.time[0])*1.5/1000+1, token.payload.addressee)
  .then (token)-> console.info("end")


changeColor = ->
  document.body.style.backgroundColor = location.hash.slice(1)

window.addEventListener "DOMContentLoaded", -> setup -> main -> changeColor()
window.addEventListener("hashchange", changeColor)
