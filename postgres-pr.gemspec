require 'rubygems'

spec = Gem::Specification.new do |s|
  s.name = 'postgres-pr'
  s.version = '0.2.1'
  s.summary = 'A pure Ruby interface to the PostgreSQL database'

  s.files = (Dir['lib/**/*'] + Dir['test/**/*'] + 
             Dir['examples/**/*']).
             delete_if {|item| item.include?(".svn") }

  s.require_path = 'lib'

  s.author = "Michael Neumann"
  s.email = "mneumann@ntecs.de"
  s.homepage = "ruby-dbi.rubyforge.org"
  s.rubyforge_project = "ruby-dbi"
end
