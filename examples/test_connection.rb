$LOAD_PATH.unshift '../lib'
require 'postgres-pr/connection'

conn = Connection.new('mneumann', 'mneumann')
p conn.query("DROP TABLE test; CREATE TABLE test (a VARCHAR(100))")
p conn.query("INSERT INTO test VALUES ('hallo')") 
p conn.query("INSERT INTO test VALUES ('leute')") 
conn.query("COMMIT")

conn.query("BEGIN")
10000.times do |i|
  p i
  conn.query("INSERT INTO test VALUES ('#{i}')") 
end
conn.query("COMMIT")

p conn.query("SELECT * FROM test")
