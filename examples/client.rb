$LOAD_PATH.unshift "../lib"
require 'postgres-pr/message'
require 'socket'
include PostgresPR

s = UNIXSocket.new(ARGV.shift || "/tmp/.s.PGSQL.5432")

msg = StartupMessage.new(196608, "user" => "mneumann", "database" => "mneumann")
s << msg.dump

Thread.start(s) { |s|
  sleep 2
  s << Query.new("drop table test").dump
  s << Query.new("create table test (i int, v varchar(100))").dump
  s << Parse.new("insert into test (i, v) values ($1, $2)", "blah").dump 
  s << Query.new("EXECUTE blah(1, 'hallo')").dump

  while not (line = gets.chomp).empty?
    s << Query.new(line).dump
  end
  exit
}

loop do  
  msg = Message.read(s)
  p msg

  case msg
  when AuthentificationOk
    p "OK"
  when ErrorResponse
    p "FAILED"
  end
end
