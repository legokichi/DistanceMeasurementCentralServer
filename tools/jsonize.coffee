cp = require 'child_process'
fs = require 'fs'
reduce = (arr,id,f)-> arr.reduce(f,id)

datas = fs.readdirSync(".")
.filter (a)-> /^(\d+)/.test(a)
.map (dir)->
  ls = fs.readdirSync(dir)
  exps = reduce ls, [], (arr, file)->
    [_,exp,type]=(/^(\d+)\_([A-Za-z]+)\.json$/.exec(file)||[null,"",""])
    if exp isnt ""
      param = JSON.parse(fs.readFileSync(dir+"/"+file))
      arr.push({exp,type,dir,file,param})
    arr
  exps.map ({exp,type,dir,file,param})->
    reg = new RegExp "^#{exp}\\_(\\d+)\\_distribute\\_([A-Za-z]+)\\_([A-Za-z0-9_]+)\\.json$"+"|"+
                     "^#{exp}\\_#{type}\\_(\\d+)\\_distribute\\_([A-Za-z]+)\\_([A-Za-z0-9_]+)\\.json$"
    # old: 1458610989361_mseq_1458611014935_distribute_yellow_qrl47gnhuG7P7d-_AAAL.json
    # new: 1458353443732_1458353445381_distribute_red_LnrKdFxfrHfXMTN1AAAF.json
    distribute = ls.filter (file)-> reg.test(file)
    .map (file)->
      [_,timeStamp,color,id] = reg.exec(file)
      json = JSON.parse(fs.readFileSync(dir+"/"+file))
      {timeStamp,color,id,json}
    {exp,type,param,distribute}
.reduce (arr, a)-> arr.concat a

datas = datas.filter ({exp})-> exp > 1458359600000
types = reduce datas, {}, (o, a)-> {type}=a ;o[type] ?= []; o[type].push a; o
Object.keys(types).forEach (key)->
  iter = switch key
    when "barker" then (o, a)->
      {param: {carrierFreq}} = a
      o[carrierFreq] ?= []
      o[carrierFreq].push a
      o
    when "chirp" then (o, a)->
      {param: {length}} = a
      o[length] ?= []
      o[length].push a
      o
    when "barkerCodedChirp" then (o, a)->
      {param: {length}} = a
      o[length] ?= []
      o[length].push a
      o
    when "mseq" then (o, a)->
      {param: {carrierFreq, length}} = a
      o[carrierFreq+":"+length] ?= []
      o[carrierFreq+":"+length].push a
      o
  types[key] = reduce types[key], {}, iter

console.log JSON.stringify(types)
