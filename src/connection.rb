#
# Author:: Michael Neumann
# Copyright:: (c) 2004 by Michael Neumann
#

require 'message'
require 'uri'
require 'socket'
require 'thread'

PROTO_VERSION = 196608

class Connection

  # sync

  def initialize(database, user, auth=nil, uri = "unix:/tmp/.s.PGSQL.5432")
    raise unless @mutex.nil?

    @mutex = Mutex.new

    @mutex.synchronize {
      @params = {}
      establish_connection(uri)
    
      @conn << StartupMessage.new(PROTO_VERSION, 'user' => user, 'database' => database).dump

      loop do
        msg = Message.read(@conn)
        case msg
        when AuthentificationOk
        when ErrorResponse
          raise
        when NoticeResponse
          # TODO
        when ParameterStatus
          @params[msg.key] = msg.value
        when BackendKeyData
          # TODO
          #p msg
        when ReadyForQuery
          # TODO: use transaction status
          break
        else
          raise "unhandled message type"
        end
      end
    }
  end

  def query(sql)
    @mutex.synchronize {
      @conn << Query.dump(sql)

      rows = []

      loop do
        msg = Message.read(@conn)
        case msg
        when DataRow
          rows << msg.columns 
        when CommandComplete
        when ReadyForQuery
          break
        when RowDescription
          # TODO
        when CopyInResponse
        when CopyOutResponse
        when EmptyQueryResponse
        when ErrorResponse
          p msg
          raise 
        when NoticeResponse
          # TODO
        else
          raise
        end
      end
      rows
    }
  end

  DEFAULT_PORT = 5432
  DEFAULT_HOST = 'localhost'

  private

  # tcp://localhost:5432
  # unix:/tmp/.s.PGSQL.5432
  def establish_connection(uri)
    u = URI.parse(uri)
    case u.scheme
    when 'tcp'
      @conn = TCPSocket.new(u.host || DEFAULT_HOST, u.port || DEFAULT_PORT)
    when 'unix'
      @conn = UNIXSocket.new(u.path)
    else
      raise 'unrecognized uri scheme format (must be tcp or unix)'
    end
  end
end

if __FILE__ == $0
  conn = Connection.new('mneumann', 'mneumann')
  #p conn.query("DROP TABLE test; CREATE TABLE test (a VARCHAR(100))")
  #p conn.query("INSERT INTO test VALUES ('hallo')") 
  #p conn.query("INSERT INTO test VALUES ('leute')") 
  #conn.query("COMMIT")

=begin
  conn.query("BEGIN")
  10000.times do |i|
    p i
    conn.query("INSERT INTO test VALUES ('#{i}')") 
  end
  conn.query("COMMIT")
=end

  p conn.query("SELECT * FROM test")
end
