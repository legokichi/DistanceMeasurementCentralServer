
{Chord} = P2PRingNet
chord = new Chord({host: location.hostname, port: location.port, path: "peerjs", secure: true, debug: 3})
window["chord"] = chord
rootNodeId = null

setup = (next)->
  next()

main = (next)->
  if rootNodeId then ord.join(rootNodeId) else chord.create()
  next()


window.addEventListener "DOMContentLoaded", -> setup -> main -> console.log "end"
