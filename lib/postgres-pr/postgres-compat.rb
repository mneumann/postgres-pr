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

  attr_reader :db

  def query(sql)
    PGresult.new(@conn.query(sql))
  end

  alias exec query
end

class PGresult
  attr_reader :fields, :result

  def initialize(res)
    @res = res
    @fields = @res.fields.map {|f| f.name}
    @result = @res.rows
  end

  include Enumerable

  def each(&block)
    @result.each(&block)
  end

  def [](index)
    @result[index]
  end
end
