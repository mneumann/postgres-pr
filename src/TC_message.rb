require 'test/unit'
require 'stringio'

class Module
  def attr_accessor(*attrs)
    @@attrs = [] unless defined?(@@attrs)
    @@attrs += attrs

    x = @@attrs.map {|a| "self.#{a} == o.#{a}"}.join(" && ")
    class_eval %{
      def ==(o)
        #{ x }
      end
    }

    @@attrs.each do |a|
      class_eval %{
        def #{a}() @#{a} end
        def #{a}=(v) @#{a}=v end
      }
    end
  end
end

require 'message'

class StringIO
  alias readbytes read
end

class TC_Message < Test::Unit::TestCase

  CASES = [ 
    #[AuthentificationOk], 
    [ErrorResponse],
    [ParameterStatus, "key", "value"],
    [BackendKeyData, 234234234, 213434],
    [ReadyForQuery, ?T],
    # TODO: RowDescription
    [DataRow, ["a", "bbbbbb", "ccc", nil, nil, "ddddd", "e" * 10_000]],
    [DataRow, []],
    [CommandComplete, "INSERT"],
    [StartupMessage, 196608, {"user" => "mneumann", "database" => "mneumann"}],
    [Parse, "INSERT INTO blah values (?, ?)", ""],
    [Query, "SELECT * FROM test\nWHERE a='test'"]
  ]

  def test_pack_unpack_feature
    assert_equal ['a', 'b'], "a\000b\000".unpack('Z*Z*')
  end

  def test_marshal_unmarshal
    CASES.each do |klass, *params|
      msg = klass.new(*params)
      new_msg = Message.read(StringIO.new(msg.dump), klass == StartupMessage)
      assert_equal(msg, new_msg)

      msg1, msg2 = klass.new(*params), klass.new(*params)
      msg1.dump
      msg2.dump; msg2.parse
      assert_equal(msg1, msg2)
    end
  end
end
