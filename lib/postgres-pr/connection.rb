#
# Author:: Michael Neumann
# Copyright:: (c) 2004 by Michael Neumann
#

require 'postgres-pr/message'
require 'uri'
require 'socket'
require 'thread'

module PostgresPR

PROTO_VERSION = 3 << 16   #196608

class Connection

  # sync

  def initialize(database, user, password=nil, uri = nil)
    uri ||= DEFAULT_URI

    raise unless @mutex.nil?

    @mutex = Mutex.new

    @mutex.synchronize {
      @params = {}
      establish_connection(uri)
    
      @conn << StartupMessage.new(PROTO_VERSION, 'user' => user, 'database' => database).dump

      loop do
        msg = Message.read(@conn)

        case msg
        when AuthentificationClearTextPassword
          raise ArgumentError, "no password specified" if password.nil?
          @conn << PasswordMessage.new(password).dump

        when AuthentificationCryptPassword
          raise ArgumentError, "no password specified" if password.nil?
          @conn << PasswordMessage.new(password.crypt(msg.salt)).dump

        when AuthentificationMD5Password
          raise ArgumentError, "no password specified" if password.nil?
          require 'digest/md5'

          m = Digest::MD5.hexdigest(password + user) 
          m = Digest::MD5.hexdigest(m + msg.salt)
          m = 'md5' + m
          @conn << PasswordMessage.new(m).dump

        when AuthentificationKerberosV4, AuthentificationKerberosV5, AuthentificationSCMCredential
          raise "unsupported authentification"

        when AuthentificationOk
        when ErrorResponse
          raise msg.field_values.join("\t")
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
      errors = []

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
        when ErrorResponse
          # TODO
          errors << msg
        when NoticeResponse
          p msg
        else
          # TODO
        end
      end

      raise errors.map{|e| e.field_values.join("\t") }.join("\n") unless errors.empty?

      result
    }
  end

  DEFAULT_PORT = 5432
  DEFAULT_HOST = 'localhost'
  DEFAULT_PATH = '/tmp' 
  DEFAULT_URI = 
    if RUBY_PLATFORM.include?('win')
      'tcp://' + DEFAULT_HOST + ':' + DEFAULT_PORT.to_s 
    else
      'unix:' + File.join(DEFAULT_PATH, '.s.PGSQL.' + DEFAULT_PORT.to_s)  
    end

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

end # module PostgresPR
