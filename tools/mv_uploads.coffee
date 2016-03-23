{exec} = require 'child_process'

console.log "started."

task = ->
  exec "mv /Users/yohsukeino/Dropbox/git/jinshinbaibai/uploads/* /Users/yohsukeino/Desktop/zikken_log2", console.info.bind(console)



setInterval task, 30000
