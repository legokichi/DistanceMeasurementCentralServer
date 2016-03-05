window.navigator["getUserMedia"] = window.navigator.webkitGetUserMedia ||
                                   window.navigator.mozGetUserMedia    ||
                                   window.navigator.getUserMedia

{Chord} = P2PRingNet
chord = null
rootNodeId = null

setup = (next)->
  chord = new Chord({host: location.hostname, port: location.port, path: "peerjs", secure: true, debug: 3})
  window["chord"] = chord
  next()

main = (next)->
  if rootNodeId
  then ord.join(rootNodeId)
  else chord.create()
  next()

changeColor = ->
  document.body.style.backgroundColor = location.hash.slice(1)

window.addEventListener "DOMContentLoaded", -> setup -> main -> changeColor()
window.addEventListener("hashchange", changeColor)
