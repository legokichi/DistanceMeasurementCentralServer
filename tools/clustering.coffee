cp = require 'child_process'
fs     = require 'fs'

o = fs.readdirSync(".")
.map (a)-> [(/^(\d+)/.exec(a) || [null, ""])[1], a]
.reduce(((o,[a,b])->o[a]?=[];o[a].push(b);o), {})
Object.keys(o).forEach (a)->
  [name] = o[a].filter (a)-> /^\d+\_[A-Za-z]+\.json$/.test(a)
  unless name? then return
  name = name.replace(/\.json$/, ".zip")
  contents = o[a].filter (a)-> /^(\d+)\_(\d+)\_collect/.test(a)
  console.log name, contents
  if contents.length is 0 then return
  console.log cp.execSync("zip -9 -v #{name} #{contents.join(" ")}")
  contents.forEach (path)-> console.log fs.unlinkSync(path)
