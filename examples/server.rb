$LOAD_PATH.unshift "../src"
require 'postgres-pr/message'
require 'socket'

s = UNIXServer.open(ARGV.shift).accept
startup = true
loop do
  msg = Message.read(s, startup)
  p msg
  startup = false
end
