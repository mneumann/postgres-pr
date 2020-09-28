# Pure Ruby PostgreSQL interface

This is a library to access PostgreSQL (>= 7.4) from Ruby without the need of
any C library.

## Author and Copyright

Copyright (c) 2005, 2008 by Michael Neumann (mneumann@ntecs.de). 
Released under the same terms of license as Ruby.

## Homepage

http://rubyforge.org/projects/ruby-dbi

## Quick Example

```sh
$ gem install postgres-pr
$ irb -r rubygems 
```

Then in the interactive Ruby interpreter type (replace DBNAME and DBUSER
accordingly):

```ruby
require 'postgres-pr/connection'
c = PostgresPR::Connection.new('DBNAME', 'DBUSER')
c.query('SELECT 1+2').rows              # => [["3"]]
```
