$LOAD_PATH.unshift "../lib"
require 'postgres-pr/message'
require 'socket'
include PostgresPR

s = UNIXServer.open(ARGV.shift || raise).accept
startup = true
loop do
  msg = Message.read(s, startup)
  p msg
  startup = false
end
