# This is a compatibility layer for using the pure Ruby postgres-pr instead of
# the C interface of postgres.

require 'postgres-pr/connection'

class PGconn
  class << self
    alias connect new
  end

  def initialize(host, port, options, tty, database, user, auth)
    uri =
    if host.nil?
      nil
    elsif host[0] != ?/
      "tcp://#{ host }:#{ port }"
    else
      "unix:#{ host }/.s.PGSQL.#{ port }"
    end

    @db = database
    @conn = PostgresPR::Connection.new(database, user, auth, uri)
  end

  def close
    @conn.close
  end

  attr_reader :db

  def query(sql)
    PGresult.new(@conn.query(sql))
  end

  alias exec query

  def self.escape(str)
    # TODO: correct?
    str.gsub(/\\/){ '\\\\' }.gsub(/'/){ '\\\'' }
  end

end

class PGresult
  include Enumerable

  def each(&block)
    @result.each(&block)
  end

  def [](index)
    @result[index]
  end
 
  def initialize(res)
    @res = res
    @fields = @res.fields.map {|f| f.name}
    @result = @res.rows
  end

  # TODO: status, getlength, cmdstatus

  attr_reader :result, :fields

  def num_tuples
    @result.size
  end

  def num_fields
    @fields.size
  end

  def fieldname(index)
    @fields[index]
  end

  def fieldnum(name)
    @fields.index(name)
  end

  def type(index)
    raise
    # TODO: correct?
    @res.fields[index].type_oid
  end

  def size(index)
    raise
    # TODO: correct?
    @res.fields[index].typlen
  end

  def getvalue(tup_num, field_num)
    @result[tup_num][field_num]
  end

  # free the result set
  def clear
    @res = @fields = @result = nil
  end

  # Returns the number of rows affected by the SQL command
  def cmdtuples
    case @res.cmd_tag
    when nil 
      return nil
    when /^INSERT\s+(\d+)\s+(\d+)$/, /^(DELETE|UPDATE|MOVE|FETCH)\s+(\d+)$/
      $2.to_i
    else
      nil
    end
  end

end
