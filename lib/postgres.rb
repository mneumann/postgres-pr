# This is a compatibility layer for using the pure Ruby postgres-pr instead of
# the C interface of postgres.

begin
  require 'postgres.so'
rescue LoadError
  require 'postgres-pr/connection'
  class PGconn
    class << self
      alias connect new
    end

    def initialize(host, port, options, tty, database, user, auth)
      uri =
      if host[0] != ?/
        "tcp://#{ host }:#{ port }"
      else
        "unix:#{ host }/.s.PGSQL.#{ port }"
      end

      @db = database
      @conn = Connection.new(database, user, auth, uri)
    end

    attr_reader :db

    def query(sql)
      PGresult.new(@conn.query(sql))
    end

    alias exec query
  end

  class PGresult
    def initialize(res)
      @res = res
    end

    def fields
      @res.fields.map {|f| f.name}
    end

    def result
      @res.rows.map {|row| row.map {|c| c || ""} }
    end

    include Enumerable

    def each(&block)
      result.each(&block)
    end
  end
end
