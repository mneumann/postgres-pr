#
# Author:: Michael Neumann
# Copyright:: (c) 2004 by Michael Neumann
# 

require 'readbytes'
require 'assert'

# Base class representing a PostgreSQL protocol message
class Message

  # One character message-typecode to class map
  MsgTypeMap = Hash.new

  # Postgres-specifiy datatypes (for pack/unpack)
  # TODO: correct unpacking/packing (they are unsigned but should be signed!)
  Int32 = 'N'
  Int16 = 'n'

  CString = 'Z*'
  Char = 'C'
  Rest = 'a*' 

  def self.dump(*a)
    new(*a).dump
  end

  attr_accessor :body

  def self.register_message_type(type)
    case type
    when String
      raise if type.size != 1
      type = type[0]
    end
    case type
    when Integer
      raise if type < 0 or type > 255
    else
      raise
    end

    raise "duplicate message type registration" if MsgTypeMap.has_key? type
    MsgTypeMap[type] = self

    self.const_set(:MsgType, type) 
    class_eval %{
      def message_type() MsgType end
    }
    instance_eval %{
      def message_type() MsgType end
    }
  end

  # TODO: mutex stream? or handle one layer above?
  def self.read(stream, startup_message=false)
    return read_startup(stream) if startup_message

    type, length = stream.readbytes(5).unpack(Char + Int32)
    klass = MsgTypeMap[type]

    assert(length >= 4)

    body = stream.readbytes(length-4)

    obj = 
    if klass.nil?
      UnknownMessageType.create(body, type)
    else
      klass.create(body)
    end

    assert(obj.message_type, type)

    obj
  end

  def self.read_startup(stream)
    length = stream.readbytes(4).unpack(Int32).first
    assert(length >= 4)
    body = stream.readbytes(length-4)
    StartupMessage.create(body)
  end
  

  def self.create(body)
    obj = allocate
    obj.body = body
    obj.parse
    obj
  end

  def self.dump(*args)
    new(*args).dump
  end

  def dump
    [self.message_type, @body.size+4, @body].pack(Char + Int32 + Rest)
  end

  def parse
  end
end

class UnknownMessageType < Message
  def self.create(body, type)
    new(body, type)
  end

  def initialize(body, type)
    @body, @type = body, type
  end

  def message_type
    @type
  end

  def dump
    raise
  end
end

class Authentification < Message
  register_message_type 'R'

  AuthTypeMap = Hash.new

  class << self
    alias old_create create
  end

  # TODO
  def self.create(body)
    authtype = body.unpack(Int32).first
    klass = AuthTypeMap[authtype] || (raise "Unknown authentification type")
    klass.old_create(body)
  end

  def self.register_auth_type(type)
    raise "duplicate auth type registration" if AuthTypeMap.has_key? type
    AuthTypeMap[type] = self
    self.const_set(:AuthType, type) 
    class_eval %{
      def auth_type() AuthType end
    }
  end

  def parse
    t = @body.unpack(Int32).first
    assert(t == self.auth_type)
  end

  # the dump method of class Message
  alias message__dump dump

  def dump
    @body = [self.auth_type].pack(Int32) 
    super
  end

  def initialize
    raise "abstract class"
  end
end

class AuthentificationOk < Authentification 
  register_auth_type 0
end

class AuthentificationKerberosV4 < Authentification 
  register_auth_type 1
end

class AuthentificationKerberosV5 < Authentification 
  register_auth_type 2
end

class AuthentificationClearTextPassword < Authentification 
  register_auth_type 3
end

module SaltedAuthentificationMixin
  attr_accessor :salt

  def initialize(salt)
    @salt = salt
  end

  def dump
    assert(@salt.size == self.class.salt_size)
    @body = [self.auth_type, @salt].pack(Int32 + Rest) 
    message__dump
  end

  def parse
    t, @salt = @body.unpack(Int32 + Rest)
    assert(@salt.size == self.class.salt_size)
    assert(t == self.auth_type)
  end
end

class AuthentificationCryptPassword < Authentification 
  register_auth_type 4
  def self.salt_size; 2 end
  include SaltedAuthentificationMixin
end


class AuthentificationMD5Password < Authentification 
  register_auth_type 5
  def self.salt_size; 4 end
  include SaltedAuthentificationMixin
end

class AuthentificationSCMCredential < Authentification 
  register_auth_type 6
end


class ErrorResponse < Message
  register_message_type 'E'

  def dump
    @body = ""
    super
  end
end

class ParameterStatus < Message
  register_message_type 'S'

  attr_accessor :key, :value

  def initialize(key, value)
    @key, @value = key, value
  end

  def dump
    @body = [@key, @value].pack(CString * 2)
    super
  end

  def parse
    @key, @value = @body.unpack(CString * 2)
  end
end

class BackendKeyData < Message
  register_message_type ?K

  attr_accessor :process_id, :secret_key

  def initialize(process_id, secret_key)
    @process_id, @secret_key = process_id, secret_key
  end

  def dump
    @body = [@process_id, @secret_key].pack(Int32 * 2)
    super
  end

  def parse
    @process_id, @secret_key = @body.unpack(Int32 * 2)
  end
end


class ReadyForQuery < Message
  register_message_type 'Z'

  attr_accessor :backend_transaction_status_indicator

  def initialize(backend_transaction_status_indicator)
    @backend_transaction_status_indicator = backend_transaction_status_indicator
  end

  def dump
    @body = [@backend_transaction_status_indicator].pack(Char)
    super
  end

  def parse
    @backend_transaction_status_indicator = @body.unpack(Char).first
    assert(@body.size == 1)
  end
end

class RowDescription < Message
  register_message_type 'T'

  # TODO: dump

  def parse
    buf = @body

    @fields = []
    num_fields, buf = buf.unpack(Int16 + Rest)

    num_fields.times do
      h = {}
      h[:name], h[:oid], h[:attr_nr], h[:type_oid], h[:typlen], h[:atttypmod], h[:formatcode], buf = 
      buf.unpack(CString + Int32 + Int16 + Int32 + Int16 + Int32 + Int16 + Rest)

      @fields << h
    end
    assert(buf.empty?)
  end
end

class DataRow < Message
  register_message_type 'D'

  NULL = [-1].pack("N").unpack("N").first

  attr_accessor :columns

  def initialize(columns) 
    @columns = columns
  end

  def dump
    @body = [@columns.size].pack(Int16) 
    @columns.each do |val|
      @body <<
      if val.nil?
        [NULL].pack(Int32)
      else
        [val.size, val].pack(Int32 + Rest)
      end
    end
    super
  end

  def parse
    buf = @body

    @columns = []
    num_cols, buf = buf.unpack(Int16 + Rest)

    num_cols.times do 
      len, buf = buf.unpack(Int32 + Rest)
      @columns << 
      # TODO: -1
      if len == NULL
        # NULL value
        nil
      else
        res = buf[0, len] 
        assert(res.size == len)
        buf = buf[len..-1]
        res
      end
    end
    assert(buf.empty?)
  end
end

class CommandComplete < Message
  register_message_type 'C'

  attr_accessor :cmd_tag

  def initialize(cmd_tag)
    @cmd_tag = cmd_tag
  end

  def dump
    @body = [@cmd_tag].pack(CString)
    super
  end

  # TODO: parse @cmd_tag?
  def parse
    @cmd_tag, rest = @body.unpack(CString + Rest)
    assert(rest.empty?)
  end
end

=begin
class CopyInResponse < Message
  register_message_type ?G
end

class CopyOutResponse < Message
  register_message_type ?H
end
=end

class EmptyQueryResponse < Message
  register_message_type ?I
end

class NoticeResponse < Message
  register_message_type ?N
  # TODO
end


class StartupMessage < Message
  attr_accessor :proto_version, :params

  def initialize(proto_version, params)
    @proto_version, @params = proto_version, params
  end

  def dump
    @body = [@proto_version].pack(Int32) + @params.to_a.flatten.map {|e| e.to_s + "\000"}.join("") + "\000"
    [@body.size + 4].pack(Int32) + @body
  end

  def parse
    buf = @body

    @proto_version, buf = buf.unpack(Int32 + Rest) # TODO: test proto_version?
    @params = {}
    while buf.length > 1
      key, val, buf = buf.unpack(CString + CString + Rest)
      @params[key] = val
    end
    assert(buf.length == 1 && buf[0,1] == "\000")
  end
end

class Parse < Message
  register_message_type 'P'
 
  attr_accessor :query, :stmt_name, :parameter_oids
  def initialize(query, stmt_name="", parameter_oids=[])
    @query, @stmt_name, @parameter_oids = query, stmt_name, parameter_oids
  end

  def parse
    buf = @body
    @stmt_name, @query, num_param_types, buf = buf.unpack(CString + CString + Int16 + Rest) 
    @parameter_oids = []
    num_param_types.times do
      # zero means unspecified. TODO: should map to nil?
      param_oid, buf = buf.unpack(Int32 + Rest)
      @paramter_oids << param_oid
    end
    assert(buf.empty?)
  end

  def dump
    @body = [@stmt_name, @query, @parameter_oids.size].pack(CString + CString + Int16) 
    @body << @parameter_oids.pack(Int32 + "*")
    super
  end
end

class ParseComplete < Message
  register_message_type ?1
end

class Message
  class << self
    def fields(*attribs)
      names = attribs.map {|name, type| name.to_s}
      arg_list = names.join(", ")
      var_list = names.join(", ") 
      ivar_list = names.map {|name| "@" + name }.join(", ")
      sym_list = names.map {|name| ":" + name }.join(", ")

      class_eval %[
        attr_accessor #{ sym_list } 

        def initialize(#{ arg_list })
          #{ ivar_list } = #{ arg_list }
        end
      ] 
    end
  end
end

class Query < Message
  register_message_type 'Q'

  attr_accessor :query

  def initialize(query)
    @query = query
  end

  def dump
    @body = @query + "\000"
    super
  end

  def parse
    @query, rest = @body.unpack(CString + Rest)
    assert(rest.empty?)
  end
end
