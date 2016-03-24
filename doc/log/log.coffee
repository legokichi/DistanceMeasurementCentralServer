datas = require("./log.json")
console.clear()
console.log datas = datas.map ({start, calc, ui})-> [(new Date(start)).getTime(), calc, ui]
console.log datas = datas.map ([time, calc, ui])->
  o = []
  if calc?.aliases? && calc?.delayTimes? && calc?.distances?
    {aliases, delayTimes, distances} = calc
    Object.keys(delayTimes).forEach (id1)->
      Object.keys(delayTimes[id1]).forEach (id2)->
        o.push [aliases[id1], aliases[id2], delayTimes[id1][id2]]
  [time, o, ui]
console.log datas = datas.map ([time, delays, ui])->
  o = []
  if ui?.det?
    o.push ui.det
    ui.points.forEach ({x,y})->
      o.push [x, y]
  [time, delays, o]
console.log datas = datas.map ([time, delays, pos])->
  [time].concat(delays.reduce(((a,b)->a.concat(b)), []), pos.reduce(((a,b)->a.concat(b)), []))
console.log datas = datas.map (a)-> a.join(",")
console.log datas = datas.join("\n")
