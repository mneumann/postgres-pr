#
# Author:: Michael Neumann
# Copyright:: (c) 2004 by Michael Neumann
#

require 'postgres-pr/message'
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

  class Result 
    attr_accessor :rows, :fields
    def initialize(rows=[], fields=[])
      @rows, @fields = rows, fields
    end
  end

  def query(sql)
    @mutex.synchronize {
      @conn << Query.dump(sql)

      result = Result.new

      loop do
        msg = Message.read(@conn)
        case msg
        when DataRow
          result.rows << msg.columns
        when CommandComplete
        when ReadyForQuery
          break
        when RowDescription
          result.fields = msg.fields
        when CopyInResponse
        when CopyOutResponse
        when EmptyQueryResponse
          p "EMPTY!"
        when ErrorResponse
          p msg
          raise 
        when NoticeResponse
          p msg
          # TODO
        else
          raise
        end
      end
      result
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
